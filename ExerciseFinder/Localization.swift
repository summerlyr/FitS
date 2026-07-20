import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: Self { self }
    var locale: Locale { Locale(identifier: rawValue) }
    var title: String { self == .chinese ? "中文" : "English" }

    static var systemDefault: Self {
        Bundle.main.preferredLocalizations.first == "en" ? .english : .chinese
    }
}

@MainActor
final class LanguageStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
        }
    }

    static let defaultsKey = "appLanguage"

    init() {
        language = UserDefaults.standard.string(forKey: Self.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:))
            ?? .systemDefault
    }
}

enum L10n {
    static var language: AppLanguage {
        UserDefaults.standard.string(forKey: LanguageStore.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:))
            ?? .systemDefault
    }

    static var prefersEnglish: Bool {
        language == .english
    }

    static var listSeparator: String {
        prefersEnglish ? ", " : "、"
    }

    static func string(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: string(key),
            locale: language.locale,
            arguments: arguments
        )
    }

    static func formattedDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .weekday()
                .locale(language.locale)
        )
    }

    private static var localizedBundle: Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

struct AppLanguageButton: View {
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        Button {
            languageStore.language = targetLanguage
        } label: {
            Image(systemName: "globe")
        }
        .accessibilityLabel(
            L10n.string(targetLanguage == .english ? "切换到英文" : "切换到中文")
        )
    }

    private var targetLanguage: AppLanguage {
        languageStore.language == .chinese ? .english : .chinese
    }
}
