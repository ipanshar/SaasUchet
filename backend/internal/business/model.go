package business

import (
	"fmt"
	"strings"

	"github.com/altyncloud/saas-uchet/backend/internal/auth"
)

type Overview struct {
	CompanyName       string        `json:"company_name"`
	Initials          string        `json:"initials"`
	Dashboard         Dashboard     `json:"dashboard"`
	RecentActivities  []Activity    `json:"recent_activities"`
	Clients           []Client      `json:"clients"`
	Products          []Product     `json:"products"`
	Finance           Finance       `json:"finance"`
	Staff             []StaffMember `json:"staff"`
	MenuNotifications int           `json:"menu_notifications"`
}

type Dashboard struct {
	MonthlyRevenue string       `json:"monthly_revenue"`
	RevenueChange  string       `json:"revenue_change"`
	KPIs           []KPI        `json:"kpis"`
	SalesSeries    []ChartPoint `json:"sales_series"`
}

type KPI struct {
	Title      string `json:"title"`
	Value      string `json:"value"`
	Change     string `json:"change"`
	ChangeTone string `json:"change_tone"`
	Icon       string `json:"icon"`
	IconTone   string `json:"icon_tone"`
}

type ChartPoint struct {
	Label string  `json:"label"`
	Value float64 `json:"value"`
}

type Activity struct {
	Title  string `json:"title"`
	Amount string `json:"amount"`
	Time   string `json:"time"`
	Icon   string `json:"icon"`
	Tone   string `json:"tone"`
}

type Client struct {
	Name         string        `json:"name"`
	Contact      string        `json:"contact"`
	Phone        string        `json:"phone"`
	Email        string        `json:"email"`
	Segment      string        `json:"segment"`
	TotalSales   int           `json:"total_sales"`
	Debt         int           `json:"debt"`
	BIN          string        `json:"bin,omitempty"`
	IIN          string        `json:"iin,omitempty"`
	Interactions []Interaction `json:"interactions"`
}

type Interaction struct {
	Title string `json:"title"`
	Date  string `json:"date"`
	Note  string `json:"note"`
}

type Product struct {
	Name        string          `json:"name"`
	SKU         string          `json:"sku"`
	Category    string          `json:"category"`
	Quantity    int             `json:"quantity"`
	MinQuantity int             `json:"min_quantity"`
	Price       int             `json:"price"`
	Cost        int             `json:"cost"`
	Barcode     string          `json:"barcode"`
	Status      string          `json:"status"`
	Movements   []StockMovement `json:"movements"`
}

type StockMovement struct {
	Date     string `json:"date"`
	Document string `json:"document"`
	Quantity int    `json:"quantity"`
	Balance  int    `json:"balance"`
}

type Finance struct {
	TotalBalance      int               `json:"total_balance"`
	Income            int               `json:"income"`
	Expense           int               `json:"expense"`
	Accounts          []BankAccount     `json:"accounts"`
	ExpenseCategories []ExpenseCategory `json:"expense_categories"`
	Transactions      []Transaction     `json:"transactions"`
	CashFlows         []CashFlow        `json:"cash_flows"`
}

type BankAccount struct {
	Name    string `json:"name"`
	Balance int    `json:"balance"`
	Color   string `json:"color"`
	Icon    string `json:"icon"`
}

type ExpenseCategory struct {
	Name  string `json:"name"`
	Value int    `json:"value"`
	Color string `json:"color"`
}

type Transaction struct {
	Type        string `json:"type"`
	Description string `json:"description"`
	Amount      int    `json:"amount"`
	Category    string `json:"category"`
	Date        string `json:"date"`
	Account     string `json:"account"`
}

type CashFlow struct {
	Title       string `json:"title"`
	Subtitle    string `json:"subtitle"`
	Value       string `json:"value"`
	Tone        string `json:"tone"`
	ValueColor  string `json:"value_color"`
	Highlighted bool   `json:"highlighted"`
}

type StaffMember struct {
	Name string `json:"name"`
	Role string `json:"role"`
}

func buildOverview(user auth.User) Overview {
	companyName := `ТОО "Мой Бизнес"`
	if len(user.Companies) > 0 {
		companyName = user.Companies[0].Name
	}

	return Overview{
		CompanyName:       companyName,
		Initials:          initialsOf(companyName),
		MenuNotifications: 5,
		Dashboard: Dashboard{
			MonthlyRevenue: "₸ 2,450,000",
			RevenueChange:  "+12.5%",
			KPIs: []KPI{
				{Title: "Продажи за день", Value: "₸ 125,000", Change: "+8.2%", ChangeTone: "success", Icon: "cart", IconTone: "success"},
				{Title: "Дебиторка", Value: "₸ 456,000", Change: "-3.1%", ChangeTone: "warning", Icon: "receipt", IconTone: "warning"},
				{Title: "Клиенты", Value: "1,234", Change: "+45", ChangeTone: "success", Icon: "group", IconTone: "info"},
				{Title: "Товары", Value: "5,678", Change: "56 новых", ChangeTone: "neutral", Icon: "inventory", IconTone: "primary"},
			},
			SalesSeries: []ChartPoint{
				{Label: "1 июн", Value: 45},
				{Label: "5 июн", Value: 52},
				{Label: "10", Value: 48},
				{Label: "15", Value: 61},
				{Label: "20", Value: 55},
				{Label: "25", Value: 67},
				{Label: "Сегодня", Value: 73},
			},
		},
		RecentActivities: []Activity{
			{Title: `ТОО "Астана Трейд"`, Amount: "₸ 125,000", Time: "10 минут назад", Icon: "cart", Tone: "success"},
			{Title: `ТОО "Поставщик+"`, Amount: "₸ 45,000", Time: "1 час назад", Icon: "inventory", Tone: "warning"},
			{Title: `ИП Нурланов А.Б.`, Amount: "₸ 89,500", Time: "2 часа назад", Icon: "payments", Tone: "success"},
			{Title: `ТОО "Алматы Опт"`, Amount: "₸ 156,000", Time: "3 часа назад", Icon: "description", Tone: "info"},
		},
		Clients: []Client{
			{
				Name:       `ТОО "Астана Трейд"`,
				BIN:        "123456789012",
				Contact:    "Нурланов Азамат",
				Phone:      "+7 (777) 123-45-67",
				Email:      "info@astana-trade.kz",
				Segment:    "VIP",
				TotalSales: 2450000,
				Debt:       125000,
				Interactions: []Interaction{
					{Title: "Звонок", Date: "3 июня 2026", Note: "Обсудили новую поставку"},
					{Title: "Встреча", Date: "1 июня 2026", Note: "Презентация новых товаров"},
					{Title: "Email", Date: "28 мая 2026", Note: "Отправлено КП"},
				},
			},
			{
				Name:       "ИП Сериков А.Б.",
				IIN:        "890123456789",
				Contact:    "Сериков Алмас",
				Phone:      "+7 (701) 234-56-78",
				Email:      "serikov@mail.kz",
				Segment:    "Regular",
				TotalSales: 890000,
				Debt:       0,
				Interactions: []Interaction{
					{Title: "Звонок", Date: "2 июня 2026", Note: "Подтвердил готовность к оплате"},
					{Title: "Email", Date: "29 мая 2026", Note: "Отправили счет на оплату"},
				},
			},
			{
				Name:       `ТОО "Алматы Опт"`,
				BIN:        "234567890123",
				Contact:    "Касымова Айгуль",
				Phone:      "+7 (727) 345-67-89",
				Email:      "almaty-opt@gmail.com",
				Segment:    "VIP",
				TotalSales: 1560000,
				Debt:       45000,
				Interactions: []Interaction{
					{Title: "Встреча", Date: "31 мая 2026", Note: "Согласовали квартальный контракт"},
				},
			},
			{
				Name:       `ТОО "Караганда Снаб"`,
				BIN:        "345678901234",
				Contact:    "Ибрагимов Ерлан",
				Phone:      "+7 (778) 456-78-90",
				Email:      "karaganda@snab.kz",
				Segment:    "Regular",
				TotalSales: 450000,
				Debt:       150000,
				Interactions: []Interaction{
					{Title: "Email", Date: "30 мая 2026", Note: "Напоминание о просроченной задолженности"},
				},
			},
		},
		Products: []Product{
			{
				Name:        "Ноутбук Lenovo ThinkPad",
				SKU:         "TECH-001",
				Category:    "Техника",
				Quantity:    15,
				MinQuantity: 10,
				Price:       350000,
				Cost:        280000,
				Barcode:     "8600123456789",
				Status:      "in_stock",
				Movements: []StockMovement{
					{Date: "2 июня", Document: "Продажа #1234", Quantity: -5, Balance: 15},
					{Date: "28 мая", Document: "Поступление #567", Quantity: 20, Balance: 20},
					{Date: "15 мая", Document: "Продажа #1122", Quantity: -3, Balance: 0},
				},
			},
			{
				Name:        "Офисное кресло Comfort Pro",
				SKU:         "FURN-045",
				Category:    "Мебель",
				Quantity:    3,
				MinQuantity: 5,
				Price:       65000,
				Cost:        45000,
				Barcode:     "8600987654321",
				Status:      "low_stock",
				Movements: []StockMovement{
					{Date: "3 июня", Document: "Продажа #1987", Quantity: -2, Balance: 3},
					{Date: "27 мая", Document: "Поступление #458", Quantity: 10, Balance: 5},
				},
			},
			{
				Name:        "Принтер HP LaserJet",
				SKU:         "TECH-089",
				Category:    "Техника",
				Quantity:    8,
				MinQuantity: 5,
				Price:       125000,
				Cost:        95000,
				Barcode:     "8600555666777",
				Status:      "in_stock",
				Movements: []StockMovement{
					{Date: "1 июня", Document: "Продажа #1820", Quantity: -1, Balance: 8},
				},
			},
			{
				Name:        "Бумага A4 500 листов",
				SKU:         "OFF-234",
				Category:    "Канцелярия",
				Quantity:    0,
				MinQuantity: 20,
				Price:       2500,
				Cost:        1800,
				Barcode:     "8600111222333",
				Status:      "out_of_stock",
				Movements: []StockMovement{
					{Date: "31 мая", Document: "Продажа #1765", Quantity: -12, Balance: 0},
				},
			},
		},
		Finance: Finance{
			TotalBalance: 5032000,
			Income:       2145000,
			Expense:      940000,
			Accounts: []BankAccount{
				{Name: "Kaspi Bank", Balance: 2450000, Color: "#F14635", Icon: "🏦"},
				{Name: "Halyk Bank", Balance: 1890000, Color: "#00A651", Icon: "🏦"},
				{Name: "Forte Bank", Balance: 567000, Color: "#0066B3", Icon: "🏦"},
				{Name: "Касса", Balance: 125000, Color: "#00A86B", Icon: "💰"},
			},
			ExpenseCategories: []ExpenseCategory{
				{Name: "Закупки", Value: 1200000, Color: "#00A86B"},
				{Name: "Зарплата", Value: 900000, Color: "#3B82F6"},
				{Name: "Аренда", Value: 300000, Color: "#F59E0B"},
				{Name: "Другое", Value: 150000, Color: "#8B5CF6"},
			},
			Transactions: []Transaction{
				{Type: "income", Description: `Оплата от ТОО "Астана Трейд"`, Amount: 125000, Category: "Продажи", Date: "3 июня", Account: "Kaspi Bank"},
				{Type: "expense", Description: "Аренда офиса", Amount: 150000, Category: "Операционные расходы", Date: "1 июня", Account: "Halyk Bank"},
				{Type: "income", Description: "Оплата от ИП Сериков", Amount: 89500, Category: "Продажи", Date: "1 июня", Account: "Kaspi Bank"},
				{Type: "expense", Description: "Закуп товара", Amount: 340000, Category: "Закупки", Date: "31 мая", Account: "Forte Bank"},
				{Type: "expense", Description: "Зарплата сотрудникам", Amount: 450000, Category: "Зарплата", Date: "30 мая", Account: "Halyk Bank"},
			},
			CashFlows: []CashFlow{
				{Title: "Операционная деятельность", Subtitle: "Приток", Value: "₸ 1,245,000", Tone: "#22C55E", ValueColor: "#22C55E", Highlighted: false},
				{Title: "Операционная деятельность", Subtitle: "Отток", Value: "₸ 890,000", Tone: "#EF4444", ValueColor: "#EF4444", Highlighted: false},
				{Title: "Чистый денежный поток", Subtitle: "За месяц", Value: "₸ 355,000", Tone: "#00A86B", ValueColor: "#00A86B", Highlighted: true},
			},
		},
		Staff: []StaffMember{
			{Name: user.FullName, Role: "Администратор"},
			{Name: "Касымова Айгуль", Role: "Менеджер"},
			{Name: "Ибрагимов Ерлан", Role: "Кладовщик"},
		},
	}
}

func initialsOf(value string) string {
	normalized := strings.ReplaceAll(value, `"`, "")
	parts := strings.Fields(normalized)
	if len(parts) == 0 {
		return "MB"
	}

	initials := make([]string, 0, 2)
	for _, part := range parts {
		initials = append(initials, strings.ToUpper(string([]rune(part)[0])))
		if len(initials) == 2 {
			break
		}
	}

	return fmt.Sprintf("%s", strings.Join(initials, ""))
}
