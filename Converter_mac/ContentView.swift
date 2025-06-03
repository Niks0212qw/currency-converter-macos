import SwiftUI
import AppKit

struct ContentView: View {
    // Вместо использования стандартной инициализации:
    // @StateObject private var model = CurrencyCalculatorModel()
    
    // Используем инициализацию с пользовательскими настройками:
    @StateObject private var model = {
        let model = CurrencyCalculatorModel()
        
        // Меняем местами валюты по умолчанию:
        model.fromCurrency = model.availableCurrencies.first(where: { $0.code == "USD" }) ?? model.fromCurrency
        model.toCurrency = model.availableCurrencies.first(where: { $0.code == "RUB" }) ?? model.toCurrency
        
        // Обновляем курс конвертации после смены валют
        model.updateConversionRate()
        
        return model
    }()
    
    @State private var showFromCurrencyPicker = false
    @State private var showToCurrencyPicker = false
    @Environment(\.scenePhase) private var scenePhase
    
    // Обработка ввода с клавиатуры
    private func handleKeyPress(_ key: String) {
        switch key {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            model.appendDigit(key)
        case ".":
            model.appendDecimal()
        case "+":
            model.performOperation(.add)
        case "-":
            model.performOperation(.subtract)
        case "*", "×", "x":
            model.performOperation(.multiply)
        case "/", "÷":
            model.performOperation(.divide)
        case "%":
            model.performOperation(.percent)
        case "=", "Enter", "Return":
            model.performEquals()
        case "Backspace", "Delete":
            model.deleteLastDigit()
        case "c", "C":
            model.clear()
        default:
            break
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Ловушка для фокуса клавиатуры (невидимая)
                TextField("", text: .constant(""))
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        model.performEquals()
                    }
                
                // From Currency
                Button(action: {
                    showFromCurrencyPicker = true
                }) {
                    CurrencyView(currency: model.fromCurrency, amount: model.displayValue)
                        .background(Color(NSColor.darkGray).opacity(0.9))
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showFromCurrencyPicker) {
                    CurrencyPickerView(
                        selectedCurrency: $model.fromCurrency,
                        availableCurrencies: model.availableCurrencies,
                        title: "Валюты",
                        onCurrencySelected: { newCurrency in
                            model.fromCurrency = newCurrency
                            model.updateConversionRate()
                        }
                    )
                    .environmentObject(model)
                    .frame(width: 400, height: 500)
                }
                
                ZStack {
                    Color.clear
                        .frame(height: 28)
                    
                    Button(action: {
                        model.swapCurrencies()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .offset(y: -12)
                .zIndex(1)
                
                // To Currency
                Button(action: {
                    showToCurrencyPicker = true
                }) {
                    CurrencyView(currency: model.toCurrency, amount: model.convertedValue)
                        .background(Color(NSColor.darkGray).opacity(0.9))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, -20)
                .sheet(isPresented: $showToCurrencyPicker) {
                    CurrencyPickerView(
                        selectedCurrency: $model.toCurrency,
                        availableCurrencies: model.availableCurrencies,
                        title: "Валюты",
                        onCurrencySelected: { newCurrency in
                            model.toCurrency = newCurrency
                            model.updateConversionRate()
                        }
                    )
                    .environmentObject(model)
                    .frame(width: 400, height: 500)
                }
                
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button("C") {
                            model.clear()
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button {
                            model.deleteLastDigit()
                        } label: {
                            Image(systemName: "delete.left")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("%") {
                            model.performOperation(.percent)
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button {
                            model.performOperation(.divide)
                        } label: {
                            Image(systemName: "divide")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                    }
                    
                    Divider().frame(height: 1).background(Color.black)
                    
                    HStack(spacing: 0) {
                        Button("7") {
                            model.appendDigit("7")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("8") {
                            model.appendDigit("8")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("9") {
                            model.appendDigit("9")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button {
                            model.performOperation(.multiply)
                        } label: {
                            Image(systemName: "multiply")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                    }
                    
                    Divider().frame(height: 1).background(Color.black)
                    
                    HStack(spacing: 0) {
                        Button("4") {
                            model.appendDigit("4")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("5") {
                            model.appendDigit("5")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("6") {
                            model.appendDigit("6")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button {
                            model.performOperation(.subtract)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                    }
                    
                    Divider().frame(height: 1).background(Color.black)
                    
                    HStack(spacing: 0) {
                        Button("1") {
                            model.appendDigit("1")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("2") {
                            model.appendDigit("2")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("3") {
                            model.appendDigit("3")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button {
                            model.performOperation(.add)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                    }
                    
                    Divider().frame(height: 1).background(Color.black)
                    
                    HStack(spacing: 0) {
                        Button("0") {
                            model.appendDigit("0")
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        .frame(width: NSScreen.main?.frame.width ?? 0 > 0 ? (320 / 2 - 0.5) : 160)
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button(".") {
                            model.appendDecimal()
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(NSColor.darkGray).opacity(0.9), foregroundColor: .white))
                        
                        Divider().frame(width: 1).background(Color.black)
                        
                        Button("=") {
                            model.performEquals()
                        }
                        .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                    }
                }
                .background(Color.black)
                
                // Исправленная секция с кнопкой обновления
                HStack {
                    Button(action: {
                        // Форсируем обновление курсов валют
                        DispatchQueue.main.async {
                            // Если уже происходит загрузка, попробуем сбросить состояние
                            if model.isLoading {
                                model.resetLoadingState() // Убедитесь, что этот метод добавлен в модель
                            }
                            
                            withAnimation {
                                model.isLoading = true
                            }
                            
                            // Вызываем метод обновления курсов с принудительным обновлением
                            model.fetchAllExchangeRates()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Image(systemName: model.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yellow)
                                .rotationEffect(Angle(degrees: model.isLoading ? 360 : 0))
                                .animation(model.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isLoading)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(false) // Всегда активна, чтобы можно было сбросить зависшую загрузку
                    
                    Text(model.fromCurrency.code == "RUB" || model.toCurrency.code == "RUB" ? "ЦБ РФ" : "ExchangeRate")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(model.lastUpdated)
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(model.calculationHistory)
                            .font(.callout)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black)
            }
            .background(Color.black)
        }
        .accentColor(.yellow)
        .preferredColorScheme(.dark)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            isTextFieldFocused = true
            
            // Явное обновление при запуске
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                model.fetchAllExchangeRates()
            }
            
            // Регистрируем мониторинг клавиатуры
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Получаем символ с клавиатуры
                if let characters = event.characters,
                   !characters.isEmpty {
                    handleKeyPress(characters)
                    
                    // Обрабатываем специальные клавиши
                    switch event.keyCode {
                    case 51: // Backspace
                        model.deleteLastDigit()
                        return nil
                    case 36: // Return
                        model.performEquals()
                        return nil
                    default:
                        break
                    }
                }
                return event
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // Приложение стало активным - запустите периодические обновления
                model.startPeriodicUpdates()
                // Проверяем, нужно ли обновить данные (если прошло много времени)
                if model.shouldUpdate() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        model.fetchAllExchangeRates()
                    }
                }
            case .background, .inactive:
                // Приложение ушло в фон - остановите периодические обновления
                model.stopPeriodicUpdates()
            @unknown default:
                break
            }
        }
    }
    
    // Добавляем FocusState для управления фокусом
    @FocusState private var isTextFieldFocused: Bool
}

// Стиль для кнопок калькулятора
struct CalculatorButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var foregroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 32, weight: .medium))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .overlay(
                Rectangle()
                    .stroke(Color.black, lineWidth: configuration.isPressed ? 3 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Вид для отображения валюты
struct CurrencyView: View {
    var currency: Currency
    var amount: String
    
    var body: some View {
        HStack {
            FlagCircleView(currency: currency)
            Text(currency.code)
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(.white)
            Spacer()
            Text(amount)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 25)
    }
}

// Вид для отображения круга с флагом
struct FlagCircleView: View {
    var currency: Currency
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 60, height: 60)
            Text(currency.flagEmoji)
                .font(.system(size: 32))
        }
    }
}
