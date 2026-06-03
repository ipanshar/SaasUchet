package business

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
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
			&creditLimit,
			&client.BIN,
			&client.IIN,
		); err != nil {
			return nil, err
		}

		client.Debt = int(creditLimit)
		client.TotalSales = 0
		client.Interactions = []Interaction{}
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

	return clients, interactionRows.Err()
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
			   id, company_id, client_kind, name, contact_name, phone, email, bin, iin, country_code, segment, status, credit_limit, created_at, updated_at
			 ) VALUES (
			   $1::uuid, $2::uuid, $3, $4, NULLIF($5, ''), NULLIF($6, ''), NULLIF($7, ''), NULLIF($8, ''), NULLIF($9, ''), 'KZ', $10, 'active', $11, NOW(), NOW()
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
		    COALESCE(SUM(ib.quantity_on_hand), 0),
		    p.min_quantity,
		    p.sale_price,
		    p.cost_price,
		    COALESCE(p.barcode, '')
		 FROM products p
		 LEFT JOIN product_categories pc ON pc.id = p.category_id
		 LEFT JOIN inventory_balances ib ON ib.product_id = p.id AND ib.company_id = p.company_id
		 WHERE p.company_id = $1 AND p.archived_at IS NULL
		 GROUP BY p.id, p.name, p.sku, pc.name, p.min_quantity, p.sale_price, p.cost_price, p.barcode, p.created_at
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
		if err := rows.Scan(
			&product.ID,
			&product.Name,
			&product.SKU,
			&product.Category,
			&quantity,
			&product.MinQuantity,
			&product.Price,
			&product.Cost,
			&product.Barcode,
		); err != nil {
			return nil, err
		}

		product.Quantity = int(quantity)
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
		   id, company_id, category_id, sku, barcode, name, unit_name, tracking_type, min_quantity, sale_price, cost_price, is_active, created_at, updated_at
		 ) VALUES (
		   $1::uuid, $2::uuid, $3::uuid, $4, NULLIF($5, ''), $6, 'pcs', 'none', $7, $8, $9, TRUE, NOW(), NOW()
		 )`,
		product.ID,
		companyID,
		nullUUID(categoryID),
		product.SKU,
		product.Barcode,
		product.Name,
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
		 SET category_id = $3::uuid,
		     sku = $4,
		     barcode = NULLIF($5, ''),
		     name = $6,
		     min_quantity = $7,
		     sale_price = $8,
		     cost_price = $9,
		     updated_at = NOW()
		 WHERE id = $1::uuid AND company_id = $2::uuid`,
		productID,
		companyID,
		nullUUID(categoryID),
		updated.SKU,
		updated.Barcode,
		updated.Name,
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
		    COALESCE(w.name, ''),
		    COALESCE(rw.name, ''),
		    COUNT(DISTINCT l.id),
		    COALESCE(SUM(l.quantity), 0),
		    COALESCE(d.note, '')
		 FROM inventory_documents d
		 LEFT JOIN warehouses w ON w.id = d.warehouse_id
		 LEFT JOIN warehouses rw ON rw.id = d.related_warehouse_id
		 LEFT JOIN inventory_document_lines l ON l.document_id = d.id
		 WHERE d.company_id = $1::uuid
		   AND ($2 = '' OR d.document_type = $2)
		   AND (
		     $3 = ''
		     OR d.document_no ILIKE '%' || $3 || '%'
		     OR COALESCE(d.note, '') ILIKE '%' || $3 || '%'
		     OR COALESCE(w.name, '') ILIKE '%' || $3 || '%'
		   )
		 GROUP BY d.id, d.document_no, d.document_type, d.status, d.document_date, w.name, rw.name, d.note
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
		if err := rows.Scan(
			&document.ID,
			&document.DocumentNo,
			&document.DocumentType,
			&document.Status,
			&documentDate,
			&document.WarehouseName,
			&document.RelatedWarehouse,
			&document.ProductLines,
			&totalQuantity,
			&document.Note,
		); err != nil {
			return nil, err
		}
		document.DocumentDate = documentDate.Format("2006-01-02")
		document.TotalQuantity = int(totalQuantity)
		documents = append(documents, document)
	}

	return documents, rows.Err()
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
		    COALESCE(SUM(l.amount), 0)
		 FROM money_documents d
		 LEFT JOIN cash_accounts pa ON pa.id = d.primary_account_id
		 LEFT JOIN cash_accounts sa ON sa.id = d.secondary_account_id
		 LEFT JOIN money_document_lines l ON l.document_id = d.id
		 WHERE d.company_id = $1::uuid
		   AND ($2 = '' OR d.document_type = $2)
		   AND (
		     $3 = ''
		     OR d.document_no ILIKE '%' || $3 || '%'
		     OR COALESCE(d.description, '') ILIKE '%' || $3 || '%'
		     OR COALESCE(pa.name, '') ILIKE '%' || $3 || '%'
		     OR COALESCE(sa.name, '') ILIKE '%' || $3 || '%'
		   )
		 GROUP BY d.id, d.document_no, d.document_type, d.status, d.operation_date, d.description, pa.name, sa.name
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
		); err != nil {
			return nil, err
		}
		document.OperationDate = operationDate.Format("2006-01-02")
		document.Amount = int(amount)
		documents = append(documents, document)
	}

	return documents, rows.Err()
}

func (s *PostgresStore) ensurePrimaryCompany(ctx context.Context, user auth.User) (string, error) {
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

func (s *PostgresStore) withTimeout() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), s.queryTimeout)
}

func (s *PostgresStore) findProductByID(ctx context.Context, companyID string, productID string) (Product, error) {
	var product Product
	var quantity float64
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
		    COALESCE(p.barcode, '')
		 FROM products p
		 LEFT JOIN product_categories pc ON pc.id = p.category_id
		 LEFT JOIN inventory_balances ib ON ib.product_id = p.id AND ib.company_id = p.company_id
		 WHERE p.id = $1::uuid AND p.company_id = $2::uuid AND p.archived_at IS NULL
		 GROUP BY p.id, p.name, p.sku, pc.name, p.min_quantity, p.sale_price, p.cost_price, p.barcode`,
		productID,
		companyID,
	).Scan(
		&product.ID,
		&product.Name,
		&product.SKU,
		&product.Category,
		&quantity,
		&product.MinQuantity,
		&product.Price,
		&product.Cost,
		&product.Barcode,
	)
	if err != nil {
		return Product{}, err
	}

	product.Quantity = int(quantity)
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
