import SwiftUI

@main
struct CurrencyConverterApp: App {
    init() {
        // Настройка для отладки сетевых запросов
        URLSession.shared.configuration.timeoutIntervalForRequest = 30
        URLSession.shared.configuration.waitsForConnectivity = true
        
        // Выводим информацию об окружении
        print("Запуск приложения CurrencyConverter для macOS")
        print("Версия macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Текущая директория: \(FileManager.default.currentDirectoryPath)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 320, height: 520)
                .fixedSize()
                .onAppear {
                    print("ContentView появилась")
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 520)
    }
}
