import WidgetKit
import SwiftUI

// Структура представления данных для виджета
struct CurrencyRateEntry: TimelineEntry {
    let date: Date
    let rates: [CurrencyRate]
}

// Модель для хранения информации о курсе валюты
struct CurrencyRate: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let rate: Double
    let flagEmoji: String
    
    // Метод для форматирования курса с двумя десятичными знаками
    func formattedRate() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: rate)) ?? "\(rate)"
    }
}

// Провайдер для получения данных о курсах валют
struct CurrencyRateProvider: TimelineProvider {
    // Заглушка для предварительного просмотра
    func placeholder(in context: Context) -> CurrencyRateEntry {
        CurrencyRateEntry(
            date: Date(),
            rates: [
                CurrencyRate(code: "USD", name: "Доллар США", rate: 85.5, flagEmoji: "🇺🇸"),
                CurrencyRate(code: "EUR", name: "Евро", rate: 92.7, flagEmoji: "🇪🇺"),
                CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65, flagEmoji: "🇹🇷"),
                CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.3, flagEmoji: "🇦🇪")
            ]
        )
    }
    
    // Снепшот для предварительного просмотра
    func getSnapshot(in context: Context, completion: @escaping (CurrencyRateEntry) -> Void) {
        // Сначала используем fallback данные для быстрого отображения
        let fallbackEntry = fallbackEntry()
        completion(fallbackEntry)
        
        // Проверяем, есть ли данные от основного приложения через CurrencyDataService
        let (sharedRates, _) = CurrencyDataService.getCurrencyRates()
        if !sharedRates.isEmpty {
            // Если есть общие данные от приложения, используем их
            let rates = sharedRates.map { CurrencyRate(
                code: $0.code,
                name: $0.name,
                rate: $0.rate,
                flagEmoji: $0.flagEmoji
            )}
            
            completion(CurrencyRateEntry(date: Date(), rates: rates))
        } else {
            // Если нет данных от приложения, простой запрос к ЦБ РФ
            simpleFetchCBRF { entry in
                completion(entry)
            }
        }
    }
    
    // Получение таймлайна с актуальными данными
    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyRateEntry>) -> Void) {
        // Проверяем, есть ли свежие данные от основного приложения
        if CurrencyDataService.isDataFresh(within: 60) {
            let (sharedRates, lastUpdated) = CurrencyDataService.getCurrencyRates()
            if !sharedRates.isEmpty {
                let rates = sharedRates.map { CurrencyRate(
                    code: $0.code,
                    name: $0.name,
                    rate: $0.rate,
                    flagEmoji: $0.flagEmoji
                )}
                
                let entry = CurrencyRateEntry(date: lastUpdated, rates: rates)
                // Обновляем каждые 1-2 часа, если используем данные из приложения
                let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                return
            }
        }
        
        // Если нет свежих данных из приложения, запрашиваем напрямую
        simpleFetchCBRF { entry in
            // Обновляем каждые 3 часа
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date().addingTimeInterval(10800)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    // Максимально упрощенный запрос к ЦБ РФ
    private func simpleFetchCBRF(completion: @escaping (CurrencyRateEntry) -> Void) {
        // URL для получения данных с ЦБ РФ
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            completion(fallbackEntry())
            return
        }
        
        // Создаем запрос с малым таймаутом и игнорированием кэша
        let request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 5)
        
        // Создаем задачу для запроса
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Проверяем наличие данных и отсутствие ошибок
            guard let data = data, error == nil else {
                // При ошибке пробуем запасной источник
                fallbackToExchangeRate { entry in
                    completion(entry)
                }
                return
            }
            
            // Парсим JSON-ответ с использованием JSONSerialization вместо декодера
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let valute = json["Valute"] as? [String: [String: Any]] {
                    
                    var rates: [CurrencyRate] = []
                    
                    // Информация о валютах, которые нам нужны
                    let requiredCurrencies = [
                        ("USD", "Доллар США", "🇺🇸"),
                        ("EUR", "Евро", "🇪🇺"),
                        ("TRY", "Турецкая лира", "🇹🇷"),
                        ("AED", "Дирхам ОАЭ", "🇦🇪")
                    ]
                    
                    // Обработка каждой валюты из ответа
                    for (code, name, flagEmoji) in requiredCurrencies {
                        if let currencyData = valute[code],
                           let value = currencyData["Value"] as? Double,
                           let nominal = currencyData["Nominal"] as? Int {
                            // Вычисляем актуальный курс с учетом номинала
                            let rate = value / Double(nominal)
                            
                            rates.append(CurrencyRate(
                                code: code,
                                name: name,
                                rate: rate,
                                flagEmoji: flagEmoji
                            ))
                        }
                    }
                    
                    // Проверяем, что мы получили все нужные валюты
                    if rates.count < requiredCurrencies.count {
                        // Добавляем отсутствующие валюты с резервными значениями
                        let existingCodes = rates.map { $0.code }
                        for (code, name, flagEmoji) in requiredCurrencies {
                            if !existingCodes.contains(code) {
                                // Резервные значения
                                let backupRate: Double
                                switch code {
                                case "USD": backupRate = 85.5
                                case "EUR": backupRate = 92.7
                                case "TRY": backupRate = 2.65
                                case "AED": backupRate = 23.3
                                default: backupRate = 1.0
                                }
                                
                                rates.append(CurrencyRate(
                                    code: code,
                                    name: name,
                                    rate: backupRate,
                                    flagEmoji: flagEmoji
                                ))
                            }
                        }
                    }
                    
                    // Создаем и возвращаем запись с актуальными данными
                    let successEntry = CurrencyRateEntry(
                        date: Date(),
                        rates: rates
                    )
                    
                    DispatchQueue.main.async {
                        completion(successEntry)
                    }
                } else {
                    // Если не удалось распарсить, используем запасной источник
                    fallbackToExchangeRate { entry in
                        completion(entry)
                    }
                }
            } catch {
                // Если произошла ошибка парсинга, используем запасной источник
                fallbackToExchangeRate { entry in
                    completion(entry)
                }
            }
        }
        
        // Задаем таймаут для запроса
        DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
            if task.state == .running {
                task.cancel()
                // При таймауте используем запасной источник
                fallbackToExchangeRate { entry in
                    completion(entry)
                }
            }
        }
        
        // Запускаем задачу
        task.resume()
    }
    
    // Максимально упрощенный запасной источник - ExchangeRate API
    private func fallbackToExchangeRate(completion: @escaping (CurrencyRateEntry) -> Void) {
        // Если запасной источник тоже не сработает, используем заглушку
        let defaultEntry = fallbackEntry()
        
        // Создаем URL для запроса к ExchangeRate API
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            completion(defaultEntry)
            return
        }
        
        // Создаем запрос с малым таймаутом
        let request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 5)
        
        // Создаем задачу для запроса
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Проверяем наличие данных и отсутствие ошибок
            guard let data = data, error == nil else {
                completion(defaultEntry)
                return
            }
            
            // Парсим JSON-ответ с использованием JSONSerialization
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let rates = json["rates"] as? [String: Double],
                   let rubRate = rates["RUB"] {
                    
                    var currencyRates: [CurrencyRate] = []
                    
                    // USD к рублю (1 USD = X RUB)
                    currencyRates.append(CurrencyRate(
                        code: "USD",
                        name: "Доллар США",
                        rate: rubRate,
                        flagEmoji: "🇺🇸"
                    ))
                    
                    // EUR к рублю
                    if let eurRate = rates["EUR"] {
                        let eurToRub = rubRate / eurRate
                        currencyRates.append(CurrencyRate(
                            code: "EUR",
                            name: "Евро",
                            rate: eurToRub,
                            flagEmoji: "🇪🇺"
                        ))
                    }
                    
                    // TRY к рублю
                    if let tryRate = rates["TRY"] {
                        let tryToRub = rubRate / tryRate
                        currencyRates.append(CurrencyRate(
                            code: "TRY",
                            name: "Турецкая лира",
                            rate: tryToRub,
                            flagEmoji: "🇹🇷"
                        ))
                    }
                    
                    // AED к рублю
                    if let aedRate = rates["AED"] {
                        let aedToRub = rubRate / aedRate
                        currencyRates.append(CurrencyRate(
                            code: "AED",
                            name: "Дирхам ОАЭ",
                            rate: aedToRub,
                            flagEmoji: "🇦🇪"
                        ))
                    }
                    
                    // Проверяем, что у нас есть данные для основных валют
                    if currencyRates.count >= 2 {
                        let successEntry = CurrencyRateEntry(
                            date: Date(),
                            rates: currencyRates
                        )
                        
                        DispatchQueue.main.async {
                            completion(successEntry)
                        }
                        return
                    }
                }
                
                // Если не удалось получить нужные данные, используем заглушку
                completion(defaultEntry)
                
            } catch {
                // Если произошла ошибка парсинга, используем заглушку
                completion(defaultEntry)
            }
        }
        
        // Задаем таймаут для запроса
        DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
            if task.state == .running {
                task.cancel()
                completion(defaultEntry)
            }
        }
        
        // Запускаем задачу
        task.resume()
    }
    
    // Заглушка для случаев, когда нет доступа к данным
    private func fallbackEntry() -> CurrencyRateEntry {
        return CurrencyRateEntry(
            date: Date(),
            rates: [
                CurrencyRate(code: "USD", name: "Доллар США", rate: 85.5, flagEmoji: "🇺🇸"),
                CurrencyRate(code: "EUR", name: "Евро", rate: 92.7, flagEmoji: "🇪🇺"),
                CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65, flagEmoji: "🇹🇷"),
                CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.3, flagEmoji: "🇦🇪")
            ]
        )
    }
}
    // Вид для среднего размера виджета
struct CurrencyWidgetMediumView: View {
    var entry: CurrencyRateProvider.Entry
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: -20) {
                Spacer()
                
                // Список валют без заголовков и дат - теперь с центрированием
                VStack(spacing: 6) {
                    ForEach(entry.rates) { rate in
                        HStack {
                            Text(rate.flagEmoji)
                                .font(.title2)
                            
                            Text(rate.code)
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Spacer()
                            
                            Text("\(rate.formattedRate()) ₽")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        .padding(.horizontal)
                        
                        if rate.id != entry.rates.last?.id {
                            Divider()
                                .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}

// Вид для маленького размера виджета с 3 валютами
struct CurrencyWidgetSmallView: View {
    var entry: CurrencyRateProvider.Entry
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                // Показываем USD, EUR, TRY и AED
                let visibleRates = entry.rates
                    .filter { ["USD", "EUR", "TRY", "AED"].contains($0.code) }
                    .sorted { (a, b) -> Bool in
                        let order = ["USD", "EUR", "TRY", "AED"]
                        return order.firstIndex(of: a.code) ?? 999 < order.firstIndex(of: b.code) ?? 999
                    }
                
                ForEach(visibleRates.prefix(4)) { rate in
                    HStack {
                        Text(rate.flagEmoji)
                            .font(.system(size: 16))
                        
                        Text(rate.code)
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Spacer()
                        
                        Text("\(rate.formattedRate()) ₽")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    
                    if rate.id != visibleRates.last?.id {
                        Divider()
                            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                            .padding(.horizontal, 5)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}

    // Конфигурация виджета
    struct CurrencyWidget: Widget {
        let kind: String = "CurrencyWidget"
        
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: CurrencyRateProvider()) { entry in
                CurrencyWidgetEntryView(entry: entry)
            }
            .configurationDisplayName("Курсы валют")
            .description("Отображает курсы валют по отношению к рублю")
            .supportedFamilies([.systemSmall, .systemMedium])
        }
    }

    // Выбор представления в зависимости от размера виджета
    struct CurrencyWidgetEntryView: View {
        var entry: CurrencyRateProvider.Entry
        @Environment(\.widgetFamily) var family
        
        var body: some View {
            switch family {
            case .systemSmall:
                CurrencyWidgetSmallView(entry: entry)
            case .systemMedium:
                CurrencyWidgetMediumView(entry: entry)
            default:
                CurrencyWidgetMediumView(entry: entry)
            }
        }
    }

    // Предварительный просмотр для виджета
    struct CurrencyWidget_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Превью для темной темы
                CurrencyWidgetEntryView(entry: CurrencyRateEntry(
                    date: Date(),
                    rates: [
                        CurrencyRate(code: "USD", name: "Доллар США", rate: 85.5, flagEmoji: "🇺🇸"),
                        CurrencyRate(code: "EUR", name: "Евро", rate: 92.7, flagEmoji: "🇪🇺"),
                        CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65, flagEmoji: "🇹🇷"),
                        CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.3, flagEmoji: "🇦🇪")
                    ]
                ))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium - Dark")
                .environment(\.colorScheme, .dark)
                
                // Превью для светлой темы
                CurrencyWidgetEntryView(entry: CurrencyRateEntry(
                    date: Date(),
                    rates: [
                        CurrencyRate(code: "USD", name: "Доллар США", rate: 85.5, flagEmoji: "🇺🇸"),
                        CurrencyRate(code: "EUR", name: "Евро", rate: 92.7, flagEmoji: "🇪🇺"),
                        CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65, flagEmoji: "🇹🇷"),
                        CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.3, flagEmoji: "🇦🇪")
                    ]
                ))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium - Light")
                .environment(\.colorScheme, .light)
            }
        }
    }
