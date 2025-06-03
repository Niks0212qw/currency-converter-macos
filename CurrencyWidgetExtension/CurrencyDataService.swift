import Foundation

// Структура для хранения информации о валюте для совместного использования
struct SharedCurrencyRate: Codable {
    let code: String
    let name: String
    let rate: Double
    let flagEmoji: String
    let timestamp: Date
}

/// Сервис для обмена данными между главным приложением и виджетом
class CurrencyDataService {
    // Идентификатор группы приложений, должен соответствовать настройкам в Xcode
    private static let appGroupIdentifier = "group.com.bonitalabs.currencyconverter"
    
    // Ключи для UserDefaults
    private enum UserDefaultsKeys {
        static let currencyRates = "currencyRates"
        static let lastUpdated = "lastUpdated"
    }
    
    // Получение общего UserDefaults для группы приложений
    private static var sharedUserDefaults: UserDefaults? {
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
