// Command seeddemo наполняет демо-стенд для презентации проекта.
//
// ВРЕМЕННЫЙ скрипт: создаёт через публичный HTTP API мебельную компанию,
// 7 пользователей (пароль 12345678) с разными ролями, 7 связанных сотрудников
// на окладах, контрагентов-должников и кредиторов, каталог сырья/товаров/готовой
// мебели и услуг (включая делегированную подрядчику), производство, движение
// документов продаж/закупок за ~3 месяца и проведённые зарплатные ведомости.
//
// Запуск (нужны поднятые Postgres и backend на localhost:8080):
//
//	cd backend && go run ./cmd/seeddemo
//
// Базовый URL переопределяется переменной окружения API_BASE_URL.
// Каждый прогон использует уникальный суффикс в телефонах и названии компании —
// скрипт можно запускать многократно без конфликтов. Удаляется одной папкой.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"
)

const password = "12345678"

var (
	baseURL = getenv("API_BASE_URL", "http://localhost:9090")
	httpc   = &http.Client{Timeout: 30 * time.Second}
	rng     = rand.New(rand.NewSource(time.Now().UnixNano()))
	suffix  = time.Now().Unix() % 1_000_000

	counts = map[string]int{}
)

func main() {
	log.SetFlags(0)
	fmt.Printf("== Seed demo (suffix=%d, base=%s) ==\n", suffix, baseURL)

	// ── Период: последние ~3 месяца ───────────────────────────────────────────
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	from := today.AddDate(0, -3, 0)
	// Дата открытия — на день раньше периода данных, чтобы начальные остатки
	// (касса/счёт, товарные остатки) не искажали график баланса по неделям:
	// эндпоинт company-balance реконструирует историю вычитанием движений
	// после cutoff, и если остаток датирован "сегодня", он пропадает из всех
	// прошлых недель и даёт ложный скачок только в последней.
	openingDate := from.AddDate(0, 0, -1).Format("2006-01-02")

	// ── 1. Пользователи ────────────────────────────────────────────────────────
	people := demoPeople()
	for i := range people {
		people[i].phone = phoneFor(i + 1)
		res := post("/api/v1/auth/register", "", "", map[string]any{
			"full_name": people[i].name,
			"phone":     people[i].phone,
			"password":  password,
		})
		token := sget(res, "access_token")
		if i == 0 {
			people[i].token = token // владелец
		}
		bump("users")
		fmt.Printf("  user: %-32s %s (%s)\n", people[i].name, people[i].phone, people[i].role)
	}
	owner := people[0]

	// ── 2. Компания ────────────────────────────────────────────────────────────
	companyName := fmt.Sprintf("ТОО МебельПро %d", suffix)
	comp := post("/api/v1/companies", owner.token, "", map[string]any{
		"name":    companyName,
		"country": "KZ",
		"iin":     fmt.Sprintf("%012d", 200_000_000_000+suffix),
	})
	companyID := sget(comp, "id")
	fmt.Printf("  company: %s (%s)\n", companyName, companyID)

	api := &client{token: owner.token, company: companyID}

	// Реквизиты компании (банк/адрес) — для печатных форм; best-effort.
	api.tryPut("/api/v1/companies/"+companyID, map[string]any{
		"name":         companyName,
		"legal_form":   "ТОО",
		"country":      "KZ",
		"iin":          fmt.Sprintf("%012d", 200_000_000_000+suffix),
		"phone":        owner.phone,
		"address_line": "г. Алматы, ул. Сатпаева 90",
		"city":         "Алматы",
		"bank_name":    "Kaspi Bank",
		"bank_account": "KZ75914002203KZ00ABC",
		"bank_bik":     "CASPKZKA",
	})

	// ── 3. Участники + карта phone → user_id ──────────────────────────────────
	for i := 1; i < len(people); i++ {
		api.post("/api/v1/companies/"+companyID+"/members", map[string]any{
			"phone": people[i].phone,
			"role":  people[i].role,
		})
		bump("members")
	}
	usersResp := api.get("/api/v1/payroll/users")
	userByPhone := map[string]string{}
	for _, u := range arr(usersResp, "users") {
		um := obj(u)
		userByPhone[sget(um, "phone")] = sget(um, "user_id")
	}

	// ── 4. Счета ────────────────────────────────────────────────────────────────
	bank := sget(api.post("/api/v1/business/accounts", map[string]any{
		"name": "Kaspi Bank", "account_type": "bank", "currency_code": "KZT",
		"bank_name": "Kaspi Bank",
	}), "id")
	cash := sget(api.post("/api/v1/business/accounts", map[string]any{
		"name": "Касса", "account_type": "cash", "currency_code": "KZT",
	}), "id")
	bump("accounts")
	bump("accounts")
	// Начальные остатки — отдельной датированной операцией (а не "opening_balance"
	// при создании счёта), чтобы happened_at был в начале периода, а не "сейчас".
	api.post("/api/v1/business/money-operations", map[string]any{
		"account_id": bank, "direction": "income", "amount": 5_000_000,
		"category": "Начальный остаток", "operation_date": openingDate,
	})
	api.post("/api/v1/business/money-operations", map[string]any{
		"account_id": cash, "direction": "income", "amount": 500_000,
		"category": "Начальный остаток", "operation_date": openingDate,
	})

	// ── 5. Контрагенты (покупатели + поставщики) ───────────────────────────────
	buyers := []string{}
	for _, b := range demoBuyers() {
		id := sget(api.post("/api/v1/business/clients", b), "id")
		buyers = append(buyers, id)
		bump("clients")
	}
	suppliers := []string{}
	for _, s := range demoSuppliers() {
		id := sget(api.post("/api/v1/business/clients", s), "id")
		suppliers = append(suppliers, id)
		bump("clients")
	}

	// ── 6. Сотрудники (связаны с пользователями) ───────────────────────────────
	hire := from.AddDate(0, -1, 0).Format("2006-01-02")
	for i := range people {
		p := &people[i]
		body := map[string]any{
			"user_id":        userByPhone[p.phone],
			"full_name":      p.name,
			"position":       p.position,
			"phone":          p.phone,
			"salary_type":    p.salaryType,
			"monthly_salary": p.monthly,
			"sales_percent":  p.salesPercent,
			"sales_basis":    "revenue",
			"standard_days":  22,
			"status":         "active",
			"hire_date":      hire,
		}
		p.empID = sget(api.post("/api/v1/payroll/employees", body), "id")
		bump("employees")
	}
	salesEmps := []string{}
	prodEmps := []string{}
	for _, p := range people {
		if p.isSales {
			salesEmps = append(salesEmps, p.empID)
		}
		if p.isProd {
			prodEmps = append(prodEmps, p.empID)
		}
	}

	// ── 7. Каталог: товары ─────────────────────────────────────────────────────
	products := demoProducts()
	for i := range products {
		pr := &products[i]
		res := api.post("/api/v1/business/products", map[string]any{
			"name":             pr.name,
			"sku":              pr.sku,
			"product_type":     "consumer_goods",
			"unit_name":        "шт",
			"allowed_to_sell":  pr.sellable,
			"initial_quantity": 0,
			"min_quantity":     5,
			"price":            pr.price,
			"cost":             pr.cost,
		})
		pr.id = sget(res, "id")
		bump("products")
	}
	// Начальные остатки товаров — отдельным датированным документом (а не
	// "initial_quantity" при создании, который заводит остаток "сегодня") по
	// той же причине, что и начальные остатки счетов выше.
	openingLines := []map[string]any{}
	for i := range products {
		pr := &products[i]
		if pr.initQty <= 0 {
			continue
		}
		openingLines = append(openingLines, map[string]any{
			"product_id": pr.id, "quantity": pr.initQty, "unit_price": pr.cost, "unit_cost": pr.cost,
		})
	}
	if len(openingLines) > 0 {
		api.post("/api/v1/business/inventory-documents", map[string]any{
			"document_type": "adjustment",
			"status":        "posted",
			"document_date": openingDate,
			"document_no":   "OPEN-STOCK",
			"lines":         openingLines,
		})
	}
	productByName := map[string]*product{}
	for i := range products {
		productByName[products[i].name] = &products[i]
	}
	// Списки для документов.
	var sellable, rawMats, resale []*product
	for i := range products {
		p := &products[i]
		switch p.kind {
		case "raw":
			rawMats = append(rawMats, p)
		case "good":
			resale = append(resale, p)
			sellable = append(sellable, p)
		case "fin":
			sellable = append(sellable, p)
		}
	}

	// ── 8. Услуги (включая делегированную подрядчику) ──────────────────────────
	services := []serviceDef{
		{name: "Доставка", price: 15000},
		{name: "Монтаж мебели", price: 25000},
		{name: "Установка кухни (с подрядчиком)", price: 40000, external: "ТОО МонтажСервис", externalCost: 15000},
	}
	var saleServices []serviceDef
	for i := range services {
		body := map[string]any{
			"name":            services[i].name,
			"price":           services[i].price,
			"allowed_to_sell": true,
		}
		if services[i].external != "" {
			body["materials"] = []map[string]any{{
				"material_type":         "external_service",
				"external_service_name": services[i].external,
				"quantity":              1,
				"cost":                  services[i].externalCost,
			}}
		}
		services[i].id = sget(api.post("/api/v1/catalog/services", body), "id")
		saleServices = append(saleServices, services[i])
		bump("services")
	}

	// ── 9. Рецепты (техкарты) для готовой мебели ───────────────────────────────
	recipes := []string{}
	for _, r := range demoRecipes() {
		out := productByName[r.output]
		if out == nil {
			continue
		}
		ings := []map[string]any{}
		for name, qty := range r.ingredients {
			if mp := productByName[name]; mp != nil {
				ings = append(ings, map[string]any{"product_id": mp.id, "quantity": qty, "unit_name": "шт"})
			}
		}
		res := api.post("/api/v1/production/recipes", map[string]any{
			"name":           "Производство: " + r.output,
			"description":    "Техкарта изготовления «" + r.output + "»",
			"payroll_amount": r.payroll,
			"ingredients":    ings,
			"outputs":        []map[string]any{{"product_id": out.id, "quantity": 1, "unit_name": "шт"}},
		})
		recipes = append(recipes, sget(res, "id"))
		bump("recipes")
	}

	// Дефолтный склад (создан при заведении остатков товаров).
	warehouseID := ""
	for _, w := range arr(api.get("/api/v1/business/warehouses"), "warehouses") {
		wm := obj(w)
		warehouseID = sget(wm, "id")
		if b, ok := wm["is_default"].(bool); ok && b {
			break
		}
	}

	// ── 10. Производственные заказы (по месяцам) ──────────────────────────────
	for _, m := range monthsBetween(from, today) {
		for n := 0; n < 2; n++ {
			if len(recipes) == 0 || warehouseID == "" || len(prodEmps) < 2 {
				break
			}
			day := dayInMonth(m, today)
			order := api.post("/api/v1/production/orders", map[string]any{
				"recipe_id":           recipes[rng.Intn(len(recipes))],
				"source_warehouse_id": warehouseID,
				"output_warehouse_id": warehouseID,
				"planned_quantity":    2 + rng.Intn(3),
				"planned_date":        day.Format("2006-01-02"),
				"participants": []map[string]any{
					{"employee_id": prodEmps[0], "share_percent": 50},
					{"employee_id": prodEmps[1], "share_percent": 50},
				},
			})
			oid := sget(order, "id")
			api.patch("/api/v1/production/orders/"+oid, map[string]any{"status": "completed"})
			bump("production_orders")
		}
	}

	// ── 11. Документы за период (~2-3/день) ────────────────────────────────────
	saleSeq, purSeq := 0, 0
	for d := from; !d.After(today); d = d.AddDate(0, 0, 1) {
		dateStr := d.Format("2006-01-02")

		// Закупки сырья/товаров (не каждый день).
		if rng.Float64() < 0.35 {
			purSeq++
			lines := []map[string]any{}
			for _, p := range pickProducts(append(append([]*product{}, rawMats...), resale...), 2+rng.Intn(3)) {
				qty := purchaseQtyFor(p)
				lines = append(lines, map[string]any{
					"product_id": p.id, "quantity": qty, "unit_price": p.cost, "unit_cost": p.cost,
				})
			}
			purNo := fmt.Sprintf("PUR-%06d", purSeq)
			api.post("/api/v1/business/inventory-documents", map[string]any{
				"document_type": "purchase_receipt",
				"status":        "posted",
				"document_date": dateStr,
				"document_no":   purNo,
				"client_id":     suppliers[rng.Intn(len(suppliers))],
				"lines":         lines,
			})
			bump("purchases")
			// Кредиторка: ~82% гасим полностью, ~10% частично, ~8% оставляем долг.
			settleLinked(api, bank, purNo, 0.82, 0.70)
		}

		// Продажи (1-3 в день).
		for k := 0; k < 1+rng.Intn(3); k++ {
			saleSeq++
			lines := []map[string]any{}
			// Товарные строки.
			for _, p := range pickProducts(sellable, 1+rng.Intn(2)) {
				qty := 1 + rng.Intn(2)
				price := varyPrice(p.price)
				lines = append(lines, map[string]any{
					"product_id": p.id, "quantity": qty, "unit_price": price, "unit_cost": p.cost,
				})
			}
			// Иногда — услуга (доставка/монтаж/установка).
			if rng.Float64() < 0.5 {
				sv := saleServices[rng.Intn(len(saleServices))]
				lines = append(lines, map[string]any{
					"service_id": sv.id, "quantity": 1, "unit_price": sv.price, "unit_cost": sv.price / 2,
				})
			}
			saleNo := fmt.Sprintf("SALE-%06d", saleSeq)
			api.post("/api/v1/business/inventory-documents", map[string]any{
				"document_type": "sale_issue",
				"status":        "posted",
				"document_date": dateStr,
				"document_no":   saleNo,
				"client_id":     buyers[rng.Intn(len(buyers))],
				"employee_id":   salesEmps[rng.Intn(len(salesEmps))],
				"lines":         lines,
			})
			bump("sales")
			// Дебиторка: ~78% оплачено полностью, ~12% частично, ~10% остаётся долгом.
			settleLinked(api, bank, saleNo, 0.78, 0.60)
		}
	}

	// ── 13. Прочие расходы ─────────────────────────────────────────────────────
	for _, m := range monthsBetween(from, today) {
		ops := []struct {
			cat    string
			amount int
			acc    string
		}{
			{"Аренда", 250000, bank},
			{"Коммунальные услуги", 60000, bank},
			{"Налоги", 150000, bank},
			{"Топливо", 35000, cash},
		}
		for _, o := range ops {
			api.post("/api/v1/business/money-operations", map[string]any{
				"account_id":     o.acc,
				"direction":      "expense",
				"amount":         o.amount,
				"category":       o.cat,
				"description":    o.cat + " за " + m.Format("01.2006"),
				"operation_date": dayInMonth(m, today).Format("2006-01-02"),
			})
			bump("expenses")
		}
	}

	// ── 14. Зарплата ───────────────────────────────────────────────────────────
	curMonth := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, today.Location())
	// Три полных предыдущих месяца — рассчитываем, начисляем премии и выплачиваем.
	for i := 3; i >= 1; i-- {
		m := curMonth.AddDate(0, -i, 0)
		runPayroll(api, bank, m, true)
	}
	// Текущий месяц — открытая ведомость («к выплате»).
	runPayroll(api, bank, curMonth, false)

	// ── Итог ───────────────────────────────────────────────────────────────────
	fmt.Println("\n== Готово ==")
	fmt.Printf("Компания: %s\n", companyName)
	fmt.Printf("Период данных: %s … %s\n", from.Format("2006-01-02"), today.Format("2006-01-02"))
	fmt.Println("\nДоступы (пароль у всех: " + password + "):")
	for _, p := range people {
		fmt.Printf("  %-34s %-14s %s\n", p.name, p.phone, p.role)
	}
	fmt.Println("\nСоздано:")
	for _, k := range []string{"users", "members", "accounts", "clients", "employees", "products", "services", "recipes", "production_orders", "purchases", "sales", "settlements", "expenses", "payroll_periods"} {
		fmt.Printf("  %-18s %d\n", k, counts[k])
	}
	fmt.Printf("\nВойдите владельцем (%s) — увидите дашборд, CRM с должниками, финансы, склад, производство и зарплату.\n", owner.phone)
}

// ── Зарплата за один месяц ──────────────────────────────────────────────────

func runPayroll(api *client, bank string, m time.Time, pay bool) {
	period := api.post("/api/v1/payroll/periods", map[string]any{
		"period_year":  m.Year(),
		"period_month": int(m.Month()),
	})
	pid := sget(period, "id")
	bump("payroll_periods")

	detail := api.post("/api/v1/payroll/periods/"+pid+"/calculate", map[string]any{})
	// Ручные премии: директору и выездным мастерам.
	for _, e := range arr(detail, "entries") {
		em := obj(e)
		pos := sget(em, "position")
		bonus := 0
		switch {
		case contains(pos, "Директор"):
			bonus = 100000
		case contains(pos, "Выездной"):
			bonus = 40000
		}
		if bonus > 0 {
			api.put("/api/v1/payroll/periods/"+pid+"/entries/"+sget(em, "id"), map[string]any{
				"days_worked": 0, "bonus_amount": bonus,
			})
		}
	}
	if pay {
		end := m.AddDate(0, 1, -1)
		api.post("/api/v1/payroll/periods/"+pid+"/pay", map[string]any{
			"account_id":     bank,
			"operation_date": end.Format("2006-01-02"),
		})
	}
}

// ── Погашение денежных документов ───────────────────────────────────────────

// settleLinked находит связанный денежный документ (FIN-<docNo>) и гасит его по
// политике: с вероятностью fullProb — полностью, ещё в 12% случаев — частично
// (partFrac), иначе оставляет долг. Поиск по document_no обходит лимит списка.
func settleLinked(api *client, account, docNo string, fullProb, partFrac float64) {
	finNo := "FIN-" + docNo
	for _, d := range arr(api.get("/api/v1/business/money-documents?search="+finNo), "documents") {
		dm := obj(d)
		if sget(dm, "document_no") != finNo {
			continue
		}
		remaining := num(dm, "remaining_amount")
		if remaining <= 0 {
			return
		}
		r := rng.Float64()
		amount := 0
		switch {
		case r < fullProb:
			amount = remaining // полностью
		case r < fullProb+0.12:
			amount = int(float64(remaining) * partFrac) // частично
		default:
			return // оставляем долг
		}
		if amount <= 0 {
			return
		}
		api.post("/api/v1/business/money-documents/"+sget(dm, "id")+"/settle", map[string]any{
			"account_id":     account,
			"amount":         amount,
			"operation_date": sget(dm, "operation_date"),
		})
		bump("settlements")
		return
	}
}

// ── Демо-данные ──────────────────────────────────────────────────────────────

type member struct {
	name, role, position, salaryType string
	monthly                          int
	salesPercent                     float64
	isSales, isProd                  bool
	phone, token, empID              string
}

func demoPeople() []member {
	return []member{
		{name: "Арман Серіков", role: "owner", position: "Директор", salaryType: "monthly", monthly: 600000},
		{name: "Динара Қасымова", role: "sales", position: "Менеджер по продажам", salaryType: "combined", monthly: 250000, salesPercent: 3, isSales: true},
		{name: "Ербол Тұрсынбек", role: "sales", position: "Менеджер по продажам", salaryType: "combined", monthly: 250000, salesPercent: 3, isSales: true},
		{name: "Саян Әбілқайыр", role: "staff", position: "Выездной мастер (доставка/монтаж)", salaryType: "monthly", monthly: 200000},
		{name: "Тимур Жакаев", role: "staff", position: "Выездной мастер (установка)", salaryType: "monthly", monthly: 200000},
		{name: "Нұрлан Оспанов", role: "warehouse", position: "Столяр (производство)", salaryType: "combined", monthly: 180000, isProd: true},
		{name: "Асель Манапова", role: "warehouse", position: "Сборщик (производство)", salaryType: "combined", monthly: 180000, isProd: true},
	}
}

func demoBuyers() []map[string]any {
	return []map[string]any{
		{"name": "ТОО Уют Мебель", "contact": "Алия", "phone": phoneFor(101), "segment": "vip", "bin": "050340001234"},
		{"name": "ТОО ОфисСтрой", "contact": "Бекзат", "phone": phoneFor(102), "segment": "regular", "bin": "070240005678"},
		{"name": "ИП Сергеев", "contact": "Игорь Сергеев", "phone": phoneFor(103), "segment": "regular", "iin": "850101300111"},
		{"name": "Кафе Астана", "contact": "Гульнар", "phone": phoneFor(104), "segment": "regular", "bin": "120540009012"},
		{"name": "ТОО ХоумДекор", "contact": "Дамир", "phone": phoneFor(105), "segment": "vip", "bin": "160340003456"},
		{"name": "Розничный покупатель Ким", "contact": "Сергей Ким", "phone": phoneFor(106), "segment": "regular", "iin": "900215300222"},
		{"name": "ТОО ГостиницаПлюс", "contact": "Жанна", "phone": phoneFor(107), "segment": "vip", "bin": "110640007890"},
		{"name": "ИП Нурланова", "contact": "Айгуль Нурланова", "phone": phoneFor(108), "segment": "regular", "iin": "880712400333"},
	}
}

func demoSuppliers() []map[string]any {
	return []map[string]any{
		{"name": "ТОО ЛДСП-Снаб", "contact": "Руслан", "phone": phoneFor(121), "segment": "regular", "bin": "030240001111"},
		{"name": "ТОО Фурнитура КЗ", "contact": "Олег", "phone": phoneFor(122), "segment": "regular", "bin": "040340002222"},
		{"name": "ТОО ТекстильОпт", "contact": "Марина", "phone": phoneFor(123), "segment": "regular", "bin": "050440003333"},
		{"name": "ТОО МонтажСервис", "contact": "Канат", "phone": phoneFor(124), "segment": "regular", "bin": "060540004444"},
		{"name": "ТОО МеталлТорг", "contact": "Виктор", "phone": phoneFor(125), "segment": "regular", "bin": "070640005555"},
		{"name": "ТОО СонСбыт (матрасы)", "contact": "Лаура", "phone": phoneFor(126), "segment": "regular", "bin": "080740006666"},
	}
}

type product struct {
	name, sku, kind      string // kind: raw | good | fin
	cost, price, initQty int
	sellable             bool
	id                   string
}

func demoProducts() []product {
	raw := []product{
		{name: "ЛДСП Эггер 18мм", sku: "RAW-01", kind: "raw", cost: 8000, initQty: 250},
		{name: "Кромка ПВХ 2мм", sku: "RAW-02", kind: "raw", cost: 150, initQty: 800},
		{name: "Петли Blum", sku: "RAW-03", kind: "raw", cost: 700, initQty: 400},
		{name: "Направляющие 450мм", sku: "RAW-04", kind: "raw", cost: 1800, initQty: 250},
		{name: "Ручки мебельные", sku: "RAW-05", kind: "raw", cost: 500, initQty: 350},
		{name: "Саморезы (упак)", sku: "RAW-06", kind: "raw", cost: 200, initQty: 100},
		{name: "ДВП задняя стенка", sku: "RAW-07", kind: "raw", cost: 1200, initQty: 100},
		{name: "Поролон и ткань", sku: "RAW-08", kind: "raw", cost: 3500, initQty: 80},
	}
	good := []product{
		{name: "Матрас Comfort", sku: "GOOD-01", kind: "good", sellable: true, cost: 35000, price: 60000, initQty: 40},
		{name: "Зеркало настенное", sku: "GOOD-02", kind: "good", sellable: true, cost: 8000, price: 15000, initQty: 40},
		{name: "Светильник LED", sku: "GOOD-03", kind: "good", sellable: true, cost: 6000, price: 12000, initQty: 40},
	}
	fin := []product{
		{name: "Шкаф-купе", sku: "FIN-01", kind: "fin", sellable: true, cost: 90000, price: 160000, initQty: 90},
		{name: "Кухонный гарнитур", sku: "FIN-02", kind: "fin", sellable: true, cost: 150000, price: 280000, initQty: 90},
		{name: "Стол письменный", sku: "FIN-03", kind: "fin", sellable: true, cost: 35000, price: 65000, initQty: 90},
		{name: "Кровать двуспальная", sku: "FIN-04", kind: "fin", sellable: true, cost: 70000, price: 130000, initQty: 90},
		{name: "Комод", sku: "FIN-05", kind: "fin", sellable: true, cost: 40000, price: 75000, initQty: 90},
	}
	out := []product{}
	for _, p := range raw {
		p.sellable = false
		out = append(out, p)
	}
	for _, p := range good {
		out = append(out, p)
	}
	for _, p := range fin {
		out = append(out, p)
	}
	return out
}

type serviceDef struct {
	name         string
	price        int
	external     string
	externalCost int
	id           string
}

type recipeDef struct {
	output      string
	payroll     int
	ingredients map[string]float64
}

func demoRecipes() []recipeDef {
	return []recipeDef{
		{output: "Шкаф-купе", payroll: 12000, ingredients: map[string]float64{"ЛДСП Эггер 18мм": 4, "Кромка ПВХ 2мм": 12, "Петли Blum": 4, "Направляющие 450мм": 3, "Ручки мебельные": 2, "ДВП задняя стенка": 2, "Саморезы (упак)": 1}},
		{output: "Кухонный гарнитур", payroll: 20000, ingredients: map[string]float64{"ЛДСП Эггер 18мм": 6, "Кромка ПВХ 2мм": 20, "Петли Blum": 10, "Направляющие 450мм": 6, "Ручки мебельные": 8, "Саморезы (упак)": 2}},
		{output: "Стол письменный", payroll: 7000, ingredients: map[string]float64{"ЛДСП Эггер 18мм": 2, "Кромка ПВХ 2мм": 6, "Ручки мебельные": 1, "Саморезы (упак)": 1}},
		{output: "Кровать двуспальная", payroll: 10000, ingredients: map[string]float64{"ЛДСП Эггер 18мм": 3, "Кромка ПВХ 2мм": 8, "ДВП задняя стенка": 1, "Поролон и ткань": 2, "Саморезы (упак)": 1}},
		{output: "Комод", payroll: 6000, ingredients: map[string]float64{"ЛДСП Эггер 18мм": 2, "Кромка ПВХ 2мм": 8, "Направляющие 450мм": 4, "Ручки мебельные": 4, "Саморезы (упак)": 1}},
	}
}

// ── HTTP-клиент ──────────────────────────────────────────────────────────────

type client struct {
	token   string
	company string
}

func (c *client) get(path string) map[string]any { return do("GET", path, c.token, c.company, nil) }
func (c *client) post(path string, b any) map[string]any {
	return do("POST", path, c.token, c.company, b)
}
func (c *client) put(path string, b any) map[string]any {
	return do("PUT", path, c.token, c.company, b)
}

// tryPut выполняет PUT, не прерывая прогон при ошибке (для необязательных данных).
func (c *client) tryPut(path string, b any) {
	if _, err := doSafe("PUT", path, c.token, c.company, b); err != nil {
		fmt.Printf("  warn: PUT %s: %v\n", path, err)
	}
}
func (c *client) patch(path string, b any) map[string]any {
	return do("PATCH", path, c.token, c.company, b)
}

func post(path, token, company string, b any) map[string]any {
	return do("POST", path, token, company, b)
}

func do(method, path, token, company string, body any) map[string]any {
	m, err := doSafe(method, path, token, company, body)
	if err != nil {
		log.Fatalf("%v", err)
	}
	return m
}

func doSafe(method, path, token, company string, body any) (map[string]any, error) {
	var rdr io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, baseURL+path, rdr)
	if err != nil {
		return nil, fmt.Errorf("build %s %s: %w", method, path, err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if company != "" {
		req.Header.Set("X-Company-Id", company)
	}
	resp, err := httpc.Do(req)
	if err != nil {
		return nil, fmt.Errorf("%s %s: %w", method, path, err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("%s %s -> %d: %s", method, path, resp.StatusCode, string(data))
	}
	trimmed := bytes.TrimSpace(data)
	if len(trimmed) == 0 || trimmed[0] != '{' {
		return map[string]any{}, nil
	}
	var m map[string]any
	if err := json.Unmarshal(trimmed, &m); err != nil {
		return nil, fmt.Errorf("decode %s %s: %w body=%s", method, path, err, string(data))
	}
	return m, nil
}

// ── Утилиты ──────────────────────────────────────────────────────────────────

func phoneFor(idx int) string { return fmt.Sprintf("+77%09d", suffix*100+int64(idx)) }

func varyPrice(price int) int {
	if price <= 0 {
		return price
	}
	delta := int(float64(price) * 0.1)
	if delta == 0 {
		return price
	}
	return price - delta + rng.Intn(2*delta+1)
}

func pickProducts(src []*product, n int) []*product {
	if n > len(src) {
		n = len(src)
	}
	idx := rng.Perm(len(src))[:n]
	out := make([]*product, 0, n)
	for _, i := range idx {
		out = append(out, src[i])
	}
	return out
}

func purchaseQtyFor(p *product) int {
	switch p.kind {
	case "raw":
		return 5 + rng.Intn(8)
	case "good":
		return 3 + rng.Intn(5)
	default:
		return 3 + rng.Intn(5)
	}
}

func monthsBetween(from, to time.Time) []time.Time {
	out := []time.Time{}
	m := time.Date(from.Year(), from.Month(), 1, 0, 0, 0, 0, from.Location())
	end := time.Date(to.Year(), to.Month(), 1, 0, 0, 0, 0, to.Location())
	for !m.After(end) {
		out = append(out, m)
		m = m.AddDate(0, 1, 0)
	}
	return out
}

// dayInMonth возвращает случайный день месяца m, не позже today.
func dayInMonth(m, today time.Time) time.Time {
	first := time.Date(m.Year(), m.Month(), 1, 0, 0, 0, 0, m.Location())
	last := first.AddDate(0, 1, -1)
	if last.After(today) {
		last = today
	}
	span := int(last.Sub(first).Hours()/24) + 1
	if span < 1 {
		span = 1
	}
	return first.AddDate(0, 0, rng.Intn(span))
}

func sget(m map[string]any, k string) string {
	if v, ok := m[k].(string); ok {
		return v
	}
	return ""
}

func num(m map[string]any, k string) int {
	if v, ok := m[k].(float64); ok {
		return int(v)
	}
	return 0
}

func arr(m map[string]any, k string) []any {
	if v, ok := m[k].([]any); ok {
		return v
	}
	return nil
}

func obj(v any) map[string]any {
	if m, ok := v.(map[string]any); ok {
		return m
	}
	return map[string]any{}
}

func contains(s, sub string) bool { return bytes.Contains([]byte(s), []byte(sub)) }

func bump(k string) { counts[k]++ }

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
