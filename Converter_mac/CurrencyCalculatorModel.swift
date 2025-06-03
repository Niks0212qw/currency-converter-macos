import SwiftUI
import Combine

// Структура для хранения информации о валюте для совместного использования
struct SharedCurrencyRate: Codable {
    let code: String
    let name: String
    let rate: Double
    let flagEmoji: String
    let timestamp: Date
}

// Сервис для обмена данными между главным приложением и виджетом
class CurrencyDataService {
    // Идентификатор группы приложений, должен соответствовать настройкам в Xcode
    static let appGroupIdentifier = "group.com.yourcompany.currencyconverter"
    
    // Ключи для UserDefaults
    private enum UserDefaultsKeys {
        static let currencyRates = "currencyRates"
        static let lastUpdated = "lastUpdated"
    }
    
    // Получение общего UserDefaults для группы приложений
    static var sharedUserDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    // Сохранение курсов валют (вызывается из основного приложения)
    static func saveCurrencyRates(_ rates: [SharedCurrencyRate]) {
        guard let sharedDefaults = sharedUserDefaults else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(rates)
            
            sharedDefaults.set(data, forKey: UserDefaultsKeys.currencyRates)
            sharedDefaults.set(Date(), forKey: UserDefaultsKeys.lastUpdated)
            sharedDefaults.synchronize()
        } catch {
            print("Ошибка при сохранении курсов валют: \(error)")
        }
    }
    
    // Получение курсов валют (вызывается из виджета)
    static func getCurrencyRates() -> ([SharedCurrencyRate], Date) {
        guard let sharedDefaults = sharedUserDefaults else {
            return ([], Date())
        }
        
        // Получаем дату последнего обновления
        let lastUpdated = sharedDefaults.object(forKey: UserDefaultsKeys.lastUpdated) as? Date ?? Date()
        
        // Получаем сохраненные курсы
        guard let data = sharedDefaults.data(forKey: UserDefaultsKeys.currencyRates) else {
            return ([], lastUpdated)
        }
        
        do {
            let decoder = JSONDecoder()
            let rates = try decoder.decode([SharedCurrencyRate].self, from: data)
            return (rates, lastUpdated)
        } catch {
            print("Ошибка при чтении курсов валют: \(error)")
            return ([], lastUpdated)
        }
    }
    
    // Проверка актуальности данных
    static func isDataFresh(within minutes: Int = 30) -> Bool {
        guard let sharedDefaults = sharedUserDefaults else { return false }
        
        guard let lastUpdated = sharedDefaults.object(forKey: UserDefaultsKeys.lastUpdated) as? Date else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute], from: lastUpdated, to: now)
        
        guard let minutesElapsed = components.minute else { return false }
        return minutesElapsed < minutes
    }
}

// Структура для декодирования ответа API Центрального Банка России
struct CBRResponse: Decodable {
    let Date: String
    let PreviousDate: String
    let PreviousURL: String
    let Timestamp: String
    let Valute: [String: CBRCurrency]
    
    struct CBRCurrency: Decodable {
        let ID: String
        let NumCode: String
        let CharCode: String
        let Nominal: Int
        let Name: String
        let Value: Double
        let Previous: Double
    }
}

// Структура для декодирования ответа ExchangeRate API
struct ExchangeRatesResponse: Codable {
    let result: String
    let base_code: String
    let time_last_update_unix: Int
    let rates: [String: Double]
}

struct Currency: Identifiable, Hashable {
    var id = UUID()
    var code: String
    var name: String
    var flagName: String
    
    // Вычисляемое свойство для получения эмодзи-флага
    var flagEmoji: String {
        switch code {
        case "RUB": return "🇷🇺"
        case "USD": return "🇺🇸"
        case "EUR": return "🇪🇺"
        case "TRY": return "🇹🇷"
        case "KZT": return "🇰🇿"
        case "CNY": return "🇨🇳"
        case "AED": return "🇦🇪"
        case "UZS": return "🇺🇿"
        case "BYN": return "🇧🇾"
        case "THB": return "🇹🇭"
        case "UAH": return "🇺🇦"
        case "GBP": return "🇬🇧"
        case "JPY": return "🇯🇵"
        default: return "🏳️"
        }
    }
}

// Перечисление для операций калькулятора
enum CalculatorOperation {
    case none
    case add
    case subtract
    case multiply
    case divide
    case percent
    
    var symbol: String {
        switch self {
        case .none: return ""
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "×"
        case .divide: return "÷"
        case .percent: return "%"
        }
    }
}

class CurrencyCalculatorModel: ObservableObject {
    @Published var displayValue: String = "0"
    @Published var fromCurrency: Currency
    @Published var toCurrency: Currency
    @Published var calculationHistory: String = ""
    @Published var conversionRate: Double = 0.012
    @Published var lastUpdated: String = ""
    @Published var isLoading: Bool = false
    @Published var convertedValue: String = "0"
    @Published var showFromCurrencyPicker = false
    @Published var showToCurrencyPicker = false
    
    // Новые переменные для функционала калькулятора
    @Published var pendingOperation: CalculatorOperation = .none
    @Published var storedValue: Double = 0.0
    @Published var isPerformingOperation: Bool = false
    @Published var showCalculatorHistory: Bool = false
    @Published var calculatorHistory: String = ""
    
    // Словарь для хранения курсов валют из ЦБ РФ
    @Published var cbrRates: [String: Double] = [:]
    // Словарь для хранения курсов валют из ExchangeRate API
    @Published var exchangeRates: [String: Double] = [:]
    
    // Добавляем таймер для периодического обновления
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 60 * 60 * 4.8 // Примерно 5 раз в день (каждые ~4.8 часа)
    
    let availableCurrencies: [Currency] = [
        Currency(code: "RUB", name: "Российский рубль", flagName: "russia"),
        Currency(code: "USD", name: "Доллар США", flagName: "usa"),
        Currency(code: "EUR", name: "Евро", flagName: "europe"),
        Currency(code: "TRY", name: "Турецкая лира", flagName: "turkey"),
        Currency(code: "KZT", name: "Казахский тенге", flagName: "kazakhstan"),
        Currency(code: "CNY", name: "Китайский юань", flagName: "china"),
        Currency(code: "AED", name: "Дирхам ОАЭ", flagName: "uae"),
        Currency(code: "UZS", name: "Узбекский сум", flagName: "uzbekistan"),
        Currency(code: "BYN", name: "Белорусский рубль", flagName: "belarus"),
        Currency(code: "THB", name: "Таиландский бат", flagName: "thailand"),
        Currency(code: "UAH", name: "Украинская гривна", flagName: "ukraine"),
        Currency(code: "GBP", name: "Британский фунт", flagName: "uk"),
        Currency(code: "JPY", name: "Японская йена", flagName: "japan")
    ]
    
    // Резервные курсы на случай проблем с API
    private let backupRates: [String: Double] = [
        "USD": 1.0,
        "EUR": 0.92,
        "RUB": 85.49,
        "GBP": 0.78,
        "JPY": 149.8,
        "CNY": 7.18,
        "TRY": 32.5,
        "KZT": 450.2,
        "AED": 3.67,
        "UZS": 12450.0,
        "BYN": 3.25,
        "THB": 35.8,
        "UAH": 39.5
    ]
    
    init() {
        // Изменяем порядок валют - первой будет USD, второй RUB
        self.fromCurrency = availableCurrencies.first(where: { $0.code == "USD" }) ?? availableCurrencies[1]  // USD
        self.toCurrency = availableCurrencies.first(where: { $0.code == "RUB" }) ?? availableCurrencies[0]    // RUB
        
        // Используем резервные курсы при инициализации
        self.exchangeRates = backupRates
        self.cbrRates = backupRates
        
        // Загружаем актуальные курсы из обоих источников
        fetchAllExchangeRates()
        
        // Запускаем периодическое обновление
        startPeriodicUpdates()
    }
    
    // Метод для проверки необходимости обновления
    func shouldUpdate() -> Bool {
        guard !lastUpdated.isEmpty else { return true }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm"
        
        guard let lastUpdateDate = dateFormatter.date(from: lastUpdated) else {
            return true
        }
        
        // Если прошло более 4 часов с последнего обновления
        return Date().timeIntervalSince(lastUpdateDate) > 4 * 60 * 60
    }
    
    // Метод для запуска периодических обновлений
    func startPeriodicUpdates() {
        // Остановить существующий таймер, если есть
        updateTimer?.invalidate()
        
        // Создать новый таймер для обновления курсов
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.fetchAllExchangeRates()
        }
    }
    
    // Метод для остановки периодических обновлений
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // Метод для сброса состояния загрузки (используется при принудительном обновлении)
    func resetLoadingState() {
        isLoading = false
        print("Состояние загрузки принудительно сброшено")
    }
    
    // Главный метод обновления курсов
    func fetchAllExchangeRates() {
        // Принудительно сбрасываем предыдущее состояние загрузки
        isLoading = true
        print("Начинаем обновление курсов валют - \(Date())")
        
        // 1. Сначала пробуем обновить через ЦБ РФ
        simpleFetchCBR { [weak self] success in
            guard let self = self else { return }
            
            if success {
                // Если ЦБ РФ успешно обновлен - дополнительно обновляем и ExchangeRate
                self.fetchExchangeRateOnly()
            } else {
                // Если ЦБ РФ не удалось обновить, пробуем только ExchangeRate
                self.fetchExchangeRateOnly()
            }
        }
        
        // Гарантированное завершение обновления через 15 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.isLoading {
                print("Принудительное завершение всего процесса обновления по таймауту")
                self.isLoading = false
                self.updateLastUpdated(date: Date())
            }
        }
    }
    
    // Обновленный метод для запроса данных ЦБ РФ
    private func simpleFetchCBR(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            completion(false)
            return
        }
        
        // Создаем запрос с игнорированием кэша для получения актуальных данных
        let request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 7)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            
            do {
                // Используем JSONSerialization для более надежного парсинга
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let valute = json["Valute"] as? [String: [String: Any]] {
                    
                    var rates: [String: Double] = ["RUB": 1.0]
                    
                    // Обрабатываем валюты из ответа ЦБ РФ
                    for (code, currencyData) in valute {
                        if let value = currencyData["Value"] as? Double,
                           let nominal = currencyData["Nominal"] as? Int {
                            let rate = value / Double(nominal)
                            rates[code] = rate
                        }
                    }
                    
                    // Проверяем наличие основных валют
                    let requiredCodes = ["USD", "EUR", "GBP", "CNY"]
                    let hasEnoughData = requiredCodes.filter { rates[$0] != nil }.count >= 3
                    
                    DispatchQueue.main.async {
                        if hasEnoughData {
                            self.cbrRates = rates
                            completion(true)
                        } else {
                            print("ЦБ РФ вернул недостаточно валют")
                            completion(false)
                        }
                    }
                } else {
                    completion(false)
                }
            } catch {
                print("Ошибка парсинга данных ЦБ РФ: \(error)")
                completion(false)
            }
        }.resume()
        
        // Гарантированное завершение через 8 секунд
        DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
            completion(false)
        }
    }
    
    // Упрощенный метод для запроса только ExchangeRate с корректной обработкой всех валют
    private func fetchExchangeRateOnly() {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        // Создаем запрос с игнорированием кэша для получения актуальных данных
        let request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 7)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Обработка завершения в главном потоке
            let finishUpdate = {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.updateLastUpdated(date: Date())
                }
            }
            
            // Проверка на ошибки
            guard let data = data, error == nil else {
                finishUpdate()
                return
            }
            
            do {
                // Используем JSONSerialization для более надежного парсинга
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let rates = json["rates"] as? [String: Double] {
                    
                    // Проверяем, что у нас есть достаточно данных для основных валют
                    let requiredCodes = ["USD", "EUR", "RUB", "GBP", "JPY", "CNY", "TRY"]
                    let hasEnoughData = requiredCodes.filter { rates[$0] != nil }.count >= 3
                    
                    if hasEnoughData {
                        DispatchQueue.main.async {
                            // Копируем все курсы напрямую
                            self.exchangeRates = rates
                            
                            // Принудительно обновляем дату
                            self.updateLastUpdated(date: Date())
                            
                            // Обновляем интерфейс и сохраняем данные
                            self.updateConversionRate()
                            self.saveRatesForWidget()
                            self.isLoading = false
                            
                            print("ExchangeRate курсы успешно обновлены: \(rates.count) валют")
                        }
                    } else {
                        print("ExchangeRate вернул недостаточно данных")
                        finishUpdate()
                    }
                } else {
                    print("Ошибка структуры JSON от ExchangeRate API")
                    finishUpdate()
                }
            } catch {
                print("Ошибка парсинга данных ExchangeRate: \(error)")
                finishUpdate()
            }
        }.resume()
        
        // Гарантированное завершение через 8 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if self.isLoading {
                print("Принудительное завершение запроса к ExchangeRate по таймауту")
                self.isLoading = false
                self.updateLastUpdated(date: Date())
            }
        }
    }
    
    // Вспомогательная функция для форматирования даты из ЦБР
    private func parseDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.date(from: dateString)
    }
    
    // Обновленный метод updateLastUpdated
    private func updateLastUpdated(date: Date? = nil) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm"
        
        // Всегда используем текущую дату или переданную дату
        lastUpdated = dateFormatter.string(from: date ?? Date())
    }
    
    func updateConversionRate() {
        print("Обновляем конверсионный курс: \(fromCurrency.code) -> \(toCurrency.code)")
        
        // Определяем, нужно ли использовать данные ЦБ РФ
        let useCBR = fromCurrency.code == "RUB" || toCurrency.code == "RUB"
        
        // Выбираем источник курсов
        let ratesSource = useCBR ? cbrRates : exchangeRates
        
        print("Используем источник: \(useCBR ? "ЦБ РФ" : "ExchangeRate")")
        print("Доступные валюты в источнике: \(ratesSource.keys.joined(separator: ", "))")
        
        let fromRate = ratesSource[fromCurrency.code] ?? backupRates[fromCurrency.code] ?? 1.0
        let toRate = ratesSource[toCurrency.code] ?? backupRates[toCurrency.code] ?? 1.0
        
        print("Курс для \(fromCurrency.code): \(fromRate)")
        print("Курс для \(toCurrency.code): \(toRate)")

        if useCBR {
            if fromCurrency.code == "RUB" {
                conversionRate = 1.0 / toRate
                print("Расчет RUB -> иностранная: 1.0 / \(toRate) = \(conversionRate)")
            } else if toCurrency.code == "RUB" {
                conversionRate = fromRate
                print("Расчет иностранная -> RUB: \(fromRate)")
            } else {
                conversionRate = toRate / fromRate
                print("Расчет через RUB: \(toRate) / \(fromRate) = \(conversionRate)")
            }
        } else {
            conversionRate = toRate / fromRate
            print("Стандартный расчет: \(toRate) / \(fromRate) = \(conversionRate)")
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 4
        
        if let formatted = formatter.string(from: NSNumber(value: conversionRate)) {
            calculationHistory = "1 \(fromCurrency.code) = \(formatted) \(toCurrency.code)"
            print("Установлена история расчета: \(calculationHistory)")
        }
        
        convert()
    }
    
    // Сохранение курсов валют для доступа из виджета
    private func saveRatesForWidget() {
        // Создаем массив курсов для четырех валют
        var rates: [SharedCurrencyRate] = []
        
        // Получаем курсы из обоих источников
        let rateUSD = cbrRates["USD"] ?? exchangeRates["RUB"] ?? backupRates["RUB"] ?? 85.49
        
        // USD
        rates.append(SharedCurrencyRate(
            code: "USD",
            name: "Доллар США",
            rate: rateUSD,
            flagEmoji: "🇺🇸",
            timestamp: Date()
        ))
        
        // EUR
        let rateEUR = cbrRates["EUR"] ?? (exchangeRates["RUB"] ?? 85.49) / (exchangeRates["EUR"] ?? 0.92)
        rates.append(SharedCurrencyRate(
            code: "EUR",
            name: "Евро",
            rate: rateEUR,
            flagEmoji: "🇪🇺",
            timestamp: Date()
        ))
        
        // TRY
        let rateTRY = cbrRates["TRY"] ?? (exchangeRates["RUB"] ?? 85.49) / (exchangeRates["TRY"] ?? 32.5)
        rates.append(SharedCurrencyRate(
            code: "TRY",
            name: "Турецкая лира",
            rate: rateTRY,
            flagEmoji: "🇹🇷",
            timestamp: Date()
        ))
        
        // AED
        let rateAED = cbrRates["AED"] ?? (exchangeRates["RUB"] ?? 85.49) / (exchangeRates["AED"] ?? 3.67)
        rates.append(SharedCurrencyRate(
            code: "AED",
            name: "Дирхам ОАЭ",
            rate: rateAED,
            flagEmoji: "🇦🇪",
            timestamp: Date()
        ))
        
        // Сохраняем курсы для виджета
        CurrencyDataService.saveCurrencyRates(rates)
    }
    
    func swapCurrencies() {
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
        updateConversionRate()
    }
    
    // MARK: - Методы калькулятора
    
    func appendDigit(_ digit: String) {
        if isPerformingOperation {
            displayValue = digit
            isPerformingOperation = false
        } else if displayValue == "0" {
            displayValue = digit
        } else {
            displayValue += digit
        }
        convert()
    }
    
    func appendDecimal() {
        if isPerformingOperation {
            displayValue = "0."
            isPerformingOperation = false
        } else if !displayValue.contains(".") {
            displayValue += "."
        }
        convert()
    }
    
    func clear() {
        displayValue = "0"
        pendingOperation = .none
        storedValue = 0.0
        calculatorHistory = ""
        convert()
    }
    
    func deleteLastDigit() {
        if displayValue.count > 1 {
            displayValue.removeLast()
        } else {
            displayValue = "0"
        }
        convert()
    }
    
    func performOperation(_ operation: CalculatorOperation) {
        if let currentValue = Double(displayValue.replacingOccurrences(of: ",", with: ".")) {
            if operation == .percent {
                let percentResult = currentValue / 100.0
                displayValue = formatDisplayValue(percentResult)
                convert()
                return
            }
            
            if pendingOperation != .none {
                let result = calculateResult(storedValue, currentValue)
                displayValue = formatDisplayValue(result)
                storedValue = result
            } else {
                storedValue = currentValue
            }
            
            pendingOperation = operation
            isPerformingOperation = true
            calculatorHistory = "\(formatDisplayValue(storedValue)) \(operation.symbol)"
        }
        
        convert()
    }
    
    func performEquals() {
        if pendingOperation != .none {
            if let currentValue = Double(displayValue.replacingOccurrences(of: ",", with: ".")) {
                let result = calculateResult(storedValue, currentValue)
                calculatorHistory = "\(formatDisplayValue(storedValue)) \(pendingOperation.symbol) \(formatDisplayValue(currentValue)) = \(formatDisplayValue(result))"
                displayValue = formatDisplayValue(result)
                pendingOperation = .none
                isPerformingOperation = true
                convert()
            }
        }
    }
    
    private func calculateResult(_ firstValue: Double, _ secondValue: Double) -> Double {
        switch pendingOperation {
        case .add:
            return firstValue + secondValue
        case .subtract:
            return firstValue - secondValue
        case .multiply:
            return firstValue * secondValue
        case .divide:
            return secondValue != 0 ? firstValue / secondValue : 0
        case .percent:
            return firstValue * (secondValue / 100.0)
        case .none:
            return secondValue
        }
    }
    
    private func formatDisplayValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formatter.maximumFractionDigits = 0
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    
    func convert() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        if let number = formatter.number(from: displayValue) {
            let result = number.doubleValue * conversionRate
            formatter.maximumFractionDigits = 2
            if let formattedResult = formatter.string(from: NSNumber(value: result)) {
                convertedValue = formattedResult
            } else {
                convertedValue = "Ошибка"
            }
        } else {
            let cleanValue = displayValue
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            
            if let value = Double(cleanValue) {
                let result = value * conversionRate
                formatter.maximumFractionDigits = 2
                if let formattedResult = formatter.string(from: NSNumber(value: result)) {
                    convertedValue = formattedResult
                } else {
                    convertedValue = "Ошибка"
                }
            } else {
                convertedValue = "0"
            }
        }
    }
    
    func getRateForCurrency(_ currency: Currency) -> String {
        let ratesSource = currency.code == "RUB" ? cbrRates : exchangeRates
        
        guard let usdRate = exchangeRates["USD"],
              let currencyRate = ratesSource[currency.code] else {
            return "N/A"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        
        let rate = currencyRate / usdRate
        if let formattedRate = formatter.string(from: NSNumber(value: rate)) {
            return "1 USD = \(formattedRate) \(currency.code)"
        }
        
        return "N/A"
    }
}
