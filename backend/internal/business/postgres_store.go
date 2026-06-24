package business

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
	"github.com/jackc/pgx/v5/pgconn"
)

const defaultQueryTimeout = 5 * time.Second

type PostgresStore struct {
	db           *sql.DB
	queryTimeout time.Duration
}

func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{
		db:           db,
		queryTimeout: defaultQueryTimeout,
	}
}

func (s *PostgresStore) ListClients(user auth.User) ([]Client, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id::text, name, COALESCE(contact_name, ''), COALESCE(phone, ''), COALESCE(email, ''), segment,
		        COALESCE(bank_name, ''), COALESCE(bank_account, ''), COALESCE(bank_bik, ''),
		        COALESCE(credit_limit, 0), COALESCE(bin, ''), COALESCE(iin, '')
		 FROM clients
		 WHERE company_id = $1 AND archived_at IS NULL
		 ORDER BY created_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	clients := make([]Client, 0)
	indexByID := make(map[string]int)
	for rows.Next() {
		var client Client
		var creditLimit float64
		if err := rows.Scan(
			&client.ID,
			&client.Name,
			&client.Contact,
			&client.Phone,
			&client.Email,
			&client.Segment,
			&client.BankName,
			&client.BankAccount,
			&client.BankBik,
			&creditLimit,
			&client.BIN,
			&client.IIN,
		); err != nil {
			return nil, err
		}

		client.Debt = int(creditLimit)
		client.TotalSales = 0
		client.SalesCount = 0
		client.AverageSale = 0
		client.PaymentsIn = 0
		client.PaymentsOut = 0
		client.OverdueAmount = 0
		client.Interactions = []Interaction{}
		client.OpenDocuments = []ClientDebtDocument{}
		client.Timeline = []ClientTimelineItem{}
		indexByID[client.ID] = len(clients)
		clients = append(clients, client)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	if len(clients) == 0 {
		return []Client{}, nil
	}

	interactionRows, err := s.db.QueryContext(
		ctx,
		`SELECT client_id::text, interaction_type, subject, COALESCE(note, ''), happened_at
		 FROM client_interactions
		 WHERE company_id = $1
		 ORDER BY happened_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer interactionRows.Close()

	for interactionRows.Next() {
		var clientID string
		var interactionType string
		var subject string
		var note string
		var happenedAt time.Time
		if err := interactionRows.Scan(
			&clientID,
			&interactionType,
			&subject,
			&note,
			&happenedAt,
		); err != nil {
			return nil, err
		}

		index, ok := indexByID[clientID]
		if !ok {
			continue
		}

		clients[index].Interactions = append(
			clients[index].Interactions,
			Interaction{
				Title: subjectTitle(interactionType, subject),
				Date:  happenedAt.Format("2 January 2006"),
				Note:  note,
			},
		)
	}
	if err := interactionRows.Err(); err != nil {
		return nil, err
	}

	financialRows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    c.id::text,
		    COALESCE(sales.total_sales, 0),
		    COALESCE(sales.sales_count, 0),
		    COALESCE(docs.receivable, 0),
		    COALESCE(docs.payable, 0),
		    COALESCE(docs.payments_in, 0),
		    COALESCE(docs.payments_out, 0),
		    COALESCE(docs.overdue_receivable, 0)
		 FROM clients c
		 LEFT JOIN (
		   SELECT d.client_id,
		          COALESCE(SUM(l.line_total), 0) AS total_sales,
		          COUNT(DISTINCT d.id) AS sales_count
		   FROM inventory_documents d
		   JOIN inventory_document_lines l ON l.document_id = d.id
		   WHERE d.company_id = $1::uuid
		     AND d.client_id IS NOT NULL
		     AND d.document_type = 'sale_issue'
		     AND d.status = 'posted'
		   GROUP BY d.client_id
		 ) sales ON sales.client_id = c.id
		 LEFT JOIN (
		   SELECT d.client_id,
		          COALESCE(SUM(CASE WHEN d.document_type = 'sale_receivable' THEN line_amounts.total_amount - paid.paid_amount ELSE 0 END), 0) AS receivable,
		          COALESCE(SUM(CASE WHEN d.document_type = 'purchase_payable' THEN line_amounts.total_amount - paid.paid_amount ELSE 0 END), 0) AS payable,
		          COALESCE(SUM(CASE WHEN d.document_type = 'sale_receivable' THEN paid.paid_amount ELSE 0 END), 0) AS payments_in,
		          COALESCE(SUM(CASE WHEN d.document_type = 'purchase_payable' THEN paid.paid_amount ELSE 0 END), 0) AS payments_out,
		          COALESCE(SUM(
		            CASE
		              WHEN d.document_type = 'sale_receivable'
		               AND (COALESCE(line_amounts.total_amount, 0) - COALESCE(paid.paid_amount, 0)) > 0
		               AND d.operation_date < CURRENT_DATE
		              THEN line_amounts.total_amount - paid.paid_amount
		              ELSE 0
		            END
		          ), 0) AS overdue_receivable
		   FROM money_documents d
		   LEFT JOIN (
		     SELECT l.document_id, COALESCE(SUM(l.amount), 0) AS total_amount
		     FROM money_document_lines l
		     GROUP BY l.document_id
		   ) line_amounts ON line_amounts.document_id = d.id
		   LEFT JOIN (
		     SELECT mm.document_id, COALESCE(SUM(mm.amount), 0) AS paid_amount
		     FROM money_movements mm
		     GROUP BY mm.document_id
		   ) paid ON paid.document_id = d.id
		   WHERE d.company_id = $1::uuid
		     AND d.client_id IS NOT NULL
		     AND d.document_type IN ('sale_receivable', 'purchase_payable')
		     AND (COALESCE(line_amounts.total_amount, 0) - COALESCE(paid.paid_amount, 0)) > 0
		   GROUP BY d.client_id
		 ) docs ON docs.client_id = c.id
		 WHERE c.company_id = $1::uuid AND c.archived_at IS NULL`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer financialRows.Close()

	for financialRows.Next() {
		var clientID string
		var totalSales float64
		var salesCount int
		var receivable float64
		var payable float64
		var paymentsIn float64
		var paymentsOut float64
		var overdueReceivable float64
		if err := financialRows.Scan(
			&clientID,
			&totalSales,
			&salesCount,
			&receivable,
			&payable,
			&paymentsIn,
			&paymentsOut,
			&overdueReceivable,
		); err != nil {
			return nil, err
		}
		index, ok := indexByID[clientID]
		if !ok {
			continue
		}
		clients[index].TotalSales = int(totalSales)
		clients[index].SalesCount = salesCount
		if salesCount > 0 {
			clients[index].AverageSale = int(totalSales) / salesCount
		}
		clients[index].Receivable = int(receivable)
		clients[index].Payable = int(payable)
		clients[index].PaymentsIn = int(paymentsIn)
		clients[index].PaymentsOut = int(paymentsOut)
		clients[index].OverdueAmount = int(overdueReceivable)
		clients[index].Debt = clients[index].Receivable
	}
	if err := financialRows.Err(); err != nil {
		return nil, err
	}

	documentRows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    d.client_id::text,
		    d.id::text,
		    d.document_no,
		    d.document_type,
		    d.status,
		    d.operation_date,
		    COALESCE(line_amounts.total_amount, 0),
		    COALESCE(paid.paid_amount, 0)
		 FROM money_documents d
		 LEFT JOIN (
		   SELECT l.document_id, COALESCE(SUM(l.amount), 0) AS total_amount
		   FROM money_document_lines l
		   GROUP BY l.document_id
		 ) line_amounts ON line_amounts.document_id = d.id
		 LEFT JOIN (
		   SELECT mm.document_id, COALESCE(SUM(mm.amount), 0) AS paid_amount
		   FROM money_movements mm
		   GROUP BY mm.document_id
		 ) paid ON paid.document_id = d.id
		 WHERE d.company_id = $1::uuid
		   AND d.client_id IS NOT NULL
		   AND d.document_type IN ('sale_receivable', 'purchase_payable')
		   AND (COALESCE(line_amounts.total_amount, 0) - COALESCE(paid.paid_amount, 0)) > 0
		 ORDER BY d.operation_date DESC, d.created_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer documentRows.Close()

	for documentRows.Next() {
		var clientID string
		var document ClientDebtDocument
		var operationDate time.Time
		var amount float64
		var paidAmount float64
		if err := documentRows.Scan(
			&clientID,
			&document.DocumentID,
			&document.DocumentNo,
			&document.DocumentType,
			&document.Status,
			&operationDate,
			&amount,
			&paidAmount,
		); err != nil {
			return nil, err
		}
		index, ok := indexByID[clientID]
		if !ok {
			continue
		}
		document.OperationDate = operationDate.Format("2006-01-02")
		document.Amount = int(amount)
		document.PaidAmount = int(paidAmount)
		document.RemainingAmount = document.Amount - document.PaidAmount
		clients[index].OpenDocuments = append(clients[index].OpenDocuments, document)
	}

	if err := documentRows.Err(); err != nil {
		return nil, err
	}

	timelineRows, err := s.db.QueryContext(
		ctx,
		`WITH client_timeline AS (
		   SELECT
		     d.client_id::text AS client_id,
		     d.id::text AS document_id,
		     d.document_type,
		     d.document_type AS event_type,
		     CASE
		       WHEN d.document_type = 'sale_issue' THEN 'Продажа'
		       WHEN d.document_type = 'purchase_receipt' THEN 'Закуп'
		       ELSE 'Складской документ'
		     END AS title,
		     COALESCE(d.document_no, d.document_type) AS subtitle,
		     d.document_date AS event_date,
		     COALESCE(line_amounts.total_amount, 0) AS amount,
		     CASE
		       WHEN d.document_type = 'sale_issue' THEN 'success'
		       WHEN d.document_type = 'purchase_receipt' THEN 'info'
		       ELSE 'neutral'
		     END AS tone,
		     ROW_NUMBER() OVER (
		       PARTITION BY d.client_id
		       ORDER BY d.document_date DESC, d.created_at DESC
		     ) AS position
		   FROM inventory_documents d
		   LEFT JOIN (
		     SELECT document_id, COALESCE(SUM(line_total), 0) AS total_amount
		     FROM inventory_document_lines
		     GROUP BY document_id
		   ) line_amounts ON line_amounts.document_id = d.id
		   WHERE d.company_id = $1::uuid
		     AND d.client_id IS NOT NULL
		     AND d.document_type IN ('sale_issue', 'purchase_receipt')
		     AND d.status = 'posted'

		   UNION ALL

		   SELECT
		     d.client_id::text AS client_id,
		     d.id::text AS document_id,
		     d.document_type,
		     CASE
		       WHEN d.document_type = 'sale_receivable' THEN 'payment_in'
		       WHEN d.document_type = 'purchase_payable' THEN 'payment_out'
		       ELSE 'payment'
		     END AS event_type,
		     CASE
		       WHEN d.document_type = 'sale_receivable' THEN 'Оплата от клиента'
		       WHEN d.document_type = 'purchase_payable' THEN 'Оплата поставщику'
		       ELSE 'Оплата'
		     END AS title,
		     COALESCE(ca.name, 'Без счета') AS subtitle,
		     mm.happened_at AS event_date,
		     mm.amount AS amount,
		     CASE
		       WHEN d.document_type = 'sale_receivable' THEN 'success'
		       WHEN d.document_type = 'purchase_payable' THEN 'warning'
		       ELSE 'neutral'
		     END AS tone,
		     ROW_NUMBER() OVER (
		       PARTITION BY d.client_id
		       ORDER BY mm.happened_at DESC, mm.created_at DESC
		     ) AS position
		   FROM money_movements mm
		   JOIN money_documents d ON d.id = mm.document_id
		   LEFT JOIN cash_accounts ca ON ca.id = mm.account_id
		   WHERE d.company_id = $1::uuid
		     AND d.client_id IS NOT NULL
		     AND d.document_type IN ('sale_receivable', 'purchase_payable')
		 ),
		 ranked AS (
		   SELECT
		     client_id,
		     document_id,
		     document_type,
		     event_type,
		     title,
		     subtitle,
		     event_date,
		     amount,
		     tone,
		     ROW_NUMBER() OVER (
		       PARTITION BY client_id
		       ORDER BY event_date DESC, document_id DESC
		     ) AS client_rank
		   FROM client_timeline
		 )
		 SELECT
		   client_id,
		   document_id,
		   document_type,
		   event_type,
		   title,
		   subtitle,
		   event_date,
		   amount,
		   tone
		 FROM ranked
		 WHERE client_rank <= 6
		 ORDER BY event_date DESC, document_id DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer timelineRows.Close()

	for timelineRows.Next() {
		var clientID string
		var item ClientTimelineItem
		var eventDate time.Time
		var amount float64
		if err := timelineRows.Scan(
			&clientID,
			&item.DocumentID,
			&item.DocumentType,
			&item.EventType,
			&item.Title,
			&item.Subtitle,
			&eventDate,
			&amount,
			&item.Tone,
		); err != nil {
			return nil, err
		}
		index, ok := indexByID[clientID]
		if !ok {
			continue
		}
		item.EventDate = eventDate.Format("2006-01-02")
		item.Amount = int(amount)
		clients[index].Timeline = append(clients[index].Timeline, item)
	}

	return clients, timelineRows.Err()
}

func (s *PostgresStore) SaveClients(user auth.User, clients []Client) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	if _, err = tx.ExecContext(
		ctx,
		`DELETE FROM client_interactions
		 WHERE company_id = $1
		   AND client_id IN (SELECT id FROM clients WHERE company_id = $1)`,
		companyID,
	); err != nil {
		return err
	}

	if _, err = tx.ExecContext(ctx, `DELETE FROM clients WHERE company_id = $1`, companyID); err != nil {
		return err
	}

	for _, client := range clients {
		if client.ID == "" {
			client.ID = mustGenerateClientID()
		}

		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO clients (
			   id, company_id, client_kind, name, contact_name, phone, email, bin, iin, country_code, segment, bank_name, bank_account, bank_bik, status, credit_limit, created_at, updated_at
			 ) VALUES (
			   $1::uuid, $2::uuid, $3, $4, NULLIF($5, ''), NULLIF($6, ''), NULLIF($7, ''), NULLIF($8, ''), NULLIF($9, ''), 'KZ', $10, NULLIF($11, ''), NULLIF($12, ''), NULLIF($13, ''), 'active', $14, NOW(), NOW()
			 )`,
			client.ID,
			companyID,
			clientKindFor(client),
			client.Name,
			client.Contact,
			client.Phone,
			client.Email,
			client.BIN,
			client.IIN,
			normalizeClientSegment(client.Segment),
			client.BankName,
			client.BankAccount,
			client.BankBik,
			client.Debt,
		); err != nil {
			return err
		}

		for _, interaction := range client.Interactions {
			if _, err = tx.ExecContext(
				ctx,
				`INSERT INTO client_interactions (
				   company_id, client_id, interaction_type, subject, note, happened_at, created_at, updated_at
				 ) VALUES (
				   $1::uuid, $2::uuid, $3, $4, NULLIF($5, ''), NOW(), NOW(), NOW()
				 )`,
				companyID,
				client.ID,
				interactionTypeFor(interaction.Title),
				interaction.Title,
				interaction.Note,
			); err != nil {
				return err
			}
		}
	}

	err = tx.Commit()
	return err
}

func (s *PostgresStore) ListWarehouses(user auth.User) ([]Warehouse, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id::text, name, COALESCE(code, ''), is_default
		 FROM warehouses
		 WHERE company_id = $1::uuid AND archived_at IS NULL
		 ORDER BY is_default DESC, created_at ASC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	warehouses := make([]Warehouse, 0)
	for rows.Next() {
		var warehouse Warehouse
		if err := rows.Scan(&warehouse.ID, &warehouse.Name, &warehouse.Code, &warehouse.IsDefault); err != nil {
			return nil, err
		}
		warehouses = append(warehouses, warehouse)
	}

	return warehouses, rows.Err()
}

func (s *PostgresStore) CreateWarehouse(user auth.User, input CreateWarehouseInput) (Warehouse, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Warehouse{}, err
	}

	normalized := NormalizeWarehouseInput(input)
	if err := ValidateWarehouseInput(normalized); err != nil {
		return Warehouse{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Warehouse{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	warehouseID, _, err := s.ensureWarehouse(
		ctx,
		tx,
		companyID,
		normalized.Name,
		normalized.Code,
		"storage",
	)
	if err != nil {
		return Warehouse{}, err
	}

	if normalized.Code != "" {
		if _, err = tx.ExecContext(
			ctx,
			`UPDATE warehouses
			 SET code = $3, updated_at = NOW()
			 WHERE company_id = $1::uuid AND id = $2::uuid`,
			companyID,
			warehouseID,
			normalized.Code,
		); err != nil {
			return Warehouse{}, err
		}
	}

	var warehouse Warehouse
	err = tx.QueryRowContext(
		ctx,
		`SELECT id::text, name, COALESCE(code, ''), is_default
		 FROM warehouses
		 WHERE company_id = $1::uuid AND id = $2::uuid`,
		companyID,
		warehouseID,
	).Scan(&warehouse.ID, &warehouse.Name, &warehouse.Code, &warehouse.IsDefault)
	if err != nil {
		return Warehouse{}, err
	}

	if err = tx.Commit(); err != nil {
		return Warehouse{}, err
	}

	return warehouse, nil
}

func (s *PostgresStore) ListWarehouseStock(user auth.User, warehouseID string, search string) ([]WarehouseStockItem, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	loweredSearch := strings.ToLower(strings.TrimSpace(search))
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    p.id::text,
		    p.name,
		    p.sku,
		    COALESCE(pc.name, ''),
		    p.unit_name,
		    COALESCE(ib.quantity_on_hand, 0),
		    p.min_quantity
		 FROM inventory_balances ib
		 JOIN products p ON p.id = ib.product_id
		 LEFT JOIN product_categories pc ON pc.id = p.category_id
		 WHERE ib.company_id = $1::uuid
		   AND ib.warehouse_id = $2::uuid
		   AND p.archived_at IS NULL
		   AND COALESCE(ib.quantity_on_hand, 0) <> 0
		   AND (
		     $3 = ''
		     OR LOWER(p.name) LIKE '%' || $3 || '%'
		     OR LOWER(p.sku) LIKE '%' || $3 || '%'
		   )
		 ORDER BY p.name ASC`,
		companyID,
		warehouseID,
		loweredSearch,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]WarehouseStockItem, 0)
	for rows.Next() {
		var item WarehouseStockItem
		var available float64
		var minQuantity float64
		if err := rows.Scan(
			&item.ProductID,
			&item.ProductName,
			&item.SKU,
			&item.Category,
			&item.UnitName,
			&available,
			&minQuantity,
		); err != nil {
			return nil, err
		}
		item.Available = int(available)
		item.MinQuantity = int(minQuantity)
		item.Status = productStatus(item.Available, item.MinQuantity)
		items = append(items, item)
	}

	return items, rows.Err()
}

func (s *PostgresStore) ListWarehouseMovements(user auth.User, warehouseID string, search string) ([]WarehouseMovement, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	loweredSearch := strings.ToLower(strings.TrimSpace(search))
	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    m.id::text,
		    m.document_id::text,
		    COALESCE(d.document_no, d.document_type),
		    d.document_type,
		    m.movement_type,
		    p.id::text,
		    p.name,
		    p.sku,
		    m.quantity_delta,
		    COALESCE(m.balance_after, 0),
		    m.happened_at,
		    w.name,
		    COALESCE(rw.name, '')
		 FROM inventory_movements m
		 JOIN inventory_documents d ON d.id = m.document_id
		 JOIN products p ON p.id = m.product_id
		 JOIN warehouses w ON w.id = m.warehouse_id
		 LEFT JOIN warehouses rw ON rw.id = d.related_warehouse_id
		 WHERE m.company_id = $1::uuid
		   AND m.warehouse_id = $2::uuid
		   AND (
		     $3 = ''
		     OR LOWER(COALESCE(d.document_no, d.document_type)) LIKE '%' || $3 || '%'
		     OR LOWER(p.name) LIKE '%' || $3 || '%'
		     OR LOWER(p.sku) LIKE '%' || $3 || '%'
		   )
		 ORDER BY m.happened_at DESC, m.created_at DESC`,
		companyID,
		warehouseID,
		loweredSearch,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	movements := make([]WarehouseMovement, 0)
	for rows.Next() {
		var movement WarehouseMovement
		var quantity float64
		var balanceAfter float64
		var happenedAt time.Time
		if err := rows.Scan(
			&movement.ID,
			&movement.DocumentID,
			&movement.DocumentNo,
			&movement.DocumentType,
			&movement.MovementType,
			&movement.ProductID,
			&movement.ProductName,
			&movement.SKU,
			&quantity,
			&balanceAfter,
			&happenedAt,
			&movement.WarehouseName,
			&movement.RelatedWarehouse,
		); err != nil {
			return nil, err
		}
		movement.Quantity = int(quantity)
		movement.BalanceAfter = int(balanceAfter)
		movement.DocumentDate = happenedAt.Format("2006-01-02")
		movements = append(movements, movement)
	}

	return movements, rows.Err()
}

func (s *PostgresStore) ListProducts(user auth.User) ([]Product, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    p.id::text,
		    p.name,
		    p.sku,
		    COALESCE(pc.name, ''),
		    p.product_type,
		    p.unit_name,
		    p.allowed_to_sell,
		    COALESCE(SUM(ib.quantity_on_hand), 0),
		    p.min_quantity,
		    p.sale_price,
		    p.cost_price,
		    COALESCE(p.barcode, '')
		 FROM products p
		 LEFT JOIN product_categories pc ON pc.id = p.category_id
		 LEFT JOIN inventory_balances ib ON ib.product_id = p.id AND ib.company_id = p.company_id
		 WHERE p.company_id = $1 AND p.archived_at IS NULL
		 GROUP BY p.id, p.name, p.sku, pc.name, p.product_type, p.unit_name, p.allowed_to_sell,
		          p.min_quantity, p.sale_price, p.cost_price, p.barcode, p.created_at
		 ORDER BY p.created_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	products := make([]Product, 0)
	indexByID := make(map[string]int)
	for rows.Next() {
		var product Product
		var quantity float64
		var minQuantity float64
		var price float64
		var cost float64
		if err := rows.Scan(
			&product.ID,
			&product.Name,
			&product.SKU,
			&product.Category,
			&product.ProductType,
			&product.UnitName,
			&product.AllowedToSell,
			&quantity,
			&minQuantity,
			&price,
			&cost,
			&product.Barcode,
		); err != nil {
			return nil, err
		}

		product.Quantity = int(quantity)
		product.MinQuantity = int(minQuantity)
		product.Price = int(price)
		product.Cost = int(cost)
		product.Status = productStatus(product.Quantity, product.MinQuantity)
		product.Movements = []StockMovement{}
		indexByID[product.ID] = len(products)
		products = append(products, product)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(products) == 0 {
		return []Product{}, nil
	}

	movementRows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    m.product_id::text,
		    COALESCE(d.document_no, d.document_type),
		    m.quantity_delta,
		    COALESCE(m.balance_after, 0),
		    m.happened_at
		 FROM inventory_movements m
		 JOIN inventory_documents d ON d.id = m.document_id
		 WHERE m.company_id = $1
		 ORDER BY m.happened_at DESC, m.created_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer movementRows.Close()

	for movementRows.Next() {
		var productID string
		var document string
		var quantity float64
		var balance float64
		var happenedAt time.Time
		if err := movementRows.Scan(&productID, &document, &quantity, &balance, &happenedAt); err != nil {
			return nil, err
		}

		index, ok := indexByID[productID]
		if !ok {
			continue
		}

		products[index].Movements = append(products[index].Movements, StockMovement{
			Date:     happenedAt.Format("2 January 2006"),
			Document: document,
			Quantity: int(quantity),
			Balance:  int(balance),
		})
	}

	return products, movementRows.Err()
}

func (s *PostgresStore) CreateProduct(user auth.User, input CreateProductInput) (Product, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Product{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Product{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	defaultWarehouseID, err := s.ensureDefaultWarehouse(ctx, tx, companyID)
	if err != nil {
		return Product{}, err
	}

	categoryID, err := s.ensureProductCategory(ctx, tx, companyID, input.Category)
	if err != nil {
		return Product{}, err
	}

	product := NewProductFromInput(input)
	if _, err = tx.ExecContext(
		ctx,
		`INSERT INTO products (
		   id, company_id, category_id, sku, barcode, name, unit_name, product_type, allowed_to_sell,
		   tracking_type, min_quantity, sale_price, cost_price, is_active, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2::uuid, $3::uuid, $4, NULLIF($5, ''), $6, $7, $8, $9,
		   'none', $10, $11, $12, TRUE, NOW(), NOW()
		 )`,
		product.ID,
		companyID,
		nullUUID(categoryID),
		product.SKU,
		product.Barcode,
		product.Name,
		product.UnitName,
		product.ProductType,
		product.AllowedToSell,
		product.MinQuantity,
		product.Price,
		product.Cost,
	); err != nil {
		return Product{}, err
	}

	if product.Quantity > 0 {
		if err = s.createOpeningInventory(ctx, tx, companyID, defaultWarehouseID, product); err != nil {
			return Product{}, err
		}
	}

	if err = tx.Commit(); err != nil {
		return Product{}, err
	}

	return product, nil
}

func (s *PostgresStore) UpdateProduct(user auth.User, productID string, input CreateProductInput) (Product, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Product{}, err
	}

	existing, err := s.findProductByID(ctx, companyID, productID)
	if err != nil {
		return Product{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Product{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	categoryID, err := s.ensureProductCategory(ctx, tx, companyID, input.Category)
	if err != nil {
		return Product{}, err
	}

	updated := UpdatedProductFromInput(existing, input)
	if _, err = tx.ExecContext(
		ctx,
		`UPDATE products
		 SET category_id    = $3::uuid,
		     sku             = $4,
		     barcode         = NULLIF($5, ''),
		     name            = $6,
		     unit_name       = $7,
		     product_type    = $8,
		     allowed_to_sell = $9,
		     min_quantity    = $10,
		     sale_price      = $11,
		     cost_price      = $12,
		     updated_at      = NOW()
		 WHERE id = $1::uuid AND company_id = $2::uuid`,
		productID,
		companyID,
		nullUUID(categoryID),
		updated.SKU,
		updated.Barcode,
		updated.Name,
		updated.UnitName,
		updated.ProductType,
		updated.AllowedToSell,
		updated.MinQuantity,
		updated.Price,
		updated.Cost,
	); err != nil {
		return Product{}, err
	}

	if err = tx.Commit(); err != nil {
		return Product{}, err
	}

	return updated, nil
}

func (s *PostgresStore) DeleteProduct(user auth.User, productID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	result, err := s.db.ExecContext(
		ctx,
		`UPDATE products
		 SET archived_at = NOW(), is_active = FALSE, updated_at = NOW()
		 WHERE id = $1::uuid AND company_id = $2::uuid AND archived_at IS NULL`,
		productID,
		companyID,
	)
	if err != nil {
		return err
	}

	affected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return sql.ErrNoRows
	}

	return nil
}

func (s *PostgresStore) CreateInventoryDocument(user auth.User, input CreateInventoryDocumentInput) (InventoryDocumentDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	normalized := NormalizeInventoryDocumentInput(input)
	documentDate := time.Now()
	if normalized.DocumentDate != "" {
		documentDate, err = time.Parse("2006-01-02", normalized.DocumentDate)
		if err != nil {
			return InventoryDocumentDetail{}, fmt.Errorf("%w: document date must be in YYYY-MM-DD format", ErrValidation)
		}
	}

	sourceWarehouseID, sourceWarehouseName, err := s.ensureWarehouse(ctx, tx, companyID, normalized.WarehouseName, "MAIN", "Основной склад")
	if err != nil {
		return InventoryDocumentDetail{}, err
	}

	relatedWarehouseID := ""
	relatedWarehouseName := ""
	if normalized.DocumentType == "transfer" {
		relatedWarehouseID, relatedWarehouseName, err = s.ensureWarehouse(ctx, tx, companyID, normalized.RelatedWarehouseName, "TRANSIT", normalized.RelatedWarehouseName)
		if err != nil {
			return InventoryDocumentDetail{}, err
		}
	}

	clientName := ""
	if normalized.ClientID != "" {
		client, clientErr := s.findClientByID(ctx, companyID, normalized.ClientID)
		if clientErr != nil {
			if errors.Is(clientErr, sql.ErrNoRows) {
				return InventoryDocumentDetail{}, fmt.Errorf("%w: client not found", ErrValidation)
			}
			return InventoryDocumentDetail{}, clientErr
		}
		clientName = client.Name
	}

	documentNo := normalized.DocumentNo
	if documentNo == "" {
		documentNo = s.nextInventoryDocumentNo(normalized.DocumentType)
	}
	status := inventoryDocumentStatusForCreate(normalized.Status)

	var documentID string
	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO inventory_documents (
		   company_id, document_no, document_type, status, document_date, warehouse_id, related_warehouse_id, client_id, employee_id, note, created_by_user_id, posted_by_user_id, posted_at, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2, $3, $4, $5, $6::uuid, $7::uuid, $8::uuid, $9::uuid, NULLIF($10, ''), $11,
		   CASE WHEN $4 = 'posted' THEN $11 ELSE NULL END,
		   CASE WHEN $4 = 'posted' THEN NOW() ELSE NULL END,
		   NOW(), NOW()
		 )
		 RETURNING id::text`,
		companyID,
		documentNo,
		normalized.DocumentType,
		status,
		documentDate.Format("2006-01-02"),
		sourceWarehouseID,
		nullUUID(relatedWarehouseID),
		nullUUID(normalized.ClientID),
		nullUUID(normalized.EmployeeID),
		normalized.Note,
		user.ID,
	).Scan(&documentID); err != nil {
		return InventoryDocumentDetail{}, err
	}

	detail := InventoryDocumentDetail{
		Summary: InventoryDocumentSummary{
			ID:               documentID,
			DocumentNo:       documentNo,
			DocumentType:     normalized.DocumentType,
			Status:           status,
			DocumentDate:     documentDate.Format("2006-01-02"),
			ClientID:         normalized.ClientID,
			EmployeeID:       normalized.EmployeeID,
			ClientName:       clientName,
			WarehouseName:    sourceWarehouseName,
			RelatedWarehouse: relatedWarehouseName,
			ProductLines:     len(normalized.Lines),
			Note:             normalized.Note,
		},
		Lines: make([]InventoryDocumentLine, 0, len(normalized.Lines)),
	}

	totalQuantity := 0
	totalAmount := 0
	for index, inputLine := range normalized.Lines {
		unitPrice := inputLine.UnitPrice
		unitCost := inputLine.UnitCost
		lineTotal := inputLine.Quantity * unitPrice

		if strings.TrimSpace(inputLine.ServiceID) != "" {
			// Service line — no inventory movement
			var svcName string
			var svcAllowedToSell bool
			if err = tx.QueryRowContext(
				ctx,
				`SELECT name, allowed_to_sell FROM services WHERE id = $1::uuid AND company_id = $2::uuid AND archived_at IS NULL`,
				inputLine.ServiceID,
				companyID,
			).Scan(&svcName, &svcAllowedToSell); err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					return InventoryDocumentDetail{}, fmt.Errorf("%w: service not found", ErrValidation)
				}
				return InventoryDocumentDetail{}, err
			}
			if normalized.DocumentType == "sale_issue" && !svcAllowedToSell {
				return InventoryDocumentDetail{}, fmt.Errorf("%w: service %q is not allowed to sell", ErrValidation, svcName)
			}
			if err = tx.QueryRowContext(
				ctx,
				`INSERT INTO inventory_document_lines (
				   document_id, line_no, service_id, quantity, unit_price, unit_cost, note, created_at
				 ) VALUES (
				   $1::uuid, $2, $3::uuid, $4, $5, $6, NULLIF($7, ''), NOW()
				 )
				 RETURNING id::text`,
				documentID,
				index+1,
				inputLine.ServiceID,
				inputLine.Quantity,
				unitPrice,
				unitCost,
				inputLine.Note,
			).Scan(new(string)); err != nil {
				return InventoryDocumentDetail{}, err
			}
			totalQuantity += inputLine.Quantity
			totalAmount += lineTotal
			detail.Lines = append(detail.Lines, InventoryDocumentLine{
				ServiceID: inputLine.ServiceID,
				ItemName:  svcName,
				ItemType:  "service",
				Quantity:  inputLine.Quantity,
				UnitPrice: unitPrice,
				UnitCost:  unitCost,
				LineTotal: lineTotal,
				Note:      inputLine.Note,
			})
		} else {
			// Product line — apply inventory movement
			product, productErr := s.findProductByID(ctx, companyID, inputLine.ProductID)
			if productErr != nil {
				if errors.Is(productErr, sql.ErrNoRows) {
					return InventoryDocumentDetail{}, fmt.Errorf("%w: product not found", ErrValidation)
				}
				return InventoryDocumentDetail{}, productErr
			}
			if normalized.DocumentType == "sale_issue" && !product.AllowedToSell {
				return InventoryDocumentDetail{}, fmt.Errorf("%w: product %q is not allowed to sell", ErrValidation, product.Name)
			}
			if unitPrice == 0 {
				unitPrice = product.Price
			}
			if unitCost == 0 {
				unitCost = product.Cost
			}
			lineTotal = inputLine.Quantity * unitPrice

			var lineID string
			if err = tx.QueryRowContext(
				ctx,
				`INSERT INTO inventory_document_lines (
				   document_id, line_no, product_id, quantity, unit_price, unit_cost, note, created_at
				 ) VALUES (
				   $1::uuid, $2, $3::uuid, $4, $5, $6, NULLIF($7, ''), NOW()
				 )
				 RETURNING id::text`,
				documentID,
				index+1,
				product.ID,
				inputLine.Quantity,
				unitPrice,
				unitCost,
				inputLine.Note,
			).Scan(&lineID); err != nil {
				return InventoryDocumentDetail{}, err
			}

			if status == "posted" {
				if err = s.applyInventoryMovement(
					ctx,
					tx,
					companyID,
					normalized.DocumentType,
					sourceWarehouseID,
					relatedWarehouseID,
					product,
					documentID,
					lineID,
					inputLine.Quantity,
					unitCost,
					documentDate,
				); err != nil {
					return InventoryDocumentDetail{}, err
				}
			}

			totalQuantity += inputLine.Quantity
			totalAmount += lineTotal
			detail.Lines = append(detail.Lines, InventoryDocumentLine{
				ProductID: product.ID,
				ItemName:  product.Name,
				ItemType:  "product",
				SKU:       product.SKU,
				Quantity:  inputLine.Quantity,
				UnitPrice: unitPrice,
				UnitCost:  unitCost,
				LineTotal: lineTotal,
				Note:      inputLine.Note,
			})
		}
	}

	detail.Summary.TotalQuantity = totalQuantity
	detail.Summary.TotalAmount = totalAmount

	if status == "posted" {
		if err = s.createLinkedMoneyDocumentDraft(
			ctx,
			tx,
			companyID,
			documentID,
			detail.Summary,
			documentDate,
		); err != nil {
			return InventoryDocumentDetail{}, err
		}
	}

	if err = tx.Commit(); err != nil {
		return InventoryDocumentDetail{}, err
	}
	committed = true

	return detail, nil
}

func (s *PostgresStore) UpdateInventoryDocument(user auth.User, documentID string, input CreateInventoryDocumentInput) (InventoryDocumentDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	normalized := NormalizeInventoryDocumentInput(input)
	documentDate := time.Now()
	if normalized.DocumentDate != "" {
		documentDate, err = time.Parse("2006-01-02", normalized.DocumentDate)
		if err != nil {
			return InventoryDocumentDetail{}, fmt.Errorf("%w: document date must be in YYYY-MM-DD format", ErrValidation)
		}
	}

	var currentNo string
	var currentStatus string
	var currentDate time.Time
	if err = tx.QueryRowContext(
		ctx,
		`SELECT document_no, status, document_date
		 FROM inventory_documents
		 WHERE id = $1::uuid AND company_id = $2::uuid
		 FOR UPDATE`,
		documentID,
		companyID,
	).Scan(&currentNo, &currentStatus, &currentDate); err != nil {
		return InventoryDocumentDetail{}, err
	}
	if currentStatus != "draft" {
		return InventoryDocumentDetail{}, fmt.Errorf("%w: only draft inventory documents can be edited", ErrValidation)
	}
	if normalized.DocumentDate == "" {
		documentDate = currentDate
	}

	sourceWarehouseID, _, err := s.ensureWarehouse(ctx, tx, companyID, normalized.WarehouseName, "MAIN", "Основной склад")
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	relatedWarehouseID := ""
	if normalized.DocumentType == "transfer" {
		relatedWarehouseID, _, err = s.ensureWarehouse(ctx, tx, companyID, normalized.RelatedWarehouseName, "TRANSIT", normalized.RelatedWarehouseName)
		if err != nil {
			return InventoryDocumentDetail{}, err
		}
	}
	if normalized.ClientID != "" {
		if _, err = s.findClientByID(ctx, companyID, normalized.ClientID); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return InventoryDocumentDetail{}, fmt.Errorf("%w: client not found", ErrValidation)
			}
			return InventoryDocumentDetail{}, err
		}
	}

	documentNo := normalized.DocumentNo
	if documentNo == "" {
		documentNo = currentNo
	}

	if _, err = tx.ExecContext(
		ctx,
		`UPDATE inventory_documents
		 SET document_no = $3,
		     document_type = $4,
		     document_date = $5,
		     warehouse_id = $6::uuid,
		     related_warehouse_id = $7::uuid,
		     client_id = $8::uuid,
		     employee_id = $9::uuid,
		     note = NULLIF($10, ''),
		     updated_at = NOW()
		 WHERE id = $1::uuid AND company_id = $2::uuid AND status = 'draft'`,
		documentID,
		companyID,
		documentNo,
		normalized.DocumentType,
		documentDate.Format("2006-01-02"),
		sourceWarehouseID,
		nullUUID(relatedWarehouseID),
		nullUUID(normalized.ClientID),
		nullUUID(normalized.EmployeeID),
		normalized.Note,
	); err != nil {
		return InventoryDocumentDetail{}, err
	}

	if _, _, _, err = s.replaceInventoryDocumentDraftLines(ctx, tx, companyID, documentID, normalized.DocumentType, normalized.Lines); err != nil {
		return InventoryDocumentDetail{}, err
	}

	if err = tx.Commit(); err != nil {
		return InventoryDocumentDetail{}, err
	}
	committed = true

	return s.GetInventoryDocument(user, documentID)
}

func (s *PostgresStore) PostInventoryDocument(user auth.User, documentID string) (InventoryDocumentDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	var summary InventoryDocumentSummary
	var documentDate time.Time
	var sourceWarehouseID string
	var relatedWarehouseID string
	if err = tx.QueryRowContext(
		ctx,
		`SELECT
		    d.document_no,
		    d.document_type,
		    d.status,
		    d.document_date,
		    COALESCE(d.warehouse_id::text, ''),
		    COALESCE(d.related_warehouse_id::text, ''),
		    COALESCE(d.client_id::text, '')
		 FROM inventory_documents d
		 WHERE d.id = $1::uuid AND d.company_id = $2::uuid
		 FOR UPDATE`,
		documentID,
		companyID,
	).Scan(
		&summary.DocumentNo,
		&summary.DocumentType,
		&summary.Status,
		&documentDate,
		&sourceWarehouseID,
		&relatedWarehouseID,
		&summary.ClientID,
	); err != nil {
		return InventoryDocumentDetail{}, err
	}
	if summary.Status != "draft" {
		return InventoryDocumentDetail{}, fmt.Errorf("%w: only draft inventory documents can be posted", ErrValidation)
	}
	if sourceWarehouseID == "" {
		return InventoryDocumentDetail{}, fmt.Errorf("%w: warehouse is required", ErrValidation)
	}
	if summary.DocumentType == "transfer" && relatedWarehouseID == "" {
		return InventoryDocumentDetail{}, fmt.Errorf("%w: related warehouse is required for transfer", ErrValidation)
	}

	rows, err := tx.QueryContext(
		ctx,
		`SELECT
		    id::text,
		    COALESCE(product_id::text, ''),
		    quantity,
		    unit_cost,
		    COALESCE(line_total, 0)
		 FROM inventory_document_lines
		 WHERE document_id = $1::uuid
		 ORDER BY line_no ASC`,
		documentID,
	)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	defer rows.Close()

	totalAmount := 0
	for rows.Next() {
		var lineID string
		var productID string
		var quantity float64
		var unitCost float64
		var lineTotal float64
		if err = rows.Scan(&lineID, &productID, &quantity, &unitCost, &lineTotal); err != nil {
			return InventoryDocumentDetail{}, err
		}
		totalAmount += int(lineTotal)
		if productID == "" {
			continue
		}
		product, productErr := s.findProductByID(ctx, companyID, productID)
		if productErr != nil {
			if errors.Is(productErr, sql.ErrNoRows) {
				return InventoryDocumentDetail{}, fmt.Errorf("%w: product not found", ErrValidation)
			}
			return InventoryDocumentDetail{}, productErr
		}
		if err = s.applyInventoryMovement(
			ctx,
			tx,
			companyID,
			summary.DocumentType,
			sourceWarehouseID,
			relatedWarehouseID,
			product,
			documentID,
			lineID,
			int(quantity),
			int(unitCost),
			documentDate,
		); err != nil {
			return InventoryDocumentDetail{}, err
		}
	}
	if err = rows.Err(); err != nil {
		return InventoryDocumentDetail{}, err
	}
	if err = rows.Close(); err != nil {
		return InventoryDocumentDetail{}, err
	}

	if _, err = tx.ExecContext(
		ctx,
		`UPDATE inventory_documents
		 SET status = 'posted',
		     posted_by_user_id = $3,
		     posted_at = NOW(),
		     updated_at = NOW()
		 WHERE id = $1::uuid AND company_id = $2::uuid AND status = 'draft'`,
		documentID,
		companyID,
		user.ID,
	); err != nil {
		return InventoryDocumentDetail{}, err
	}

	summary.ID = documentID
	summary.Status = "posted"
	summary.TotalAmount = totalAmount
	if err = s.createLinkedMoneyDocumentDraft(ctx, tx, companyID, documentID, summary, documentDate); err != nil {
		return InventoryDocumentDetail{}, err
	}

	if err = tx.Commit(); err != nil {
		return InventoryDocumentDetail{}, err
	}
	committed = true

	return s.GetInventoryDocument(user, documentID)
}

func (s *PostgresStore) DeleteInventoryDocument(user auth.User, documentID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	var status string
	if err = tx.QueryRowContext(
		ctx,
		`SELECT status
		 FROM inventory_documents
		 WHERE id = $1::uuid AND company_id = $2::uuid
		 FOR UPDATE`,
		documentID,
		companyID,
	).Scan(&status); err != nil {
		return err
	}
	if status != "draft" {
		return fmt.Errorf("%w: only draft inventory documents can be deleted", ErrValidation)
	}

	if _, err = tx.ExecContext(
		ctx,
		`DELETE FROM inventory_documents
		 WHERE id = $1::uuid AND company_id = $2::uuid AND status = 'draft'`,
		documentID,
		companyID,
	); err != nil {
		return err
	}

	if err = tx.Commit(); err != nil {
		return err
	}
	committed = true
	return nil
}

func (s *PostgresStore) ListInventoryDocuments(user auth.User, documentType string, search string) ([]InventoryDocumentSummary, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    d.id::text,
		    d.document_no,
		    d.document_type,
		    d.status,
		    d.document_date,
		    COALESCE(c.id::text, ''),
		    COALESCE(d.employee_id::text, ''),
		    COALESCE(c.name, ''),
		    COALESCE(w.name, ''),
		    COALESCE(rw.name, ''),
		    COUNT(DISTINCT l.id),
		    COALESCE(SUM(l.quantity), 0),
		    COALESCE(SUM(l.line_total), 0),
		    COALESCE(d.note, '')
		 FROM inventory_documents d
		 LEFT JOIN clients c ON c.id = d.client_id
		 LEFT JOIN warehouses w ON w.id = d.warehouse_id
		 LEFT JOIN warehouses rw ON rw.id = d.related_warehouse_id
		 LEFT JOIN inventory_document_lines l ON l.document_id = d.id
		 WHERE d.company_id = $1::uuid
		   AND ($2 = '' OR d.document_type = $2)
		   AND (
		     $3 = ''
		     OR d.document_no ILIKE '%' || $3 || '%'
		     OR COALESCE(d.note, '') ILIKE '%' || $3 || '%'
		     OR COALESCE(c.name, '') ILIKE '%' || $3 || '%'
		     OR COALESCE(w.name, '') ILIKE '%' || $3 || '%'
		   )
		 GROUP BY d.id, d.document_no, d.document_type, d.status, d.document_date, c.id, d.employee_id, c.name, w.name, rw.name, d.note
		 ORDER BY d.document_date DESC, d.created_at DESC
		 LIMIT 100`,
		companyID,
		documentType,
		search,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	documents := make([]InventoryDocumentSummary, 0)
	for rows.Next() {
		var document InventoryDocumentSummary
		var documentDate time.Time
		var totalQuantity float64
		var totalAmount float64
		if err := rows.Scan(
			&document.ID,
			&document.DocumentNo,
			&document.DocumentType,
			&document.Status,
			&documentDate,
			&document.ClientID,
			&document.EmployeeID,
			&document.ClientName,
			&document.WarehouseName,
			&document.RelatedWarehouse,
			&document.ProductLines,
			&totalQuantity,
			&totalAmount,
			&document.Note,
		); err != nil {
			return nil, err
		}
		document.DocumentDate = documentDate.Format("2006-01-02")
		document.TotalQuantity = int(totalQuantity)
		document.TotalAmount = int(totalAmount)
		documents = append(documents, document)
	}

	return documents, rows.Err()
}

func (s *PostgresStore) GetInventoryDocument(user auth.User, documentID string) (InventoryDocumentDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}

	var detail InventoryDocumentDetail
	var documentDate time.Time
	var totalQuantity float64
	var totalAmount float64
	err = s.db.QueryRowContext(
		ctx,
		`SELECT
		    d.id::text,
		    d.document_no,
		    d.document_type,
		    d.status,
		    d.document_date,
		    COALESCE(c.id::text, ''),
		    COALESCE(d.employee_id::text, ''),
		    COALESCE(c.name, ''),
		    COALESCE(w.name, ''),
		    COALESCE(rw.name, ''),
		    COUNT(DISTINCT l.id),
		    COALESCE(SUM(l.quantity), 0),
		    COALESCE(SUM(l.line_total), 0),
		    COALESCE(d.note, '')
		 FROM inventory_documents d
		 LEFT JOIN clients c ON c.id = d.client_id
		 LEFT JOIN warehouses w ON w.id = d.warehouse_id
		 LEFT JOIN warehouses rw ON rw.id = d.related_warehouse_id
		 LEFT JOIN inventory_document_lines l ON l.document_id = d.id
		 WHERE d.company_id = $1::uuid AND d.id = $2::uuid
		 GROUP BY d.id, d.document_no, d.document_type, d.status, d.document_date, c.id, d.employee_id, c.name, w.name, rw.name, d.note`,
		companyID,
		documentID,
	).Scan(
		&detail.Summary.ID,
		&detail.Summary.DocumentNo,
		&detail.Summary.DocumentType,
		&detail.Summary.Status,
		&documentDate,
		&detail.Summary.ClientID,
		&detail.Summary.EmployeeID,
		&detail.Summary.ClientName,
		&detail.Summary.WarehouseName,
		&detail.Summary.RelatedWarehouse,
		&detail.Summary.ProductLines,
		&totalQuantity,
		&totalAmount,
		&detail.Summary.Note,
	)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	detail.Summary.DocumentDate = documentDate.Format("2006-01-02")
	detail.Summary.TotalQuantity = int(totalQuantity)
	detail.Summary.TotalAmount = int(totalAmount)

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    CASE WHEN l.service_id IS NOT NULL THEN 'service' ELSE 'product' END,
		    COALESCE(l.product_id::text, ''),
		    COALESCE(l.service_id::text, ''),
		    COALESCE(p.name, s.name, ''),
		    COALESCE(p.sku, ''),
		    COALESCE(p.barcode, ''),
		    l.quantity,
		    l.unit_price,
		    l.unit_cost,
		    COALESCE(l.line_total, 0),
		    COALESCE(l.note, '')
		 FROM inventory_document_lines l
		 LEFT JOIN products p ON p.id = l.product_id
		 LEFT JOIN services s ON s.id = l.service_id
		 WHERE l.document_id = $1::uuid
		 ORDER BY l.line_no ASC`,
		documentID,
	)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	defer rows.Close()

	detail.Lines = make([]InventoryDocumentLine, 0)
	for rows.Next() {
		var line InventoryDocumentLine
		var quantity float64
		var unitPrice float64
		var unitCost float64
		var lineTotal float64
		if err := rows.Scan(
			&line.ItemType,
			&line.ProductID,
			&line.ServiceID,
			&line.ItemName,
			&line.SKU,
			&line.Barcode,
			&quantity,
			&unitPrice,
			&unitCost,
			&lineTotal,
			&line.Note,
		); err != nil {
			return InventoryDocumentDetail{}, err
		}
		line.Quantity = int(quantity)
		line.UnitPrice = int(unitPrice)
		line.UnitCost = int(unitCost)
		line.LineTotal = int(lineTotal)
		detail.Lines = append(detail.Lines, line)
	}
	if err := rows.Err(); err != nil {
		return InventoryDocumentDetail{}, err
	}

	paymentRows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    d.document_no,
		    d.status,
		    COALESCE((SELECT SUM(l.amount) FROM money_document_lines l WHERE l.document_id = d.id), 0),
		    COALESCE((SELECT SUM(mm.amount) FROM money_movements mm WHERE mm.document_id = d.id), 0)
		 FROM money_documents d
		 WHERE d.company_id = $1::uuid AND d.source_module = 'inventory' AND d.source_reference = $2
		 ORDER BY d.created_at ASC`,
		companyID,
		documentID,
	)
	if err != nil {
		return InventoryDocumentDetail{}, err
	}
	defer paymentRows.Close()

	detail.LinkedPayments = make([]InventoryDocumentPayment, 0)
	for paymentRows.Next() {
		var payment InventoryDocumentPayment
		var amount float64
		var paidAmount float64
		if err := paymentRows.Scan(
			&payment.DocumentNo,
			&payment.Status,
			&amount,
			&paidAmount,
		); err != nil {
			return InventoryDocumentDetail{}, err
		}
		payment.Amount = int(amount)
		payment.PaidAmount = int(paidAmount)
		payment.RemainingAmount = payment.Amount - payment.PaidAmount
		detail.LinkedPayments = append(detail.LinkedPayments, payment)
	}

	return detail, paymentRows.Err()
}

func (s *PostgresStore) replaceInventoryDocumentDraftLines(ctx context.Context, tx *sql.Tx, companyID string, documentID string, documentType string, lines []CreateInventoryDocumentLineInput) ([]InventoryDocumentLine, int, int, error) {
	if _, err := tx.ExecContext(ctx, `DELETE FROM inventory_document_lines WHERE document_id = $1::uuid`, documentID); err != nil {
		return nil, 0, 0, err
	}

	detailLines := make([]InventoryDocumentLine, 0, len(lines))
	totalQuantity := 0
	totalAmount := 0
	for index, inputLine := range lines {
		unitPrice := inputLine.UnitPrice
		unitCost := inputLine.UnitCost
		lineTotal := inputLine.Quantity * unitPrice

		if strings.TrimSpace(inputLine.ServiceID) != "" {
			var serviceName string
			var serviceAllowedToSell bool
			if err := tx.QueryRowContext(
				ctx,
				`SELECT name, allowed_to_sell
				 FROM services
				 WHERE id = $1::uuid AND company_id = $2::uuid AND archived_at IS NULL`,
				inputLine.ServiceID,
				companyID,
			).Scan(&serviceName, &serviceAllowedToSell); err != nil {
				if errors.Is(err, sql.ErrNoRows) {
					return nil, 0, 0, fmt.Errorf("%w: service not found", ErrValidation)
				}
				return nil, 0, 0, err
			}
			if documentType == "sale_issue" && !serviceAllowedToSell {
				return nil, 0, 0, fmt.Errorf("%w: service %q is not allowed to sell", ErrValidation, serviceName)
			}
			if _, err := tx.ExecContext(
				ctx,
				`INSERT INTO inventory_document_lines (
				   document_id, line_no, service_id, quantity, unit_price, unit_cost, note, created_at
				 ) VALUES (
				   $1::uuid, $2, $3::uuid, $4, $5, $6, NULLIF($7, ''), NOW()
				 )`,
				documentID,
				index+1,
				inputLine.ServiceID,
				inputLine.Quantity,
				unitPrice,
				unitCost,
				inputLine.Note,
			); err != nil {
				return nil, 0, 0, err
			}
			totalQuantity += inputLine.Quantity
			totalAmount += lineTotal
			detailLines = append(detailLines, InventoryDocumentLine{
				ServiceID: inputLine.ServiceID,
				ItemName:  serviceName,
				ItemType:  "service",
				Quantity:  inputLine.Quantity,
				UnitPrice: unitPrice,
				UnitCost:  unitCost,
				LineTotal: lineTotal,
				Note:      inputLine.Note,
			})
			continue
		}

		product, err := s.findProductByID(ctx, companyID, inputLine.ProductID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return nil, 0, 0, fmt.Errorf("%w: product not found", ErrValidation)
			}
			return nil, 0, 0, err
		}
		if documentType == "sale_issue" && !product.AllowedToSell {
			return nil, 0, 0, fmt.Errorf("%w: product %q is not allowed to sell", ErrValidation, product.Name)
		}
		if unitPrice == 0 {
			unitPrice = product.Price
		}
		if unitCost == 0 {
			unitCost = product.Cost
		}
		lineTotal = inputLine.Quantity * unitPrice
		if _, err := tx.ExecContext(
			ctx,
			`INSERT INTO inventory_document_lines (
			   document_id, line_no, product_id, quantity, unit_price, unit_cost, note, created_at
			 ) VALUES (
			   $1::uuid, $2, $3::uuid, $4, $5, $6, NULLIF($7, ''), NOW()
			 )`,
			documentID,
			index+1,
			product.ID,
			inputLine.Quantity,
			unitPrice,
			unitCost,
			inputLine.Note,
		); err != nil {
			return nil, 0, 0, err
		}
		totalQuantity += inputLine.Quantity
		totalAmount += lineTotal
		detailLines = append(detailLines, InventoryDocumentLine{
			ProductID: product.ID,
			ItemName:  product.Name,
			ItemType:  "product",
			SKU:       product.SKU,
			Quantity:  inputLine.Quantity,
			UnitPrice: unitPrice,
			UnitCost:  unitCost,
			LineTotal: lineTotal,
			Note:      inputLine.Note,
		})
	}

	return detailLines, totalQuantity, totalAmount, nil
}

func inventoryDocumentStatusForCreate(status string) string {
	if status == "draft" {
		return "draft"
	}
	return "posted"
}

type clientRecord struct {
	ID   string
	Name string
}

func (s *PostgresStore) findClientByID(ctx context.Context, companyID string, clientID string) (clientRecord, error) {
	var client clientRecord
	err := s.db.QueryRowContext(
		ctx,
		`SELECT id::text, name
		 FROM clients
		 WHERE id = $1::uuid AND company_id = $2::uuid AND archived_at IS NULL`,
		clientID,
		companyID,
	).Scan(&client.ID, &client.Name)
	if err != nil {
		return clientRecord{}, err
	}
	return client, nil
}

func (s *PostgresStore) createLinkedMoneyDocumentDraft(
	ctx context.Context,
	tx *sql.Tx,
	companyID string,
	inventoryDocumentID string,
	summary InventoryDocumentSummary,
	documentDate time.Time,
) error {
	if summary.ClientID == "" || summary.TotalAmount <= 0 {
		return nil
	}

	documentType := ""
	description := ""
	categoryDirection := ""
	categoryName := ""
	switch summary.DocumentType {
	case "sale_issue":
		documentType = "sale_receivable"
		description = fmt.Sprintf("Оплата по продаже %s", summary.DocumentNo)
		categoryDirection = "income"
		categoryName = "Продажи"
	case "purchase_receipt":
		documentType = "purchase_payable"
		description = fmt.Sprintf("Оплата по закупу %s", summary.DocumentNo)
		categoryDirection = "expense"
		categoryName = "Закуп"
	default:
		return nil
	}

	categoryID, err := s.ensureMoneyCategory(ctx, tx, companyID, categoryDirection, categoryName)
	if err != nil {
		return err
	}

	var moneyDocumentID string
	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO money_documents (
		   company_id, document_no, document_type, status, operation_date, client_id, description, source_module, source_reference, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2, $3, 'draft', $4, $5::uuid, $6, 'inventory', $7::uuid, NOW(), NOW()
		 )
		 RETURNING id::text`,
		companyID,
		fmt.Sprintf("FIN-%s", summary.DocumentNo),
		documentType,
		documentDate.Format("2006-01-02"),
		summary.ClientID,
		description,
		inventoryDocumentID,
	).Scan(&moneyDocumentID); err != nil {
		return err
	}

	_, err = tx.ExecContext(
		ctx,
		`INSERT INTO money_document_lines (
		   document_id, line_no, category_id, amount, note, created_at
		 ) VALUES (
		   $1::uuid, 1, $2::uuid, $3, $4, NOW()
		 )`,
		moneyDocumentID,
		nullUUID(categoryID),
		summary.TotalAmount,
		description,
	)
	return err
}

func (s *PostgresStore) GetFinance(user auth.User) (Finance, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Finance{}, err
	}

	finance := Finance{
		Accounts:          []BankAccount{},
		ExpenseCategories: []ExpenseCategory{},
		Transactions:      []Transaction{},
		CashFlows:         []CashFlow{},
	}

	accountRows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    ca.id::text,
		    ca.name,
		    ca.account_type,
		    COALESCE(cab.balance_amount, ca.opening_balance)
		 FROM cash_accounts ca
		 LEFT JOIN cash_account_balances cab ON cab.account_id = ca.id
		 WHERE ca.company_id = $1::uuid AND ca.archived_at IS NULL
		 ORDER BY ca.created_at DESC`,
		companyID,
	)
	if err != nil {
		return Finance{}, err
	}
	defer accountRows.Close()

	for accountRows.Next() {
		var balance float64
		var accountID string
		var accountType string
		var account BankAccount
		if err := accountRows.Scan(&accountID, &account.Name, &accountType, &balance); err != nil {
			return Finance{}, err
		}

		account.ID = accountID
		account.Balance = int(balance)
		account.Color = accountColorForType(accountType)
		account.Icon = accountIconForType(accountType)
		finance.Accounts = append(finance.Accounts, account)
		finance.TotalBalance += account.Balance
	}
	if err := accountRows.Err(); err != nil {
		return Finance{}, err
	}

	movementRows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    md.document_type,
		    mm.movement_direction,
		    mm.amount,
		    COALESCE(md.description, ''),
		    COALESCE(mc.name, ''),
		    COALESCE(ca.name, ''),
		    mm.happened_at
		 FROM money_movements mm
		 JOIN money_documents md ON md.id = mm.document_id
		 LEFT JOIN money_categories mc ON mc.id = mm.category_id
		 LEFT JOIN cash_accounts ca ON ca.id = mm.account_id
		 WHERE mm.company_id = $1::uuid
		 ORDER BY mm.happened_at DESC, mm.created_at DESC
		 LIMIT 20`,
		companyID,
	)
	if err != nil {
		return Finance{}, err
	}
	defer movementRows.Close()

	expenseByCategory := make(map[string]int)
	for movementRows.Next() {
		var documentType string
		var direction string
		var amount float64
		var description string
		var category string
		var account string
		var happenedAt time.Time
		if err := movementRows.Scan(&documentType, &direction, &amount, &description, &category, &account, &happenedAt); err != nil {
			return Finance{}, err
		}

		roundedAmount := int(amount)
		if documentType != "opening" {
			if direction == "income" || direction == "transfer_in" {
				finance.Income += roundedAmount
			}
			if direction == "expense" || direction == "transfer_out" {
				finance.Expense += roundedAmount
				if category == "" {
					category = "Другое"
				}
				expenseByCategory[category] += roundedAmount
			}
		}

		if description == "" {
			description = defaultMoneyDescription(direction)
		}
		if category == "" {
			category = defaultMoneyCategory(direction)
		}
		if account == "" {
			account = "Без счета"
		}

		transactionType := "expense"
		if direction == "income" || direction == "transfer_in" {
			transactionType = "income"
		}

		finance.Transactions = append(finance.Transactions, Transaction{
			Type:        transactionType,
			Description: description,
			Amount:      roundedAmount,
			Category:    category,
			Date:        happenedAt.Format("2 January"),
			Account:     account,
		})
	}
	if err := movementRows.Err(); err != nil {
		return Finance{}, err
	}

	categoryRows, err := s.db.QueryContext(
		ctx,
		`SELECT name, COALESCE(color_hex, '#64748B')
		 FROM money_categories
		 WHERE company_id = $1::uuid AND direction = 'expense' AND archived_at IS NULL
		 ORDER BY created_at ASC`,
		companyID,
	)
	if err != nil {
		return Finance{}, err
	}
	defer categoryRows.Close()

	seenCategories := make(map[string]bool)
	for categoryRows.Next() {
		var name string
		var color string
		if err := categoryRows.Scan(&name, &color); err != nil {
			return Finance{}, err
		}
		seenCategories[name] = true
		finance.ExpenseCategories = append(finance.ExpenseCategories, ExpenseCategory{
			Name:  name,
			Value: expenseByCategory[name],
			Color: color,
		})
	}
	if err := categoryRows.Err(); err != nil {
		return Finance{}, err
	}

	for name, value := range expenseByCategory {
		if seenCategories[name] {
			continue
		}
		finance.ExpenseCategories = append(finance.ExpenseCategories, ExpenseCategory{
			Name:  name,
			Value: value,
			Color: "#64748B",
		})
	}

	netFlow := finance.Income - finance.Expense
	if finance.Income > 0 {
		finance.CashFlows = append(finance.CashFlows, CashFlow{
			Title:       "Операционная деятельность",
			Subtitle:    "Приток",
			Value:       formatMoneyValue(finance.Income),
			Tone:        "#22C55E",
			ValueColor:  "#22C55E",
			Highlighted: false,
		})
	}
	if finance.Expense > 0 {
		finance.CashFlows = append(finance.CashFlows, CashFlow{
			Title:       "Операционная деятельность",
			Subtitle:    "Отток",
			Value:       formatMoneyValue(finance.Expense),
			Tone:        "#EF4444",
			ValueColor:  "#EF4444",
			Highlighted: false,
		})
	}
	finance.CashFlows = append(finance.CashFlows, CashFlow{
		Title:       "Чистый денежный поток",
		Subtitle:    "За период",
		Value:       formatSignedMoneyValue(netFlow),
		Tone:        netFlowColor(netFlow),
		ValueColor:  netFlowColor(netFlow),
		Highlighted: true,
	})
	return finance, nil
}

func (s *PostgresStore) CreateCashAccount(user auth.User, input CreateCashAccountInput) (BankAccount, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return BankAccount{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return BankAccount{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	normalized := NormalizeCashAccountInput(input)
	var accountID string
	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO cash_accounts (
		   company_id, name, account_type, currency_code, bank_name, iban, bik, opening_balance, is_active, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2, $3, $4, NULLIF($5, ''), NULLIF($6, ''), NULLIF($7, ''), $8, TRUE, NOW(), NOW()
		 )
		 RETURNING id::text`,
		companyID,
		normalized.Name,
		normalized.AccountType,
		normalized.CurrencyCode,
		normalized.BankName,
		normalized.IBAN,
		normalized.BIK,
		normalized.OpeningBalance,
	).Scan(&accountID); err != nil {
		return BankAccount{}, err
	}

	if _, err = tx.ExecContext(
		ctx,
		`INSERT INTO cash_account_balances (account_id, balance_amount, updated_at)
		 VALUES ($1::uuid, $2, NOW())
		 ON CONFLICT (account_id)
		 DO UPDATE SET balance_amount = EXCLUDED.balance_amount, updated_at = NOW()`,
		accountID,
		normalized.OpeningBalance,
	); err != nil {
		return BankAccount{}, err
	}

	if normalized.OpeningBalance > 0 {
		var documentID string
		if err = tx.QueryRowContext(
			ctx,
			`INSERT INTO money_documents (
			   company_id, document_no, document_type, status, operation_date, primary_account_id, description, created_at, updated_at
			 ) VALUES (
			   $1::uuid, $2, 'opening', 'posted', CURRENT_DATE, $3::uuid, $4, NOW(), NOW()
			 )
			 RETURNING id::text`,
			companyID,
			fmt.Sprintf("OPEN-%s", strings.ToUpper(strings.ReplaceAll(normalized.Name, " ", "-"))),
			accountID,
			fmt.Sprintf("Начальный остаток по счету %s", normalized.Name),
		).Scan(&documentID); err != nil {
			return BankAccount{}, err
		}

		var lineID string
		if err = tx.QueryRowContext(
			ctx,
			`INSERT INTO money_document_lines (
			   document_id, line_no, amount, note, created_at
			 ) VALUES (
			   $1::uuid, 1, $2, $3, NOW()
			 )
			 RETURNING id::text`,
			documentID,
			normalized.OpeningBalance,
			"Начальный остаток",
		).Scan(&lineID); err != nil {
			return BankAccount{}, err
		}

		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO money_movements (
			   company_id, account_id, document_id, document_line_id, movement_direction, amount, signed_amount, balance_after, happened_at, created_at
			 ) VALUES (
			   $1::uuid, $2::uuid, $3::uuid, $4::uuid, 'income', $5, $6, $7, NOW(), NOW()
			 )`,
			companyID,
			accountID,
			documentID,
			lineID,
			normalized.OpeningBalance,
			normalized.OpeningBalance,
			normalized.OpeningBalance,
		); err != nil {
			return BankAccount{}, err
		}
	}

	if err = tx.Commit(); err != nil {
		return BankAccount{}, err
	}

	return BankAccount{
		ID:      accountID,
		Name:    normalized.Name,
		Balance: normalized.OpeningBalance,
		Color:   accountColorForType(normalized.AccountType),
		Icon:    accountIconForType(normalized.AccountType),
	}, nil
}

func (s *PostgresStore) CreateMoneyOperation(user auth.User, input CreateMoneyOperationInput) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	normalized := NormalizeMoneyOperationInput(input)
	operationDate := time.Now()
	if normalized.OperationDate != "" {
		operationDate, err = time.Parse("2006-01-02", normalized.OperationDate)
		if err != nil {
			return fmt.Errorf("%w: operation date must be in YYYY-MM-DD format", ErrValidation)
		}
	}

	primaryAccount, err := s.findCashAccount(ctx, tx, companyID, normalized.AccountID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("%w: account not found", ErrValidation)
		}
		return err
	}

	var secondaryAccount cashAccountRecord
	if normalized.Direction == "transfer" {
		secondaryAccount, err = s.findCashAccount(ctx, tx, companyID, normalized.CounterpartyAccountID)
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return fmt.Errorf("%w: counterparty account not found", ErrValidation)
			}
			return err
		}
	}

	categoryID := ""
	if normalized.Direction != "transfer" {
		categoryID, err = s.ensureMoneyCategory(ctx, tx, companyID, normalized.Direction, normalized.Category)
		if err != nil {
			return err
		}
	}

	documentType := moneyDocumentTypeFor(normalized.Direction)
	documentNo := s.nextMoneyDocumentNo(normalized.Direction)
	description := normalized.Description
	if description == "" {
		description = defaultMoneyDescriptionForCreate(normalized.Direction, primaryAccount.Name, secondaryAccount.Name)
	}

	var documentID string
	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO money_documents (
		   company_id, document_no, document_type, status, operation_date, primary_account_id, secondary_account_id, client_id, description, created_by_user_id, posted_by_user_id, posted_at, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2, $3, 'posted', $4, $5::uuid, $6::uuid, $7::uuid, $8, $9, $9, NOW(), NOW(), NOW()
		 )
		 RETURNING id::text`,
		companyID,
		documentNo,
		documentType,
		operationDate.Format("2006-01-02"),
		primaryAccount.ID,
		nullUUID(secondaryAccount.ID),
		nullUUID(normalized.ClientID),
		description,
		user.ID,
	).Scan(&documentID); err != nil {
		return err
	}

	var lineID string
	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO money_document_lines (
		   document_id, line_no, category_id, amount, note, created_at
		 ) VALUES (
		   $1::uuid, 1, $2::uuid, $3, NULLIF($4, ''), NOW()
		 )
		 RETURNING id::text`,
		documentID,
		nullUUID(categoryID),
		normalized.Amount,
		description,
	).Scan(&lineID); err != nil {
		return err
	}

	switch normalized.Direction {
	case "income":
		newBalance := primaryAccount.Balance + normalized.Amount
		if err = s.insertMoneyMovement(ctx, tx, companyID, primaryAccount.ID, documentID, lineID, normalized.ClientID, categoryID, "", "income", normalized.Amount, normalized.Amount, newBalance, operationDate); err != nil {
			return err
		}
		if err = s.upsertCashAccountBalance(ctx, tx, primaryAccount.ID, newBalance); err != nil {
			return err
		}
	case "expense":
		newBalance := primaryAccount.Balance - normalized.Amount
		if err = s.insertMoneyMovement(ctx, tx, companyID, primaryAccount.ID, documentID, lineID, normalized.ClientID, categoryID, "", "expense", normalized.Amount, -normalized.Amount, newBalance, operationDate); err != nil {
			return err
		}
		if err = s.upsertCashAccountBalance(ctx, tx, primaryAccount.ID, newBalance); err != nil {
			return err
		}
	case "transfer":
		transferGroupID, transferErr := generateProductID()
		if transferErr != nil {
			return transferErr
		}
		sourceBalance := primaryAccount.Balance - normalized.Amount
		targetBalance := secondaryAccount.Balance + normalized.Amount
		if err = s.insertMoneyMovement(ctx, tx, companyID, primaryAccount.ID, documentID, lineID, normalized.ClientID, "", transferGroupID, "transfer_out", normalized.Amount, -normalized.Amount, sourceBalance, operationDate); err != nil {
			return err
		}
		if err = s.insertMoneyMovement(ctx, tx, companyID, secondaryAccount.ID, documentID, lineID, normalized.ClientID, "", transferGroupID, "transfer_in", normalized.Amount, normalized.Amount, targetBalance, operationDate); err != nil {
			return err
		}
		if err = s.upsertCashAccountBalance(ctx, tx, primaryAccount.ID, sourceBalance); err != nil {
			return err
		}
		if err = s.upsertCashAccountBalance(ctx, tx, secondaryAccount.ID, targetBalance); err != nil {
			return err
		}
	default:
		return fmt.Errorf("%w: direction is invalid", ErrValidation)
	}

	err = tx.Commit()
	return err
}

func (s *PostgresStore) ListMoneyDocuments(user auth.User, documentType string, search string) ([]MoneyDocumentSummary, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    d.id::text,
		    d.document_no,
		    d.document_type,
		    d.status,
		    d.operation_date,
		    COALESCE(d.description, ''),
		    COALESCE(pa.name, ''),
		    COALESCE(sa.name, ''),
		    COALESCE((SELECT SUM(l.amount) FROM money_document_lines l WHERE l.document_id = d.id), 0),
		    COALESCE((SELECT SUM(mm.amount) FROM money_movements mm WHERE mm.document_id = d.id), 0)
		 FROM money_documents d
		 LEFT JOIN cash_accounts pa ON pa.id = d.primary_account_id
		 LEFT JOIN cash_accounts sa ON sa.id = d.secondary_account_id
		 WHERE d.company_id = $1::uuid
		   AND ($2 = '' OR d.document_type = $2)
		   AND (
		     $3 = ''
		     OR d.document_no ILIKE '%' || $3 || '%'
		     OR COALESCE(d.description, '') ILIKE '%' || $3 || '%'
		     OR COALESCE(pa.name, '') ILIKE '%' || $3 || '%'
		     OR COALESCE(sa.name, '') ILIKE '%' || $3 || '%'
		   )
		 ORDER BY d.operation_date DESC, d.created_at DESC
		 LIMIT 100`,
		companyID,
		documentType,
		search,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	documents := make([]MoneyDocumentSummary, 0)
	for rows.Next() {
		var document MoneyDocumentSummary
		var operationDate time.Time
		var amount float64
		var paidAmount float64
		if err := rows.Scan(
			&document.ID,
			&document.DocumentNo,
			&document.DocumentType,
			&document.Status,
			&operationDate,
			&document.Description,
			&document.PrimaryAccount,
			&document.SecondaryAccount,
			&amount,
			&paidAmount,
		); err != nil {
			return nil, err
		}
		document.OperationDate = operationDate.Format("2006-01-02")
		document.Amount = int(amount)
		document.PaidAmount = int(paidAmount)
		document.RemainingAmount = document.Amount - document.PaidAmount
		documents = append(documents, document)
	}

	return documents, rows.Err()
}

func (s *PostgresStore) GetMoneyDocument(user auth.User, documentID string) (MoneyDocumentDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return MoneyDocumentDetail{}, err
	}

	var detail MoneyDocumentDetail
	var operationDate time.Time
	var amount float64
	var paidAmount float64
	err = s.db.QueryRowContext(
		ctx,
		`SELECT
		    d.id::text,
		    d.document_no,
		    d.document_type,
		    d.status,
		    d.operation_date,
		    COALESCE(d.description, ''),
		    COALESCE(pa.name, ''),
		    COALESCE(sa.name, ''),
		    COALESCE((SELECT SUM(l.amount) FROM money_document_lines l WHERE l.document_id = d.id), 0),
		    COALESCE((SELECT SUM(mm.amount) FROM money_movements mm WHERE mm.document_id = d.id), 0)
		 FROM money_documents d
		 LEFT JOIN cash_accounts pa ON pa.id = d.primary_account_id
		 LEFT JOIN cash_accounts sa ON sa.id = d.secondary_account_id
		 WHERE d.company_id = $1::uuid AND d.id = $2::uuid`,
		companyID,
		documentID,
	).Scan(
		&detail.Summary.ID,
		&detail.Summary.DocumentNo,
		&detail.Summary.DocumentType,
		&detail.Summary.Status,
		&operationDate,
		&detail.Summary.Description,
		&detail.Summary.PrimaryAccount,
		&detail.Summary.SecondaryAccount,
		&amount,
		&paidAmount,
	)
	if err != nil {
		return MoneyDocumentDetail{}, err
	}
	detail.Summary.OperationDate = operationDate.Format("2006-01-02")
	detail.Summary.Amount = int(amount)
	detail.Summary.PaidAmount = int(paidAmount)
	detail.Summary.RemainingAmount = detail.Summary.Amount - detail.Summary.PaidAmount

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    COALESCE(mc.name, ''),
		    l.amount,
		    COALESCE(l.note, '')
		 FROM money_document_lines l
		 LEFT JOIN money_categories mc ON mc.id = l.category_id
		 WHERE l.document_id = $1::uuid
		 ORDER BY l.line_no ASC`,
		documentID,
	)
	if err != nil {
		return MoneyDocumentDetail{}, err
	}
	defer rows.Close()

	detail.Lines = make([]MoneyDocumentLine, 0)
	for rows.Next() {
		var line MoneyDocumentLine
		var lineAmount float64
		if err := rows.Scan(&line.Category, &lineAmount, &line.Note); err != nil {
			return MoneyDocumentDetail{}, err
		}
		line.Amount = int(lineAmount)
		detail.Lines = append(detail.Lines, line)
	}

	return detail, rows.Err()
}

func (s *PostgresStore) SettleMoneyDocument(user auth.User, documentID string, input SettleMoneyDocumentInput) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	normalized := NormalizeSettleMoneyDocumentInput(input)
	operationDate := time.Now()
	if normalized.OperationDate != "" {
		operationDate, err = time.Parse("2006-01-02", normalized.OperationDate)
		if err != nil {
			return fmt.Errorf("%w: operation date must be in YYYY-MM-DD format", ErrValidation)
		}
	}

	account, err := s.findCashAccount(ctx, tx, companyID, normalized.AccountID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("%w: account not found", ErrValidation)
		}
		return err
	}

	var draftType string
	var draftStatus string
	var clientID string
	var currentDescription string
	err = tx.QueryRowContext(
		ctx,
		`SELECT
		    d.document_type,
		    d.status,
		    COALESCE(d.client_id::text, ''),
		    COALESCE(d.description, '')
		 FROM money_documents d
		 WHERE d.company_id = $1::uuid AND d.id = $2::uuid`,
		companyID,
		documentID,
	).Scan(&draftType, &draftStatus, &clientID, &currentDescription)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("%w: money document not found", ErrValidation)
		}
		return err
	}

	if draftStatus != "draft" && draftStatus != "partial" {
		return fmt.Errorf("%w: only draft or partial money documents can be settled", ErrValidation)
	}

	direction := ""
	categoryName := ""
	switch draftType {
	case "sale_receivable":
		direction = "income"
		categoryName = "Продажи"
	case "purchase_payable":
		direction = "expense"
		categoryName = "Закуп"
	default:
		return fmt.Errorf("%w: this document type cannot be settled", ErrValidation)
	}

	categoryID, err := s.ensureMoneyCategory(ctx, tx, companyID, direction, categoryName)
	if err != nil {
		return err
	}

	lineRows, err := tx.QueryContext(
		ctx,
		`SELECT id::text, amount
		 FROM money_document_lines
		 WHERE document_id = $1::uuid
		 ORDER BY line_no ASC`,
		documentID,
	)
	if err != nil {
		return err
	}
	defer lineRows.Close()

	type moneyDraftLine struct {
		id     string
		amount int
	}
	lines := make([]moneyDraftLine, 0)
	for lineRows.Next() {
		var lineID string
		var amount float64
		if err := lineRows.Scan(&lineID, &amount); err != nil {
			return err
		}
		lines = append(lines, moneyDraftLine{id: lineID, amount: int(amount)})
	}
	if err := lineRows.Err(); err != nil {
		return err
	}
	if len(lines) == 0 {
		return fmt.Errorf("%w: money document has no lines", ErrValidation)
	}

	paidRows, err := tx.QueryContext(
		ctx,
		`SELECT document_line_id::text, COALESCE(SUM(amount), 0)
		 FROM money_movements
		 WHERE document_id = $1::uuid
		 GROUP BY document_line_id`,
		documentID,
	)
	if err != nil {
		return err
	}
	defer paidRows.Close()

	paidByLineID := make(map[string]int, len(lines))
	totalAmount := 0
	paidAmount := 0
	for _, line := range lines {
		totalAmount += line.amount
	}
	for paidRows.Next() {
		var lineID string
		var amount float64
		if err := paidRows.Scan(&lineID, &amount); err != nil {
			return err
		}
		paidByLineID[lineID] = int(amount)
		paidAmount += int(amount)
	}
	if err := paidRows.Err(); err != nil {
		return err
	}

	remainingAmount := totalAmount - paidAmount
	if remainingAmount <= 0 {
		return fmt.Errorf("%w: money document is already fully settled", ErrValidation)
	}
	if normalized.Amount > remainingAmount {
		return fmt.Errorf("%w: amount exceeds remaining balance", ErrValidation)
	}

	description := normalized.Description
	if description == "" {
		description = currentDescription
	}

	currentBalance := account.Balance
	amountToSettle := normalized.Amount
	for _, line := range lines {
		if amountToSettle == 0 {
			break
		}

		lineRemaining := line.amount - paidByLineID[line.id]
		if lineRemaining <= 0 {
			continue
		}
		movementAmount := lineRemaining
		if movementAmount > amountToSettle {
			movementAmount = amountToSettle
		}

		if direction == "income" {
			currentBalance += movementAmount
			if err = s.insertMoneyMovement(ctx, tx, companyID, account.ID, documentID, line.id, clientID, categoryID, "", "income", movementAmount, movementAmount, currentBalance, operationDate); err != nil {
				return err
			}
		} else {
			currentBalance -= movementAmount
			if err = s.insertMoneyMovement(ctx, tx, companyID, account.ID, documentID, line.id, clientID, categoryID, "", "expense", movementAmount, -movementAmount, currentBalance, operationDate); err != nil {
				return err
			}
		}
		amountToSettle -= movementAmount
	}
	if amountToSettle != 0 {
		return fmt.Errorf("%w: unable to distribute settlement amount", ErrValidation)
	}

	if err = s.upsertCashAccountBalance(ctx, tx, account.ID, currentBalance); err != nil {
		return err
	}

	newPaidAmount := paidAmount + normalized.Amount
	newStatus := "partial"
	if newPaidAmount >= totalAmount {
		newStatus = "posted"
	}

	if _, err = tx.ExecContext(
		ctx,
		`UPDATE money_documents
		 SET primary_account_id = $3::uuid,
		     status = $4,
		     operation_date = $5,
		     description = $6,
		     posted_by_user_id = $7,
		     posted_at = NOW(),
		     updated_at = NOW()
		 WHERE company_id = $1::uuid AND id = $2::uuid`,
		companyID,
		documentID,
		account.ID,
		newStatus,
		operationDate.Format("2006-01-02"),
		description,
		user.ID,
	); err != nil {
		return err
	}

	err = tx.Commit()
	return err
}

func (s *PostgresStore) ensurePrimaryCompany(ctx context.Context, user auth.User) (string, error) {
	// If the request specifies an active company, use it after verifying the
	// user is a member of it. This powers multi-company switching.
	if active := strings.TrimSpace(user.ActiveCompanyID); active != "" {
		var found string
		err := s.db.QueryRowContext(
			ctx,
			`SELECT cm.company_id::text
			 FROM company_memberships cm
			 WHERE cm.user_id = $1 AND cm.company_id = $2::uuid
			 LIMIT 1`,
			user.ID,
			active,
		).Scan(&found)
		if err == nil {
			return found, nil
		}
		if errors.Is(err, sql.ErrNoRows) {
			return "", fmt.Errorf("%w: no access to the requested company", ErrValidation)
		}
		return "", err
	}

	var companyID string
	err := s.db.QueryRowContext(
		ctx,
		`SELECT cm.company_id::text
		 FROM company_memberships cm
		 WHERE cm.user_id = $1
		 ORDER BY cm.is_default_company DESC, cm.created_at ASC
		 LIMIT 1`,
		user.ID,
	).Scan(&companyID)
	if err == nil {
		return companyID, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}

	return s.provisionCompanies(ctx, user)
}

func (s *PostgresStore) provisionCompanies(ctx context.Context, user auth.User) (string, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	companies := user.Companies
	if len(companies) == 0 {
		companies = []auth.Company{{
			Name:    `ТОО "Мой Бизнес"`,
			Country: "KZ",
		}}
	}

	var defaultCompanyID string
	for index, company := range companies {
		var companyID string
		if err = tx.QueryRowContext(
			ctx,
			`INSERT INTO companies (
			   owner_user_id, name, country_code, tax_identifier, created_at, updated_at
			 ) VALUES ($1, $2, $3, NULLIF($4, ''), NOW(), NOW())
			 RETURNING id::text`,
			user.ID,
			company.Name,
			strings.ToUpper(company.Country),
			company.IIN,
		).Scan(&companyID); err != nil {
			return "", err
		}

		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO company_memberships (
			   company_id, user_id, role, is_default_company, accepted_at, created_at, updated_at
			 ) VALUES ($1::uuid, $2, 'owner', $3, NOW(), NOW(), NOW())`,
			companyID,
			user.ID,
			index == 0,
		); err != nil {
			return "", err
		}

		if index == 0 {
			defaultCompanyID = companyID
		}
	}

	if err = tx.Commit(); err != nil {
		return "", err
	}

	return defaultCompanyID, nil
}

func (s *PostgresStore) ListUserCompanies(user auth.User) ([]CompanyMembership, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	// Ensure the user has at least the default company provisioned.
	if _, err := s.ensurePrimaryCompanyDefault(ctx, user); err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    c.id::text,
		    c.name,
		    c.country_code,
		    COALESCE(c.tax_identifier, ''),
		    c.logo_updated_at,
		    cm.role,
		    cm.is_default_company
		 FROM company_memberships cm
		 JOIN companies c ON c.id = cm.company_id
		 WHERE cm.user_id = $1 AND c.archived_at IS NULL
		 ORDER BY cm.is_default_company DESC, c.created_at ASC`,
		user.ID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	companies := make([]CompanyMembership, 0)
	for rows.Next() {
		var company CompanyMembership
		var logoUpdatedAt sql.NullTime
		if err := rows.Scan(
			&company.ID,
			&company.Name,
			&company.Country,
			&company.IIN,
			&logoUpdatedAt,
			&company.Role,
			&company.IsDefault,
		); err != nil {
			return nil, err
		}
		if logoUpdatedAt.Valid {
			company.LogoURL = companyLogoURL(company.ID, logoUpdatedAt.Time)
		}
		companies = append(companies, company)
	}
	return companies, rows.Err()
}

// ensurePrimaryCompanyDefault resolves (and lazily provisions) the user's
// default company, ignoring any active-company header. Used when we explicitly
// need the user to have at least one company.
func (s *PostgresStore) ensurePrimaryCompanyDefault(ctx context.Context, user auth.User) (string, error) {
	plain := user
	plain.ActiveCompanyID = ""
	return s.ensurePrimaryCompany(ctx, plain)
}

func (s *PostgresStore) CreateCompany(user auth.User, input CreateCompanyInput) (CompanyMembership, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	normalized := NormalizeCompanyInput(input)
	if err := ValidateCompanyInput(normalized); err != nil {
		return CompanyMembership{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return CompanyMembership{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	var companyID string
	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO companies (
		   owner_user_id, name, country_code, tax_identifier, created_at, updated_at
		 ) VALUES ($1, $2, $3, NULLIF($4, ''), NOW(), NOW())
		 RETURNING id::text`,
		user.ID,
		normalized.Name,
		normalized.Country,
		normalized.IIN,
	).Scan(&companyID); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return CompanyMembership{}, fmt.Errorf("%w: компания с таким названием уже существует", ErrValidation)
		}
		return CompanyMembership{}, err
	}

	if _, err = tx.ExecContext(
		ctx,
		`INSERT INTO company_memberships (
		   company_id, user_id, role, is_default_company, accepted_at, created_at, updated_at
		 ) VALUES ($1::uuid, $2, 'owner', FALSE, NOW(), NOW(), NOW())`,
		companyID,
		user.ID,
	); err != nil {
		return CompanyMembership{}, err
	}

	if err = s.syncOwnedCompaniesSnapshot(ctx, tx, user.ID); err != nil {
		return CompanyMembership{}, err
	}

	if err = tx.Commit(); err != nil {
		return CompanyMembership{}, err
	}

	return CompanyMembership{
		ID:        companyID,
		Name:      normalized.Name,
		Country:   normalized.Country,
		IIN:       normalized.IIN,
		Role:      "owner",
		IsDefault: false,
	}, nil
}

func (s *PostgresStore) ListCompanyMembers(user auth.User, companyID string) ([]CompanyMember, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	actorRole, err := s.actorRoleForCompany(ctx, user.ID, companyID)
	if err != nil {
		return nil, err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return nil, fmt.Errorf("%w: no access to the requested company", ErrValidation)
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    u.id,
		    u.full_name,
		    u.phone,
		    cm.role,
		    cm.created_at
		 FROM company_memberships cm
		 JOIN users u ON u.id = cm.user_id
		 WHERE cm.company_id = $1::uuid
		 ORDER BY
		   CASE cm.role
		     WHEN 'owner' THEN 0
		     WHEN 'admin' THEN 1
		     WHEN 'manager' THEN 2
		     WHEN 'accountant' THEN 3
		     WHEN 'warehouse' THEN 4
		     WHEN 'sales' THEN 5
		     ELSE 6
		   END,
		   cm.created_at ASC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	members := make([]CompanyMember, 0)
	for rows.Next() {
		var member CompanyMember
		var joinedAt time.Time
		if err := rows.Scan(
			&member.UserID,
			&member.FullName,
			&member.Phone,
			&member.Role,
			&joinedAt,
		); err != nil {
			return nil, err
		}
		member.RoleLabel = companyRoleLabel(member.Role)
		member.IsOwner = member.Role == "owner"
		member.IsCurrentUser = member.UserID == user.ID
		member.JoinedAt = joinedAt.UTC().Format(time.RFC3339)
		members = append(members, member)
	}
	return members, rows.Err()
}

func (s *PostgresStore) AddCompanyMember(user auth.User, companyID string, input AddCompanyMemberInput) (CompanyMember, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	normalized := NormalizeAddCompanyMemberInput(input)
	if err := ValidateAddCompanyMemberInput(normalized); err != nil {
		return CompanyMember{}, err
	}

	// Only owners/admins of the company may add members.
	actorRole, err := s.actorRoleForCompany(ctx, user.ID, companyID)
	if err != nil {
		return CompanyMember{}, err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return CompanyMember{}, fmt.Errorf("%w: only owners or admins can add members", ErrValidation)
	}

	// Find the invited user by phone.
	var invitedUserID string
	var invitedFullName string
	var invitedPhone string
	err = s.db.QueryRowContext(
		ctx,
		`SELECT id, full_name, phone FROM users WHERE phone = $1`,
		normalized.Phone,
	).Scan(&invitedUserID, &invitedFullName, &invitedPhone)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return CompanyMember{}, fmt.Errorf("%w: no registered user with this phone", ErrValidation)
		}
		return CompanyMember{}, err
	}

	var joinedAt time.Time
	err = s.db.QueryRowContext(
		ctx,
		`INSERT INTO company_memberships (
		   company_id, user_id, role, is_default_company, accepted_at, created_at, updated_at
		 ) VALUES ($1::uuid, $2, $3, FALSE, NOW(), NOW(), NOW())
		 ON CONFLICT (company_id, user_id)
		 DO UPDATE SET role = EXCLUDED.role, accepted_at = NOW(), updated_at = NOW()
		 RETURNING created_at`,
		companyID,
		invitedUserID,
		normalized.Role,
	).Scan(&joinedAt)
	if err != nil {
		return CompanyMember{}, err
	}

	return CompanyMember{
		UserID:        invitedUserID,
		FullName:      invitedFullName,
		Phone:         invitedPhone,
		Role:          normalized.Role,
		RoleLabel:     companyRoleLabel(normalized.Role),
		IsOwner:       false,
		IsCurrentUser: invitedUserID == user.ID,
		JoinedAt:      joinedAt.UTC().Format(time.RFC3339),
	}, nil
}

func (s *PostgresStore) UpdateCompanyMemberRole(user auth.User, companyID string, memberUserID string, input UpdateCompanyMemberRoleInput) (CompanyMember, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	normalized := NormalizeUpdateCompanyMemberRoleInput(input)
	if err := ValidateUpdateCompanyMemberRoleInput(normalized); err != nil {
		return CompanyMember{}, err
	}

	actorRole, err := s.actorRoleForCompany(ctx, user.ID, companyID)
	if err != nil {
		return CompanyMember{}, err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return CompanyMember{}, fmt.Errorf("%w: only owners or admins can manage members", ErrValidation)
	}
	if actorRole == "admin" && memberUserID == user.ID {
		return CompanyMember{}, fmt.Errorf("%w: admins cannot change their own role", ErrValidation)
	}

	var targetRole string
	var joinedAt time.Time
	var fullName string
	var phone string
	err = s.db.QueryRowContext(
		ctx,
		`SELECT cm.role, cm.created_at, u.full_name, u.phone
		 FROM company_memberships cm
		 JOIN users u ON u.id = cm.user_id
		 WHERE cm.company_id = $1::uuid AND cm.user_id = $2`,
		companyID,
		memberUserID,
	).Scan(&targetRole, &joinedAt, &fullName, &phone)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return CompanyMember{}, fmt.Errorf("%w: member not found", ErrValidation)
		}
		return CompanyMember{}, err
	}
	if targetRole == "owner" {
		return CompanyMember{}, fmt.Errorf("%w: owner role cannot be changed", ErrValidation)
	}

	if _, err = s.db.ExecContext(
		ctx,
		`UPDATE company_memberships
		 SET role = $3, updated_at = NOW()
		 WHERE company_id = $1::uuid AND user_id = $2`,
		companyID,
		memberUserID,
		normalized.Role,
	); err != nil {
		return CompanyMember{}, err
	}

	return CompanyMember{
		UserID:        memberUserID,
		FullName:      fullName,
		Phone:         phone,
		Role:          normalized.Role,
		RoleLabel:     companyRoleLabel(normalized.Role),
		IsOwner:       false,
		IsCurrentUser: memberUserID == user.ID,
		JoinedAt:      joinedAt.UTC().Format(time.RFC3339),
	}, nil
}

func (s *PostgresStore) RemoveCompanyMember(user auth.User, companyID string, memberUserID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	actorRole, err := s.actorRoleForCompany(ctx, user.ID, companyID)
	if err != nil {
		return err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return fmt.Errorf("%w: only owners or admins can manage members", ErrValidation)
	}
	if actorRole == "admin" && memberUserID == user.ID {
		return fmt.Errorf("%w: admins cannot remove themselves", ErrValidation)
	}

	var targetRole string
	err = s.db.QueryRowContext(
		ctx,
		`SELECT role
		 FROM company_memberships
		 WHERE company_id = $1::uuid AND user_id = $2`,
		companyID,
		memberUserID,
	).Scan(&targetRole)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("%w: member not found", ErrValidation)
		}
		return err
	}
	if targetRole == "owner" {
		return fmt.Errorf("%w: owner cannot be removed", ErrValidation)
	}

	result, err := s.db.ExecContext(
		ctx,
		`DELETE FROM company_memberships
		 WHERE company_id = $1::uuid AND user_id = $2`,
		companyID,
		memberUserID,
	)
	if err != nil {
		return err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return fmt.Errorf("%w: member not found", ErrValidation)
	}
	return nil
}

func (s *PostgresStore) SetDefaultCompany(user auth.User, companyID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	// Verify membership.
	var exists string
	if err = tx.QueryRowContext(
		ctx,
		`SELECT company_id::text FROM company_memberships
		 WHERE user_id = $1 AND company_id = $2::uuid`,
		user.ID,
		companyID,
	).Scan(&exists); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("%w: no access to the requested company", ErrValidation)
		}
		return err
	}

	// Clear the current default first (partial unique index requires it).
	if _, err = tx.ExecContext(
		ctx,
		`UPDATE company_memberships
		 SET is_default_company = FALSE, updated_at = NOW()
		 WHERE user_id = $1 AND is_default_company = TRUE`,
		user.ID,
	); err != nil {
		return err
	}

	if _, err = tx.ExecContext(
		ctx,
		`UPDATE company_memberships
		 SET is_default_company = TRUE, updated_at = NOW()
		 WHERE user_id = $1 AND company_id = $2::uuid`,
		user.ID,
		companyID,
	); err != nil {
		return err
	}

	return tx.Commit()
}

func (s *PostgresStore) actorRoleForCompany(ctx context.Context, userID string, companyID string) (string, error) {
	var actorRole string
	err := s.db.QueryRowContext(
		ctx,
		`SELECT role FROM company_memberships
		 WHERE user_id = $1 AND company_id = $2::uuid`,
		userID,
		companyID,
	).Scan(&actorRole)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", fmt.Errorf("%w: no access to the requested company", ErrValidation)
		}
		return "", err
	}
	return actorRole, nil
}

func (s *PostgresStore) GetCompany(user auth.User, companyID string) (CompanyDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	var detail CompanyDetail
	var logoUpdatedAt sql.NullTime
	err := s.db.QueryRowContext(
		ctx,
		`SELECT
		    c.id::text,
		    c.name,
		    COALESCE(c.legal_form, ''),
		    c.country_code,
		    COALESCE(c.tax_identifier, ''),
		    COALESCE(c.registration_number, ''),
		    COALESCE(c.email, ''),
		    COALESCE(c.phone, ''),
		    COALESCE(c.address_line, ''),
		    COALESCE(c.city, ''),
		    COALESCE(c.region, ''),
		    COALESCE(c.postal_code, ''),
		    COALESCE(c.bank_name, ''),
		    COALESCE(c.bank_account, ''),
		    COALESCE(c.bank_bik, ''),
		    c.logo_updated_at,
		    c.is_vat_payer,
		    cm.role,
		    cm.is_default_company
		 FROM companies c
		 JOIN company_memberships cm
		   ON cm.company_id = c.id AND cm.user_id = $1
		 WHERE c.id = $2::uuid AND c.archived_at IS NULL`,
		user.ID,
		companyID,
	).Scan(
		&detail.ID,
		&detail.Name,
		&detail.LegalForm,
		&detail.Country,
		&detail.IIN,
		&detail.RegistrationNo,
		&detail.Email,
		&detail.Phone,
		&detail.AddressLine,
		&detail.City,
		&detail.Region,
		&detail.PostalCode,
		&detail.BankName,
		&detail.BankAccount,
		&detail.BankBik,
		&logoUpdatedAt,
		&detail.IsVatPayer,
		&detail.Role,
		&detail.IsDefault,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return CompanyDetail{}, fmt.Errorf("%w: company not found or no access", ErrValidation)
		}
		return CompanyDetail{}, err
	}
	if logoUpdatedAt.Valid {
		detail.LogoURL = companyLogoURL(detail.ID, logoUpdatedAt.Time)
	}
	return detail, nil
}

func (s *PostgresStore) UpdateCompany(user auth.User, companyID string, input UpdateCompanyInput) (CompanyDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	normalized := NormalizeUpdateCompanyInput(input)
	if err := ValidateUpdateCompanyInput(normalized); err != nil {
		return CompanyDetail{}, err
	}

	// Only owners and admins may edit company data.
	var actorRole string
	err := s.db.QueryRowContext(
		ctx,
		`SELECT role FROM company_memberships
		 WHERE user_id = $1 AND company_id = $2::uuid`,
		user.ID,
		companyID,
	).Scan(&actorRole)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return CompanyDetail{}, fmt.Errorf("%w: no access to the requested company", ErrValidation)
		}
		return CompanyDetail{}, err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return CompanyDetail{}, fmt.Errorf("%w: only owners and admins can edit company details", ErrValidation)
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return CompanyDetail{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	var pgErr *pgconn.PgError
	result, err := tx.ExecContext(
		ctx,
		`UPDATE companies SET
		    name              = $3,
		    legal_form        = NULLIF($4, ''),
		    country_code      = $5,
		    tax_identifier    = NULLIF($6, ''),
		    email             = NULLIF($7, ''),
		    phone             = NULLIF($8, ''),
		    address_line      = NULLIF($9, ''),
		    city              = NULLIF($10, ''),
		    region            = NULLIF($11, ''),
		    postal_code       = NULLIF($12, ''),
		    bank_name         = NULLIF($13, ''),
		    bank_account      = NULLIF($14, ''),
		    bank_bik          = NULLIF($15, ''),
		    is_vat_payer      = $16,
		    updated_at        = NOW()
		 WHERE id = $1::uuid`,
		companyID,
		normalized.Name,
		normalized.LegalForm,
		normalized.Country,
		normalized.IIN,
		normalized.Email,
		normalized.Phone,
		normalized.AddressLine,
		normalized.City,
		normalized.Region,
		normalized.PostalCode,
		normalized.BankName,
		normalized.BankAccount,
		normalized.BankBik,
		normalized.IsVatPayer,
	)
	if err != nil {
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return CompanyDetail{}, fmt.Errorf("%w: компания с таким названием уже существует", ErrValidation)
		}
		return CompanyDetail{}, err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return CompanyDetail{}, err
	}
	if rowsAffected == 0 {
		return CompanyDetail{}, fmt.Errorf("%w: company not found", ErrValidation)
	}

	if err = s.syncOwnedCompaniesSnapshot(ctx, tx, user.ID); err != nil {
		return CompanyDetail{}, err
	}

	if err = tx.Commit(); err != nil {
		return CompanyDetail{}, err
	}

	return s.GetCompany(user, companyID)
}

func (s *PostgresStore) GetCompanyLogo(user auth.User, companyID string) ([]byte, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	var logo []byte
	err := s.db.QueryRowContext(
		ctx,
		`SELECT c.logo_png
		 FROM companies c
		 JOIN company_memberships cm
		   ON cm.company_id = c.id AND cm.user_id = $1
		 WHERE c.id = $2::uuid AND c.archived_at IS NULL`,
		user.ID,
		companyID,
	).Scan(&logo)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("%w: company not found or no access", ErrValidation)
		}
		return nil, err
	}
	if len(logo) == 0 {
		return nil, fmt.Errorf("%w: company logo not found", ErrValidation)
	}
	return logo, nil
}

func (s *PostgresStore) UpdateCompanyLogo(user auth.User, companyID string, logoPNG []byte) (CompanyDetail, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	actorRole, err := s.actorRoleForCompany(ctx, user.ID, companyID)
	if err != nil {
		return CompanyDetail{}, err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return CompanyDetail{}, fmt.Errorf("%w: only owners and admins can edit company details", ErrValidation)
	}

	result, err := s.db.ExecContext(
		ctx,
		`UPDATE companies SET
		    logo_png        = $2,
		    logo_updated_at = NOW(),
		    updated_at      = NOW()
		 WHERE id = $1::uuid`,
		companyID,
		logoPNG,
	)
	if err != nil {
		return CompanyDetail{}, err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return CompanyDetail{}, err
	}
	if rowsAffected == 0 {
		return CompanyDetail{}, fmt.Errorf("%w: company not found", ErrValidation)
	}

	return s.GetCompany(user, companyID)
}

func (s *PostgresStore) withTimeout() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), s.queryTimeout)
}

func (s *PostgresStore) syncOwnedCompaniesSnapshot(ctx context.Context, tx *sql.Tx, userID string) error {
	rows, err := tx.QueryContext(
		ctx,
		`SELECT name, country_code, COALESCE(tax_identifier, '')
		 FROM companies
		 WHERE owner_user_id = $1 AND archived_at IS NULL
		 ORDER BY created_at ASC`,
		userID,
	)
	if err != nil {
		return err
	}
	defer rows.Close()

	companies := make([]auth.Company, 0)
	for rows.Next() {
		var company auth.Company
		if err := rows.Scan(&company.Name, &company.Country, &company.IIN); err != nil {
			return err
		}
		companies = append(companies, company)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	payload, err := json.Marshal(companies)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(
		ctx,
		`UPDATE users
		 SET companies_json = $2
		 WHERE id = $1`,
		userID,
		string(payload),
	)
	return err
}

func (s *PostgresStore) findProductByID(ctx context.Context, companyID string, productID string) (Product, error) {
	var product Product
	var quantity float64
	var minQuantity float64
	var price float64
	var cost float64
	err := s.db.QueryRowContext(
		ctx,
		`SELECT
		    p.id::text,
		    p.name,
		    p.sku,
		    COALESCE(pc.name, ''),
		    COALESCE(SUM(ib.quantity_on_hand), 0),
		    p.min_quantity,
		    p.sale_price,
		    p.cost_price,
		    COALESCE(p.barcode, ''),
		    COALESCE(p.allowed_to_sell, TRUE)
		 FROM products p
		 LEFT JOIN product_categories pc ON pc.id = p.category_id
		 LEFT JOIN inventory_balances ib ON ib.product_id = p.id AND ib.company_id = p.company_id
		 WHERE p.id = $1::uuid AND p.company_id = $2::uuid AND p.archived_at IS NULL
		 GROUP BY p.id, p.name, p.sku, pc.name, p.min_quantity, p.sale_price, p.cost_price, p.barcode, p.allowed_to_sell`,
		productID,
		companyID,
	).Scan(
		&product.ID,
		&product.Name,
		&product.SKU,
		&product.Category,
		&quantity,
		&minQuantity,
		&price,
		&cost,
		&product.Barcode,
		&product.AllowedToSell,
	)
	if err != nil {
		return Product{}, err
	}

	product.Quantity = int(quantity)
	product.MinQuantity = int(minQuantity)
	product.Price = int(price)
	product.Cost = int(cost)
	product.Status = productStatus(product.Quantity, product.MinQuantity)
	product.Movements = []StockMovement{}
	return product, nil
}

func (s *PostgresStore) ensureDefaultWarehouse(ctx context.Context, tx *sql.Tx, companyID string) (string, error) {
	var warehouseID string
	err := tx.QueryRowContext(
		ctx,
		`SELECT id::text
		 FROM warehouses
		 WHERE company_id = $1::uuid AND archived_at IS NULL
		 ORDER BY created_at ASC
		 LIMIT 1`,
		companyID,
	).Scan(&warehouseID)
	if err == nil {
		return warehouseID, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}

	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO warehouses (
		   company_id, code, name, warehouse_type, is_active, created_at, updated_at
		 ) VALUES ($1::uuid, 'MAIN', 'Основной склад', 'storage', TRUE, NOW(), NOW())
		 RETURNING id::text`,
		companyID,
	).Scan(&warehouseID); err != nil {
		return "", err
	}

	return warehouseID, nil
}

func (s *PostgresStore) ensureProductCategory(ctx context.Context, tx *sql.Tx, companyID string, name string) (string, error) {
	normalizedName := strings.TrimSpace(name)
	if normalizedName == "" {
		return "", nil
	}

	var categoryID string
	err := tx.QueryRowContext(
		ctx,
		`SELECT id::text
		 FROM product_categories
		 WHERE company_id = $1::uuid AND lower(name) = lower($2) AND archived_at IS NULL
		 LIMIT 1`,
		companyID,
		normalizedName,
	).Scan(&categoryID)
	if err == nil {
		return categoryID, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}

	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO product_categories (company_id, name, created_at, updated_at)
		 VALUES ($1::uuid, $2, NOW(), NOW())
		 RETURNING id::text`,
		companyID,
		normalizedName,
	).Scan(&categoryID); err != nil {
		return "", err
	}

	return categoryID, nil
}

func (s *PostgresStore) createOpeningInventory(ctx context.Context, tx *sql.Tx, companyID string, warehouseID string, product Product) error {
	documentNo := fmt.Sprintf("OPEN-%s", product.SKU)
	var documentID string
	if err := tx.QueryRowContext(
		ctx,
		`INSERT INTO inventory_documents (
		   company_id, document_no, document_type, status, document_date, warehouse_id, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2, 'opening', 'posted', CURRENT_DATE, $3::uuid, NOW(), NOW()
		 )
		 RETURNING id::text`,
		companyID,
		documentNo,
		warehouseID,
	).Scan(&documentID); err != nil {
		return err
	}

	var lineID string
	if err := tx.QueryRowContext(
		ctx,
		`INSERT INTO inventory_document_lines (
		   document_id, line_no, product_id, quantity, unit_price, unit_cost, created_at
		 ) VALUES (
		   $1::uuid, 1, $2::uuid, $3, $4, $5, NOW()
		 )
		 RETURNING id::text`,
		documentID,
		product.ID,
		product.Quantity,
		product.Price,
		product.Cost,
	).Scan(&lineID); err != nil {
		return err
	}

	if _, err := tx.ExecContext(
		ctx,
		`INSERT INTO inventory_movements (
		   company_id, warehouse_id, product_id, document_id, document_line_id, movement_type, quantity_delta, unit_cost, total_cost, balance_after, happened_at, created_at
		 ) VALUES (
		   $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::uuid, 'in', $6, $7, $8, $9, NOW(), NOW()
		 )`,
		companyID,
		warehouseID,
		product.ID,
		documentID,
		lineID,
		product.Quantity,
		product.Cost,
		product.Quantity*product.Cost,
		product.Quantity,
	); err != nil {
		return err
	}

	_, err := tx.ExecContext(
		ctx,
		`INSERT INTO inventory_balances (
		   company_id, warehouse_id, product_id, quantity_on_hand, quantity_reserved, average_cost, updated_at
		 ) VALUES (
		   $1::uuid, $2::uuid, $3::uuid, $4, 0, $5, NOW()
		 )
		 ON CONFLICT (company_id, warehouse_id, product_id)
		 DO UPDATE SET
		   quantity_on_hand = EXCLUDED.quantity_on_hand,
		   average_cost = EXCLUDED.average_cost,
		   updated_at = NOW()`,
		companyID,
		warehouseID,
		product.ID,
		product.Quantity,
		product.Cost,
	)
	return err
}

func (s *PostgresStore) ensureWarehouse(ctx context.Context, tx *sql.Tx, companyID string, name string, fallbackCode string, fallbackName string) (string, string, error) {
	normalizedName := strings.TrimSpace(name)
	if normalizedName == "" {
		normalizedName = fallbackName
	}

	var warehouseID string
	var warehouseName string
	err := tx.QueryRowContext(
		ctx,
		`SELECT id::text, name
		 FROM warehouses
		 WHERE company_id = $1::uuid AND lower(name) = lower($2) AND archived_at IS NULL
		 LIMIT 1`,
		companyID,
		normalizedName,
	).Scan(&warehouseID, &warehouseName)
	if err == nil {
		return warehouseID, warehouseName, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", "", err
	}

	code := fallbackCode
	if code == "" {
		code = strings.ToUpper(strings.ReplaceAll(normalizedName, " ", "_"))
	}

	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO warehouses (
		   company_id, code, name, warehouse_type, is_active, created_at, updated_at
		 ) VALUES ($1::uuid, $2, $3, 'storage', TRUE, NOW(), NOW())
		 RETURNING id::text, name`,
		companyID,
		code,
		normalizedName,
	).Scan(&warehouseID, &warehouseName); err != nil {
		return "", "", err
	}

	return warehouseID, warehouseName, nil
}

func (s *PostgresStore) currentInventoryBalance(ctx context.Context, tx *sql.Tx, companyID string, warehouseID string, productID string) (int, error) {
	var quantity float64
	err := tx.QueryRowContext(
		ctx,
		`SELECT COALESCE(quantity_on_hand, 0)
		 FROM inventory_balances
		 WHERE company_id = $1::uuid AND warehouse_id = $2::uuid AND product_id = $3::uuid`,
		companyID,
		warehouseID,
		productID,
	).Scan(&quantity)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}
	return int(quantity), nil
}

func (s *PostgresStore) upsertInventoryBalance(ctx context.Context, tx *sql.Tx, companyID string, warehouseID string, productID string, quantity int, averageCost int) error {
	_, err := tx.ExecContext(
		ctx,
		`INSERT INTO inventory_balances (
		   company_id, warehouse_id, product_id, quantity_on_hand, quantity_reserved, average_cost, updated_at
		 ) VALUES (
		   $1::uuid, $2::uuid, $3::uuid, $4, 0, $5, NOW()
		 )
		 ON CONFLICT (company_id, warehouse_id, product_id)
		 DO UPDATE SET
		   quantity_on_hand = EXCLUDED.quantity_on_hand,
		   average_cost = EXCLUDED.average_cost,
		   updated_at = NOW()`,
		companyID,
		warehouseID,
		productID,
		quantity,
		averageCost,
	)
	return err
}

func (s *PostgresStore) applyInventoryMovement(
	ctx context.Context,
	tx *sql.Tx,
	companyID string,
	documentType string,
	sourceWarehouseID string,
	relatedWarehouseID string,
	product Product,
	documentID string,
	lineID string,
	quantity int,
	unitCost int,
	documentDate time.Time,
) error {
	switch documentType {
	case "purchase_receipt", "adjustment", "production_in":
		currentBalance, err := s.currentInventoryBalance(ctx, tx, companyID, sourceWarehouseID, product.ID)
		if err != nil {
			return err
		}
		newBalance := currentBalance + quantity
		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO inventory_movements (
			   company_id, warehouse_id, product_id, document_id, document_line_id, movement_type, quantity_delta, unit_cost, total_cost, balance_after, happened_at, created_at
			 ) VALUES (
			   $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::uuid, 'in', $6, $7, $8, $9, $10, NOW()
			 )`,
			companyID,
			sourceWarehouseID,
			product.ID,
			documentID,
			lineID,
			quantity,
			unitCost,
			quantity*unitCost,
			newBalance,
			documentDate,
		); err != nil {
			return err
		}
		return s.upsertInventoryBalance(ctx, tx, companyID, sourceWarehouseID, product.ID, newBalance, unitCost)
	case "write_off", "sale_issue", "production_out":
		currentBalance, err := s.currentInventoryBalance(ctx, tx, companyID, sourceWarehouseID, product.ID)
		if err != nil {
			return err
		}
		if currentBalance < quantity {
			return fmt.Errorf("%w: not enough stock for product %s", ErrValidation, product.Name)
		}
		newBalance := currentBalance - quantity
		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO inventory_movements (
			   company_id, warehouse_id, product_id, document_id, document_line_id, movement_type, quantity_delta, unit_cost, total_cost, balance_after, happened_at, created_at
			 ) VALUES (
			   $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::uuid, 'out', $6, $7, $8, $9, $10, NOW()
			 )`,
			companyID,
			sourceWarehouseID,
			product.ID,
			documentID,
			lineID,
			-quantity,
			unitCost,
			quantity*unitCost,
			newBalance,
			documentDate,
		); err != nil {
			return err
		}
		return s.upsertInventoryBalance(ctx, tx, companyID, sourceWarehouseID, product.ID, newBalance, unitCost)
	case "transfer":
		currentSourceBalance, err := s.currentInventoryBalance(ctx, tx, companyID, sourceWarehouseID, product.ID)
		if err != nil {
			return err
		}
		if currentSourceBalance < quantity {
			return fmt.Errorf("%w: not enough stock for product %s", ErrValidation, product.Name)
		}
		currentTargetBalance, err := s.currentInventoryBalance(ctx, tx, companyID, relatedWarehouseID, product.ID)
		if err != nil {
			return err
		}
		newSourceBalance := currentSourceBalance - quantity
		newTargetBalance := currentTargetBalance + quantity
		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO inventory_movements (
			   company_id, warehouse_id, product_id, document_id, document_line_id, movement_type, quantity_delta, unit_cost, total_cost, balance_after, happened_at, created_at
			 ) VALUES (
			   $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::uuid, 'transfer_out', $6, $7, $8, $9, $10, NOW()
			 )`,
			companyID,
			sourceWarehouseID,
			product.ID,
			documentID,
			lineID,
			-quantity,
			unitCost,
			quantity*unitCost,
			newSourceBalance,
			documentDate,
		); err != nil {
			return err
		}
		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO inventory_movements (
			   company_id, warehouse_id, product_id, document_id, document_line_id, movement_type, quantity_delta, unit_cost, total_cost, balance_after, happened_at, created_at
			 ) VALUES (
			   $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::uuid, 'transfer_in', $6, $7, $8, $9, $10, NOW()
			 )`,
			companyID,
			relatedWarehouseID,
			product.ID,
			documentID,
			lineID,
			quantity,
			unitCost,
			quantity*unitCost,
			newTargetBalance,
			documentDate,
		); err != nil {
			return err
		}
		if err = s.upsertInventoryBalance(ctx, tx, companyID, sourceWarehouseID, product.ID, newSourceBalance, unitCost); err != nil {
			return err
		}
		return s.upsertInventoryBalance(ctx, tx, companyID, relatedWarehouseID, product.ID, newTargetBalance, unitCost)
	default:
		return fmt.Errorf("%w: document type is invalid", ErrValidation)
	}
}

type cashAccountRecord struct {
	ID      string
	Name    string
	Balance int
}

func (s *PostgresStore) findCashAccount(ctx context.Context, tx *sql.Tx, companyID string, accountID string) (cashAccountRecord, error) {
	var account cashAccountRecord
	var balance float64
	err := tx.QueryRowContext(
		ctx,
		`SELECT
		    ca.id::text,
		    ca.name,
		    COALESCE(cab.balance_amount, ca.opening_balance)
		 FROM cash_accounts ca
		 LEFT JOIN cash_account_balances cab ON cab.account_id = ca.id
		 WHERE ca.company_id = $1::uuid AND ca.id = $2::uuid AND ca.archived_at IS NULL`,
		companyID,
		accountID,
	).Scan(&account.ID, &account.Name, &balance)
	if err != nil {
		return cashAccountRecord{}, err
	}

	account.Balance = int(balance)
	return account, nil
}

func (s *PostgresStore) ensureMoneyCategory(ctx context.Context, tx *sql.Tx, companyID string, direction string, name string) (string, error) {
	normalizedName := strings.TrimSpace(name)
	if normalizedName == "" {
		return "", nil
	}

	var categoryID string
	err := tx.QueryRowContext(
		ctx,
		`SELECT id::text
		 FROM money_categories
		 WHERE company_id = $1::uuid AND direction = $2 AND lower(name) = lower($3) AND archived_at IS NULL
		 LIMIT 1`,
		companyID,
		direction,
		normalizedName,
	).Scan(&categoryID)
	if err == nil {
		return categoryID, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}

	if err = tx.QueryRowContext(
		ctx,
		`INSERT INTO money_categories (company_id, direction, name, color_hex, created_at, updated_at)
		 VALUES ($1::uuid, $2, $3, $4, NOW(), NOW())
		 RETURNING id::text`,
		companyID,
		direction,
		normalizedName,
		moneyCategoryColor(direction),
	).Scan(&categoryID); err != nil {
		return "", err
	}

	return categoryID, nil
}

func (s *PostgresStore) insertMoneyMovement(
	ctx context.Context,
	tx *sql.Tx,
	companyID string,
	accountID string,
	documentID string,
	lineID string,
	clientID string,
	categoryID string,
	transferGroupID string,
	direction string,
	amount int,
	signedAmount int,
	balanceAfter int,
	operationDate time.Time,
) error {
	_, err := tx.ExecContext(
		ctx,
		`INSERT INTO money_movements (
		   company_id, account_id, document_id, document_line_id, client_id, category_id, transfer_group_id, movement_direction, amount, signed_amount, balance_after, happened_at, created_at
		 ) VALUES (
		   $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::uuid, $6::uuid, $7::uuid, $8, $9, $10, $11, $12, NOW()
		 )`,
		companyID,
		accountID,
		documentID,
		lineID,
		nullUUID(clientID),
		nullUUID(categoryID),
		nullUUID(transferGroupID),
		direction,
		amount,
		signedAmount,
		balanceAfter,
		operationDate,
	)
	return err
}

func (s *PostgresStore) upsertCashAccountBalance(ctx context.Context, tx *sql.Tx, accountID string, balance int) error {
	_, err := tx.ExecContext(
		ctx,
		`INSERT INTO cash_account_balances (account_id, balance_amount, updated_at)
		 VALUES ($1::uuid, $2, NOW())
		 ON CONFLICT (account_id)
		 DO UPDATE SET balance_amount = EXCLUDED.balance_amount, updated_at = NOW()`,
		accountID,
		balance,
	)
	return err
}

func nullUUID(value string) any {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return value
}

func formatMoneyValue(value int) string {
	return fmt.Sprintf("₸ %s", withThousands(value))
}

func formatSignedMoneyValue(value int) string {
	sign := ""
	if value > 0 {
		sign = "+"
	}
	return fmt.Sprintf("%s₸ %s", sign, withThousands(absInt(value)))
}

func withThousands(value int) string {
	digits := fmt.Sprintf("%d", value)
	var result []byte
	for index := 0; index < len(digits); index++ {
		result = append(result, digits[index])
		remaining := len(digits) - index - 1
		if remaining > 0 && remaining%3 == 0 {
			result = append(result, ',')
		}
	}
	return string(result)
}

func absInt(value int) int {
	if value < 0 {
		return -value
	}
	return value
}

func netFlowColor(value int) string {
	if value < 0 {
		return "#EF4444"
	}
	return "#00A86B"
}

func defaultMoneyDescription(direction string) string {
	switch direction {
	case "income", "transfer_in":
		return "Поступление"
	case "expense", "transfer_out":
		return "Списание"
	default:
		return "Операция"
	}
}

func defaultMoneyCategory(direction string) string {
	switch direction {
	case "income", "transfer_in":
		return "Поступления"
	case "expense", "transfer_out":
		return "Расходы"
	default:
		return "Операции"
	}
}

func moneyCategoryColor(direction string) string {
	switch direction {
	case "income":
		return "#22C55E"
	case "expense":
		return "#EF4444"
	default:
		return "#64748B"
	}
}

func moneyDocumentTypeFor(direction string) string {
	switch direction {
	case "income":
		return "receipt"
	case "expense":
		return "payment"
	case "transfer":
		return "transfer"
	default:
		return "adjustment"
	}
}

func (s *PostgresStore) nextMoneyDocumentNo(direction string) string {
	prefix := "MNY"
	switch direction {
	case "income":
		prefix = "RCP"
	case "expense":
		prefix = "PAY"
	case "transfer":
		prefix = "TRF"
	}
	return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
}

func (s *PostgresStore) nextInventoryDocumentNo(documentType string) string {
	prefix := "INV"
	switch documentType {
	case "purchase_receipt":
		prefix = "REC"
	case "write_off":
		prefix = "WOF"
	case "transfer":
		prefix = "TRN"
	case "sale_issue":
		prefix = "SAL"
	case "adjustment":
		prefix = "ADJ"
	case "production_in":
		prefix = "PIN"
	case "production_out":
		prefix = "POUT"
	}
	return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
}

func defaultMoneyDescriptionForCreate(direction string, primaryAccount string, secondaryAccount string) string {
	switch direction {
	case "income":
		return fmt.Sprintf("Поступление на счет %s", primaryAccount)
	case "expense":
		return fmt.Sprintf("Списание со счета %s", primaryAccount)
	case "transfer":
		return fmt.Sprintf("Перевод %s -> %s", primaryAccount, secondaryAccount)
	default:
		return "Денежная операция"
	}
}

func normalizeClientSegment(segment string) string {
	switch strings.ToLower(strings.TrimSpace(segment)) {
	case "vip":
		return "vip"
	case "lead":
		return "lead"
	case "blocked":
		return "blocked"
	default:
		return "regular"
	}
}

func clientKindFor(client Client) string {
	if client.IIN != "" && client.BIN == "" {
		return "person"
	}
	return "company"
}

func interactionTypeFor(subject string) string {
	lowered := strings.ToLower(subject)
	switch {
	case strings.Contains(lowered, "звон"):
		return "call"
	case strings.Contains(lowered, "встреч"):
		return "meeting"
	case strings.Contains(lowered, "email"):
		return "email"
	default:
		return "note"
	}
}

func subjectTitle(interactionType string, subject string) string {
	if subject != "" {
		return subject
	}
	switch interactionType {
	case "call":
		return "Звонок"
	case "meeting":
		return "Встреча"
	case "email":
		return "Email"
	default:
		return "Заметка"
	}
}

// ─── Services ────────────────────────────────────────────────────────────────

func (s *PostgresStore) ListServices(user auth.User) ([]Service, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id::text, name, description, price, allowed_to_sell
		 FROM services
		 WHERE company_id = $1 AND archived_at IS NULL
		 ORDER BY created_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	services := make([]Service, 0)
	indexByID := make(map[string]int)
	for rows.Next() {
		var svc Service
		if err := rows.Scan(&svc.ID, &svc.Name, &svc.Description, &svc.Price, &svc.AllowedToSell); err != nil {
			return nil, err
		}
		svc.Materials = []ServiceMaterial{}
		indexByID[svc.ID] = len(services)
		services = append(services, svc)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(services) == 0 {
		return []Service{}, nil
	}

	matRows, err := s.db.QueryContext(
		ctx,
		`SELECT
		    sm.id::text,
		    sm.service_id::text,
		    sm.material_type,
		    COALESCE(sm.product_id::text, ''),
		    COALESCE(p.name, ''),
		    COALESCE(sm.sub_service_id::text, ''),
		    COALESCE(ss.name, ''),
		    sm.external_service_name,
		    sm.quantity,
		    sm.cost
		 FROM service_materials sm
		 LEFT JOIN products p ON p.id = sm.product_id
		 LEFT JOIN services ss ON ss.id = sm.sub_service_id
		 WHERE sm.service_id IN (
		   SELECT id FROM services WHERE company_id = $1 AND archived_at IS NULL
		 )`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer matRows.Close()

	for matRows.Next() {
		var m ServiceMaterial
		var serviceID string
		if err := matRows.Scan(
			&m.ID, &serviceID, &m.MaterialType,
			&m.ProductID, &m.ProductName,
			&m.SubServiceID, &m.SubServiceName,
			&m.ExternalServiceName, &m.Quantity, &m.Cost,
		); err != nil {
			return nil, err
		}
		if idx, ok := indexByID[serviceID]; ok {
			services[idx].Materials = append(services[idx].Materials, m)
		}
	}

	return services, matRows.Err()
}

func (s *PostgresStore) CreateService(user auth.User, input CreateServiceInput) (Service, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Service{}, err
	}

	normalized := NormalizeServiceInput(input)
	if err := ValidateServiceInput(normalized); err != nil {
		return Service{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Service{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	serviceID := mustGenerateProductID()
	if _, err = tx.ExecContext(
		ctx,
		`INSERT INTO services (id, company_id, name, description, price, allowed_to_sell, created_at, updated_at)
		 VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, NOW(), NOW())`,
		serviceID, companyID, normalized.Name, normalized.Description, normalized.Price, normalized.AllowedToSell,
	); err != nil {
		return Service{}, err
	}

	svc := Service{
		ID:            serviceID,
		Name:          normalized.Name,
		Description:   normalized.Description,
		Price:         normalized.Price,
		AllowedToSell: normalized.AllowedToSell,
		Materials:     []ServiceMaterial{},
	}

	for _, m := range normalized.Materials {
		matID := mustGenerateProductID()
		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO service_materials
			   (id, service_id, material_type, product_id, sub_service_id, external_service_name, quantity, cost, created_at)
			 VALUES
			   ($1::uuid, $2::uuid, $3, NULLIF($4,'')::uuid, NULLIF($5,'')::uuid, $6, $7, $8, NOW())`,
			matID, serviceID, m.MaterialType, m.ProductID, m.SubServiceID, m.ExternalServiceName, m.Quantity, m.Cost,
		); err != nil {
			return Service{}, err
		}
		svc.Materials = append(svc.Materials, ServiceMaterial{
			ID:                  matID,
			MaterialType:        m.MaterialType,
			ProductID:           m.ProductID,
			SubServiceID:        m.SubServiceID,
			ExternalServiceName: m.ExternalServiceName,
			Quantity:            m.Quantity,
			Cost:                m.Cost,
		})
	}

	if err = tx.Commit(); err != nil {
		return Service{}, err
	}
	return svc, nil
}

func (s *PostgresStore) UpdateService(user auth.User, serviceID string, input CreateServiceInput) (Service, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Service{}, err
	}

	normalized := NormalizeServiceInput(input)
	if err := ValidateServiceInput(normalized); err != nil {
		return Service{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Service{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	result, err := tx.ExecContext(
		ctx,
		`UPDATE services SET name=$3, description=$4, price=$5, allowed_to_sell=$6, updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid AND archived_at IS NULL`,
		serviceID, companyID, normalized.Name, normalized.Description, normalized.Price, normalized.AllowedToSell,
	)
	if err != nil {
		return Service{}, err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return Service{}, fmt.Errorf("%w: service not found", ErrValidation)
	}

	if _, err = tx.ExecContext(ctx, `DELETE FROM service_materials WHERE service_id = $1::uuid`, serviceID); err != nil {
		return Service{}, err
	}

	svc := Service{
		ID:            serviceID,
		Name:          normalized.Name,
		Description:   normalized.Description,
		Price:         normalized.Price,
		AllowedToSell: normalized.AllowedToSell,
		Materials:     []ServiceMaterial{},
	}

	for _, m := range normalized.Materials {
		matID := mustGenerateProductID()
		if _, err = tx.ExecContext(
			ctx,
			`INSERT INTO service_materials
			   (id, service_id, material_type, product_id, sub_service_id, external_service_name, quantity, cost, created_at)
			 VALUES
			   ($1::uuid, $2::uuid, $3, NULLIF($4,'')::uuid, NULLIF($5,'')::uuid, $6, $7, $8, NOW())`,
			matID, serviceID, m.MaterialType, m.ProductID, m.SubServiceID, m.ExternalServiceName, m.Quantity, m.Cost,
		); err != nil {
			return Service{}, err
		}
		svc.Materials = append(svc.Materials, ServiceMaterial{
			ID:                  matID,
			MaterialType:        m.MaterialType,
			ProductID:           m.ProductID,
			SubServiceID:        m.SubServiceID,
			ExternalServiceName: m.ExternalServiceName,
			Quantity:            m.Quantity,
			Cost:                m.Cost,
		})
	}

	if err = tx.Commit(); err != nil {
		return Service{}, err
	}
	return svc, nil
}

func (s *PostgresStore) DeleteService(user auth.User, serviceID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	result, err := s.db.ExecContext(
		ctx,
		`UPDATE services SET archived_at=NOW(), is_active=FALSE, updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid AND archived_at IS NULL`,
		serviceID, companyID,
	)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("%w: service not found", ErrValidation)
	}
	return nil
}

// ── Recipes ───────────────────────────────────────────────────────────────────

func (s *PostgresStore) ListRecipes(user auth.User) ([]Recipe, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(
		ctx,
		`SELECT id::text, name, description, payroll_amount
		 FROM recipes
		 WHERE company_id = $1 AND archived_at IS NULL
		 ORDER BY created_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	recipes := make([]Recipe, 0)
	indexByID := make(map[string]int)
	for rows.Next() {
		var r Recipe
		var payrollAmount float64
		if err := rows.Scan(&r.ID, &r.Name, &r.Description, &payrollAmount); err != nil {
			return nil, err
		}
		r.PayrollAmount = int(payrollAmount)
		r.Ingredients = []RecipeIngredient{}
		r.Services = []RecipeService{}
		r.Outputs = []RecipeOutput{}
		indexByID[r.ID] = len(recipes)
		recipes = append(recipes, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(recipes) == 0 {
		return []Recipe{}, nil
	}

	ingRows, err := s.db.QueryContext(
		ctx,
		`SELECT ri.id::text, ri.recipe_id::text, ri.product_id::text,
		        COALESCE(p.name,''), COALESCE(ri.unit_name,'шт'), ri.quantity
		 FROM recipe_ingredients ri
		 LEFT JOIN products p ON p.id = ri.product_id
		 WHERE ri.recipe_id IN (SELECT id FROM recipes WHERE company_id=$1 AND archived_at IS NULL)`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer ingRows.Close()
	for ingRows.Next() {
		var ing RecipeIngredient
		var recipeID string
		if err := ingRows.Scan(&ing.ID, &recipeID, &ing.ProductID, &ing.ProductName, &ing.UnitName, &ing.Quantity); err != nil {
			return nil, err
		}
		if idx, ok := indexByID[recipeID]; ok {
			recipes[idx].Ingredients = append(recipes[idx].Ingredients, ing)
		}
	}
	if err := ingRows.Err(); err != nil {
		return nil, err
	}

	svcRows, err := s.db.QueryContext(
		ctx,
		`SELECT rs.id::text, rs.recipe_id::text, rs.service_id::text,
		        COALESCE(sv.name,''), rs.quantity
		 FROM recipe_services rs
		 LEFT JOIN services sv ON sv.id = rs.service_id
		 WHERE rs.recipe_id IN (SELECT id FROM recipes WHERE company_id=$1 AND archived_at IS NULL)`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer svcRows.Close()
	for svcRows.Next() {
		var rs RecipeService
		var recipeID string
		if err := svcRows.Scan(&rs.ID, &recipeID, &rs.ServiceID, &rs.ServiceName, &rs.Quantity); err != nil {
			return nil, err
		}
		if idx, ok := indexByID[recipeID]; ok {
			recipes[idx].Services = append(recipes[idx].Services, rs)
		}
	}
	if err := svcRows.Err(); err != nil {
		return nil, err
	}

	outRows, err := s.db.QueryContext(
		ctx,
		`SELECT ro.id::text, ro.recipe_id::text, ro.product_id::text,
		        COALESCE(p.name,''), COALESCE(ro.unit_name,'шт'), ro.quantity
		 FROM recipe_outputs ro
		 LEFT JOIN products p ON p.id = ro.product_id
		 WHERE ro.recipe_id IN (SELECT id FROM recipes WHERE company_id=$1 AND archived_at IS NULL)`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer outRows.Close()
	for outRows.Next() {
		var out RecipeOutput
		var recipeID string
		if err := outRows.Scan(&out.ID, &recipeID, &out.ProductID, &out.ProductName, &out.UnitName, &out.Quantity); err != nil {
			return nil, err
		}
		if idx, ok := indexByID[recipeID]; ok {
			recipes[idx].Outputs = append(recipes[idx].Outputs, out)
		}
	}
	return recipes, outRows.Err()
}

func (s *PostgresStore) CreateRecipe(user auth.User, input CreateRecipeInput) (Recipe, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Recipe{}, err
	}

	normalized := NormalizeRecipeInput(input)
	if err := ValidateRecipeInput(normalized); err != nil {
		return Recipe{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Recipe{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	recipeID := mustGenerateProductID()
	if _, err = tx.ExecContext(
		ctx,
		`INSERT INTO recipes (id, company_id, name, description, payroll_amount, created_at, updated_at)
		 VALUES ($1::uuid, $2::uuid, $3, $4, $5, NOW(), NOW())`,
		recipeID, companyID, normalized.Name, normalized.Description, normalized.PayrollAmount,
	); err != nil {
		return Recipe{}, err
	}

	recipe := Recipe{
		ID: recipeID, Name: normalized.Name, Description: normalized.Description,
		PayrollAmount: normalized.PayrollAmount,
		Ingredients:   []RecipeIngredient{}, Services: []RecipeService{}, Outputs: []RecipeOutput{},
	}

	for _, ing := range normalized.Ingredients {
		id := mustGenerateProductID()
		if _, err = tx.ExecContext(ctx,
			`INSERT INTO recipe_ingredients (id, recipe_id, product_id, quantity, unit_name, created_at)
			 VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, NOW())`,
			id, recipeID, ing.ProductID, ing.Quantity, ing.UnitName,
		); err != nil {
			return Recipe{}, err
		}
		recipe.Ingredients = append(recipe.Ingredients, RecipeIngredient{ID: id, ProductID: ing.ProductID, UnitName: ing.UnitName, Quantity: ing.Quantity})
	}

	for _, svc := range normalized.Services {
		id := mustGenerateProductID()
		if _, err = tx.ExecContext(ctx,
			`INSERT INTO recipe_services (id, recipe_id, service_id, quantity, created_at)
			 VALUES ($1::uuid, $2::uuid, $3::uuid, $4, NOW())`,
			id, recipeID, svc.ServiceID, svc.Quantity,
		); err != nil {
			return Recipe{}, err
		}
		recipe.Services = append(recipe.Services, RecipeService{ID: id, ServiceID: svc.ServiceID, Quantity: svc.Quantity})
	}

	for _, out := range normalized.Outputs {
		id := mustGenerateProductID()
		if _, err = tx.ExecContext(ctx,
			`INSERT INTO recipe_outputs (id, recipe_id, product_id, quantity, unit_name, created_at)
			 VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, NOW())`,
			id, recipeID, out.ProductID, out.Quantity, out.UnitName,
		); err != nil {
			return Recipe{}, err
		}
		recipe.Outputs = append(recipe.Outputs, RecipeOutput{ID: id, ProductID: out.ProductID, UnitName: out.UnitName, Quantity: out.Quantity})
	}

	if err = tx.Commit(); err != nil {
		return Recipe{}, err
	}
	return recipe, nil
}

func (s *PostgresStore) UpdateRecipe(user auth.User, recipeID string, input CreateRecipeInput) (Recipe, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return Recipe{}, err
	}

	normalized := NormalizeRecipeInput(input)
	if err := ValidateRecipeInput(normalized); err != nil {
		return Recipe{}, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Recipe{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	result, err := tx.ExecContext(ctx,
		`UPDATE recipes SET name=$3, description=$4, payroll_amount=$5, updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid AND archived_at IS NULL`,
		recipeID, companyID, normalized.Name, normalized.Description, normalized.PayrollAmount,
	)
	if err != nil {
		return Recipe{}, err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return Recipe{}, fmt.Errorf("%w: recipe not found", ErrValidation)
	}

	for _, tbl := range []string{"recipe_ingredients", "recipe_services", "recipe_outputs"} {
		if _, err = tx.ExecContext(ctx, fmt.Sprintf("DELETE FROM %s WHERE recipe_id = $1::uuid", tbl), recipeID); err != nil {
			return Recipe{}, err
		}
	}

	recipe := Recipe{
		ID: recipeID, Name: normalized.Name, Description: normalized.Description,
		PayrollAmount: normalized.PayrollAmount,
		Ingredients:   []RecipeIngredient{}, Services: []RecipeService{}, Outputs: []RecipeOutput{},
	}

	for _, ing := range normalized.Ingredients {
		id := mustGenerateProductID()
		if _, err = tx.ExecContext(ctx,
			`INSERT INTO recipe_ingredients (id, recipe_id, product_id, quantity, unit_name, created_at)
			 VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, NOW())`,
			id, recipeID, ing.ProductID, ing.Quantity, ing.UnitName,
		); err != nil {
			return Recipe{}, err
		}
		recipe.Ingredients = append(recipe.Ingredients, RecipeIngredient{ID: id, ProductID: ing.ProductID, UnitName: ing.UnitName, Quantity: ing.Quantity})
	}

	for _, svc := range normalized.Services {
		id := mustGenerateProductID()
		if _, err = tx.ExecContext(ctx,
			`INSERT INTO recipe_services (id, recipe_id, service_id, quantity, created_at)
			 VALUES ($1::uuid, $2::uuid, $3::uuid, $4, NOW())`,
			id, recipeID, svc.ServiceID, svc.Quantity,
		); err != nil {
			return Recipe{}, err
		}
		recipe.Services = append(recipe.Services, RecipeService{ID: id, ServiceID: svc.ServiceID, Quantity: svc.Quantity})
	}

	for _, out := range normalized.Outputs {
		id := mustGenerateProductID()
		if _, err = tx.ExecContext(ctx,
			`INSERT INTO recipe_outputs (id, recipe_id, product_id, quantity, unit_name, created_at)
			 VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, NOW())`,
			id, recipeID, out.ProductID, out.Quantity, out.UnitName,
		); err != nil {
			return Recipe{}, err
		}
		recipe.Outputs = append(recipe.Outputs, RecipeOutput{ID: id, ProductID: out.ProductID, UnitName: out.UnitName, Quantity: out.Quantity})
	}

	if err = tx.Commit(); err != nil {
		return Recipe{}, err
	}
	return recipe, nil
}

// SetRecipePayrollAmount updates only the recipe's payroll amount, used by the
// salary settings screen without touching the recipe composition.
func (s *PostgresStore) SetRecipePayrollAmount(user auth.User, recipeID string, amount int) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}
	if amount < 0 {
		return fmt.Errorf("%w: amount must be zero or greater", ErrValidation)
	}

	result, err := s.db.ExecContext(ctx,
		`UPDATE recipes SET payroll_amount=$3, updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid AND archived_at IS NULL`,
		recipeID, companyID, amount,
	)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("%w: recipe not found", ErrValidation)
	}
	return nil
}

func (s *PostgresStore) DeleteRecipe(user auth.User, recipeID string) error {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return err
	}

	result, err := s.db.ExecContext(ctx,
		`UPDATE recipes SET archived_at=NOW(), is_active=FALSE, updated_at=NOW()
		 WHERE id=$1::uuid AND company_id=$2::uuid AND archived_at IS NULL`,
		recipeID, companyID,
	)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return fmt.Errorf("%w: recipe not found", ErrValidation)
	}
	return nil
}

// ── Production Orders ─────────────────────────────────────────────────────────

type productionInventoryLine struct {
	Product   Product
	Quantity  int
	UnitPrice int
	UnitCost  int
}

type productionOrderPosting struct {
	DocumentNo              string
	RecipeID                string
	SourceWarehouseID       string
	OutputWarehouseID       string
	PlannedQuantity         float64
	Status                  string
	ProductionOutDocumentID string
	ProductionInDocumentID  string
}

func (s *PostgresStore) ListProductionOrders(user auth.User) ([]ProductionOrder, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(ctx,
		`SELECT
		    po.id::text,
		    po.document_no,
		    COALESCE(po.recipe_id::text, ''),
		    COALESCE(r.name, ''),
		    COALESCE(po.source_warehouse_id::text, ''),
		    COALESCE(sw.name, ''),
		    COALESCE(po.output_warehouse_id::text, ''),
		    COALESCE(ow.name, ''),
		    po.batch_number,
		    po.responsible_employee,
		    po.planned_quantity,
		    po.status,
		    COALESCE(po.planned_date::text, ''),
		    po.notes,
		    po.created_at::text
		 FROM production_orders po
		 LEFT JOIN recipes r ON r.id = po.recipe_id
		 LEFT JOIN warehouses sw ON sw.id = po.source_warehouse_id
		 LEFT JOIN warehouses ow ON ow.id = po.output_warehouse_id
		 WHERE po.company_id = $1
		 ORDER BY po.created_at DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	orders := make([]ProductionOrder, 0)
	indexByID := make(map[string]int)
	for rows.Next() {
		var o ProductionOrder
		if err := rows.Scan(
			&o.ID, &o.DocumentNo, &o.RecipeID, &o.RecipeName,
			&o.SourceWarehouseID, &o.SourceWarehouseName,
			&o.OutputWarehouseID, &o.OutputWarehouseName,
			&o.BatchNumber, &o.ResponsibleEmployee,
			&o.PlannedQuantity, &o.Status, &o.PlannedDate, &o.Notes, &o.CreatedAt,
		); err != nil {
			return nil, err
		}
		o.Participants = []ProductionParticipant{}
		indexByID[o.ID] = len(orders)
		orders = append(orders, o)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(orders) == 0 {
		return orders, nil
	}

	partRows, err := s.db.QueryContext(ctx,
		`SELECT pp.order_id::text, pp.employee_id::text, COALESCE(e.full_name,''), pp.share_percent
		 FROM production_order_participants pp
		 JOIN production_orders po ON po.id = pp.order_id
		 LEFT JOIN employees e ON e.id = pp.employee_id
		 WHERE po.company_id = $1
		 ORDER BY pp.share_percent DESC`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer partRows.Close()
	for partRows.Next() {
		var orderID string
		var p ProductionParticipant
		if err := partRows.Scan(&orderID, &p.EmployeeID, &p.EmployeeName, &p.SharePercent); err != nil {
			return nil, err
		}
		if idx, ok := indexByID[orderID]; ok {
			orders[idx].Participants = append(orders[idx].Participants, p)
		}
	}
	return orders, partRows.Err()
}

func (s *PostgresStore) CreateProductionOrder(user auth.User, input CreateProductionOrderInput) (ProductionOrder, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return ProductionOrder{}, err
	}

	normalized := NormalizeProductionOrderInput(input)
	if err := ValidateProductionOrderInput(normalized); err != nil {
		return ProductionOrder{}, err
	}

	if normalized.DocumentNo == "" {
		normalized.DocumentNo = fmt.Sprintf("PRD-%d", time.Now().UnixMilli())
	}

	orderID := mustGenerateProductID()
	var plannedDate *string
	if normalized.PlannedDate != "" {
		plannedDate = &normalized.PlannedDate
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return ProductionOrder{}, err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	if _, err = tx.ExecContext(ctx,
		`INSERT INTO production_orders
		   (id, company_id, document_no, recipe_id, source_warehouse_id, output_warehouse_id,
		    batch_number, responsible_employee, planned_quantity, status, planned_date, notes,
		    created_by_user_id, created_at, updated_at)
		 VALUES
		   ($1::uuid, $2::uuid, $3,
		    NULLIF($4,'')::uuid, NULLIF($5,'')::uuid, NULLIF($6,'')::uuid,
		    $7, $8, $9, 'draft', $10::date, $11, NULLIF($12,''), NOW(), NOW())`,
		orderID, companyID, normalized.DocumentNo,
		normalized.RecipeID, normalized.SourceWarehouseID, normalized.OutputWarehouseID,
		normalized.BatchNumber, normalized.ResponsibleEmployee, normalized.PlannedQuantity,
		plannedDate, normalized.Notes, user.ID,
	); err != nil {
		return ProductionOrder{}, err
	}

	for _, p := range normalized.Participants {
		if _, err = tx.ExecContext(ctx,
			`INSERT INTO production_order_participants (id, order_id, employee_id, share_percent, created_at)
			 VALUES (gen_random_uuid(), $1::uuid, $2::uuid, $3, NOW())`,
			orderID, p.EmployeeID, p.SharePercent,
		); err != nil {
			return ProductionOrder{}, err
		}
	}

	if err = tx.Commit(); err != nil {
		return ProductionOrder{}, err
	}

	orders, err := s.ListProductionOrders(user)
	if err != nil {
		return ProductionOrder{}, err
	}
	for _, o := range orders {
		if o.ID == orderID {
			return o, nil
		}
	}
	return ProductionOrder{ID: orderID, DocumentNo: normalized.DocumentNo, Status: "draft"}, nil
}

func (s *PostgresStore) UpdateProductionOrderStatus(user auth.User, orderID string, input UpdateProductionOrderStatusInput) (ProductionOrder, error) {
	ctx, cancel := s.withTimeout()
	defer cancel()

	companyID, err := s.ensurePrimaryCompany(ctx, user)
	if err != nil {
		return ProductionOrder{}, err
	}

	switch input.Status {
	case "draft", "in_progress", "completed", "cancelled":
	default:
		return ProductionOrder{}, fmt.Errorf("%w: invalid status", ErrValidation)
	}

	if input.Status == "completed" {
		tx, txErr := s.db.BeginTx(ctx, nil)
		if txErr != nil {
			return ProductionOrder{}, txErr
		}
		err = txErr
		defer func() {
			if err != nil {
				_ = tx.Rollback()
			}
		}()

		if err = s.completeProductionOrder(ctx, tx, companyID, user.ID, orderID); err != nil {
			return ProductionOrder{}, err
		}
		if err = tx.Commit(); err != nil {
			return ProductionOrder{}, err
		}
	} else {
		result, updateErr := s.db.ExecContext(ctx,
			`UPDATE production_orders SET status=$3, updated_at=NOW()
			 WHERE id=$1::uuid AND company_id=$2::uuid
			   AND status NOT IN ('completed', 'cancelled')`,
			orderID, companyID, input.Status,
		)
		if updateErr != nil {
			return ProductionOrder{}, updateErr
		}
		if affected, _ := result.RowsAffected(); affected == 0 {
			return ProductionOrder{}, fmt.Errorf("%w: production order not found or already closed", ErrValidation)
		}
	}

	orders, err := s.ListProductionOrders(user)
	if err != nil {
		return ProductionOrder{}, err
	}
	for _, o := range orders {
		if o.ID == orderID {
			return o, nil
		}
	}
	return ProductionOrder{ID: orderID, Status: input.Status}, nil
}

func (s *PostgresStore) completeProductionOrder(ctx context.Context, tx *sql.Tx, companyID string, userID string, orderID string) error {
	var order productionOrderPosting
	err := tx.QueryRowContext(
		ctx,
		`SELECT
		    document_no,
		    COALESCE(recipe_id::text, ''),
		    COALESCE(source_warehouse_id::text, ''),
		    COALESCE(output_warehouse_id::text, ''),
		    planned_quantity,
		    status,
		    COALESCE(production_out_document_id::text, ''),
		    COALESCE(production_in_document_id::text, '')
		 FROM production_orders
		 WHERE id = $1::uuid AND company_id = $2::uuid
		 FOR UPDATE`,
		orderID,
		companyID,
	).Scan(
		&order.DocumentNo,
		&order.RecipeID,
		&order.SourceWarehouseID,
		&order.OutputWarehouseID,
		&order.PlannedQuantity,
		&order.Status,
		&order.ProductionOutDocumentID,
		&order.ProductionInDocumentID,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("%w: production order not found", ErrValidation)
		}
		return err
	}

	if order.Status == "completed" || order.ProductionOutDocumentID != "" || order.ProductionInDocumentID != "" {
		return fmt.Errorf("%w: production order is already completed", ErrValidation)
	}
	if order.Status == "cancelled" {
		return fmt.Errorf("%w: cancelled production order cannot be completed", ErrValidation)
	}
	if order.RecipeID == "" || order.SourceWarehouseID == "" || order.OutputWarehouseID == "" {
		return fmt.Errorf("%w: production order is missing recipe or warehouses", ErrValidation)
	}

	inputLines, err := s.loadProductionIngredientLines(ctx, tx, companyID, order.RecipeID, order.PlannedQuantity)
	if err != nil {
		return err
	}
	outputLines, err := s.loadProductionOutputLines(ctx, tx, companyID, order.RecipeID, order.PlannedQuantity)
	if err != nil {
		return err
	}
	if len(outputLines) == 0 {
		return fmt.Errorf("%w: production recipe has no output products", ErrValidation)
	}

	documentDate := time.Now()
	outDocumentID, err := s.createProductionInventoryDocument(
		ctx,
		tx,
		companyID,
		userID,
		"production_out",
		order.DocumentNo,
		order.SourceWarehouseID,
		order.OutputWarehouseID,
		fmt.Sprintf("Списание сырья по производству %s", order.DocumentNo),
		documentDate,
		inputLines,
	)
	if err != nil {
		return err
	}

	inDocumentID, err := s.createProductionInventoryDocument(
		ctx,
		tx,
		companyID,
		userID,
		"production_in",
		order.DocumentNo,
		order.OutputWarehouseID,
		order.SourceWarehouseID,
		fmt.Sprintf("Выпуск продукции по производству %s", order.DocumentNo),
		documentDate,
		outputLines,
	)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(
		ctx,
		`UPDATE production_orders
		 SET status = 'completed',
		     completed_at = NOW(),
		     production_out_document_id = NULLIF($3, '')::uuid,
		     production_in_document_id = NULLIF($4, '')::uuid,
		     updated_at = NOW()
		 WHERE id = $1::uuid AND company_id = $2::uuid`,
		orderID,
		companyID,
		outDocumentID,
		inDocumentID,
	)
	return err
}

func (s *PostgresStore) loadProductionIngredientLines(ctx context.Context, tx *sql.Tx, companyID string, recipeID string, plannedQuantity float64) ([]productionInventoryLine, error) {
	rows, err := tx.QueryContext(
		ctx,
		`SELECT p.id::text, p.name, p.sku, p.sale_price, p.cost_price, ri.quantity
		 FROM recipe_ingredients ri
		 JOIN products p ON p.id = ri.product_id
		 WHERE ri.recipe_id = $1::uuid
		   AND p.company_id = $2::uuid
		   AND p.archived_at IS NULL
		 ORDER BY ri.created_at ASC`,
		recipeID,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	lines := make([]productionInventoryLine, 0)
	for rows.Next() {
		line, scanErr := scanProductionInventoryLine(rows, plannedQuantity)
		if scanErr != nil {
			return nil, scanErr
		}
		lines = append(lines, line)
	}
	return lines, rows.Err()
}

func (s *PostgresStore) loadProductionOutputLines(ctx context.Context, tx *sql.Tx, companyID string, recipeID string, plannedQuantity float64) ([]productionInventoryLine, error) {
	rows, err := tx.QueryContext(
		ctx,
		`SELECT p.id::text, p.name, p.sku, p.sale_price, p.cost_price, ro.quantity
		 FROM recipe_outputs ro
		 JOIN products p ON p.id = ro.product_id
		 WHERE ro.recipe_id = $1::uuid
		   AND p.company_id = $2::uuid
		   AND p.archived_at IS NULL
		 ORDER BY ro.created_at ASC`,
		recipeID,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	lines := make([]productionInventoryLine, 0)
	for rows.Next() {
		line, scanErr := scanProductionInventoryLine(rows, plannedQuantity)
		if scanErr != nil {
			return nil, scanErr
		}
		lines = append(lines, line)
	}
	return lines, rows.Err()
}

type productionLineScanner interface {
	Scan(dest ...any) error
}

func scanProductionInventoryLine(scanner productionLineScanner, plannedQuantity float64) (productionInventoryLine, error) {
	var (
		line           productionInventoryLine
		price          float64
		cost           float64
		recipeQuantity float64
	)
	if err := scanner.Scan(
		&line.Product.ID,
		&line.Product.Name,
		&line.Product.SKU,
		&price,
		&cost,
		&recipeQuantity,
	); err != nil {
		return productionInventoryLine{}, err
	}

	quantity, err := productionWholeQuantity(recipeQuantity * plannedQuantity)
	if err != nil {
		return productionInventoryLine{}, fmt.Errorf("%w: %s", err, line.Product.Name)
	}

	line.Quantity = quantity
	line.Product.Price = int(price)
	line.Product.Cost = int(cost)
	line.UnitPrice = int(cost)
	line.UnitCost = int(cost)
	return line, nil
}

func productionWholeQuantity(value float64) (int, error) {
	rounded := math.Round(value)
	if rounded <= 0 {
		return 0, fmt.Errorf("%w: production quantity must be greater than zero", ErrValidation)
	}
	if math.Abs(value-rounded) > 0.000001 {
		return 0, fmt.Errorf("%w: production quantities must be whole numbers", ErrValidation)
	}
	return int(rounded), nil
}

func (s *PostgresStore) createProductionInventoryDocument(
	ctx context.Context,
	tx *sql.Tx,
	companyID string,
	userID string,
	documentType string,
	orderDocumentNo string,
	warehouseID string,
	relatedWarehouseID string,
	note string,
	documentDate time.Time,
	lines []productionInventoryLine,
) (string, error) {
	if len(lines) == 0 {
		return "", nil
	}

	documentNo := productionInventoryDocumentNo(documentType, orderDocumentNo)
	var documentID string
	if err := tx.QueryRowContext(
		ctx,
		`INSERT INTO inventory_documents (
		   company_id, document_no, document_type, status, document_date, warehouse_id,
		   related_warehouse_id, note, created_by_user_id, posted_by_user_id,
		   posted_at, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2, $3, 'posted', $4, $5::uuid, NULLIF($6, '')::uuid,
		   NULLIF($7, ''), $8, $8, NOW(), NOW(), NOW()
		 )
		 RETURNING id::text`,
		companyID,
		documentNo,
		documentType,
		documentDate.Format("2006-01-02"),
		warehouseID,
		relatedWarehouseID,
		note,
		userID,
	).Scan(&documentID); err != nil {
		return "", err
	}

	for index, line := range lines {
		var lineID string
		if err := tx.QueryRowContext(
			ctx,
			`INSERT INTO inventory_document_lines (
			   document_id, line_no, product_id, quantity, unit_price, unit_cost, note, created_at
			 ) VALUES (
			   $1::uuid, $2, $3::uuid, $4, $5, $6, NULLIF($7, ''), NOW()
			 )
			 RETURNING id::text`,
			documentID,
			index+1,
			line.Product.ID,
			line.Quantity,
			line.UnitPrice,
			line.UnitCost,
			note,
		).Scan(&lineID); err != nil {
			return "", err
		}

		if err := s.applyInventoryMovement(
			ctx,
			tx,
			companyID,
			documentType,
			warehouseID,
			relatedWarehouseID,
			line.Product,
			documentID,
			lineID,
			line.Quantity,
			line.UnitCost,
			documentDate,
		); err != nil {
			return "", err
		}
	}

	return documentID, nil
}

func productionInventoryDocumentNo(documentType string, orderDocumentNo string) string {
	switch documentType {
	case "production_out":
		return fmt.Sprintf("POUT-%s", orderDocumentNo)
	case "production_in":
		return fmt.Sprintf("PIN-%s", orderDocumentNo)
	default:
		return fmt.Sprintf("PRD-%s", orderDocumentNo)
	}
}
