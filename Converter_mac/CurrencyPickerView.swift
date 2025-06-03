import SwiftUI

struct CurrencyPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedCurrency: Currency
    @State private var searchText = ""
    @EnvironmentObject var model: CurrencyCalculatorModel
    var availableCurrencies: [Currency]
    var title: String
    var onCurrencySelected: (Currency) -> Void
    
    var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return availableCurrencies
        } else {
            return availableCurrencies.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.code.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color.black)
            
            // Строка поиска с улучшенным дизайном
            CustomSearchBar(text: $searchText)
                .padding(.vertical, 10)
            
            // Список валют с отображением курса
            List {
                ForEach(filteredCurrencies) { currency in
                    Button(action: {
                        selectedCurrency = currency
                        onCurrencySelected(currency)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        CurrencyRowView(currency: currency)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.black)
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.black)
            .scrollContentBackground(.hidden)
        }
        .background(Color.black)
    }
}

struct CurrencyRowView: View {
    @EnvironmentObject var model: CurrencyCalculatorModel
    var currency: Currency
    
    var body: some View {
        HStack {
            // Эмодзи-флаг валюты
            FlagCircleView(currency: currency)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                // Название валюты
                Text(currency.name)
                    .foregroundColor(.white)
                    .font(.body)
                
                // Курс валюты
                Text(getCurrencyRate())
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.leading, 8)
            
            Spacer()
            
            // Код валюты
            Text(currency.code)
                .foregroundColor(.gray)
                .font(.body)
        }
        .padding(.vertical, 8)
    }
    
    // Получение курса валюты относительно USD
    private func getCurrencyRate() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4

        if currency.code == "RUB" {
            // Для рубля используем курсы ЦБ РФ, где USD хранит стоимость 1 USD в рублях
            guard let usdRate = model.cbrRates["USD"] else {
                return "Нет данных"
            }
            if let formattedRate = formatter.string(from: NSNumber(value: usdRate)) {
                return "1 USD = \(formattedRate) \(currency.code)"
            }
        } else {
            // Для остальных валют используем ExchangeRate API
            guard let usdRate = model.exchangeRates["USD"],
                  let currencyRate = model.exchangeRates[currency.code] else {
                return "Нет данных"
            }
            let rate = currencyRate / usdRate
            if let formattedRate = formatter.string(from: NSNumber(value: rate)) {
                return "1 USD = \(formattedRate) \(currency.code)"
            }
        }
        return "Нет данных"
    }
}

struct CustomSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Поиск", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
