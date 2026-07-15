import SwiftUI
import WebKit

struct ExerciseDetailView: View {
    let exercise: Exercise
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var language = DetailLanguage.chinese

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("语言 / Language", selection: $language) {
                    ForEach(DetailLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                LocalGIFView(path: exercise.gifURL)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    DetailItem(title: language.bodyPartTitle, value: value(exercise.bodyPart))
                    DetailItem(title: language.equipmentTitle, value: value(exercise.equipment))
                    DetailItem(title: language.targetTitle, value: value(exercise.target))
                    DetailItem(title: language.muscleGroupTitle, value: value(exercise.muscleGroup))
                    DetailItem(
                        title: language.secondaryMusclesTitle,
                        value: exercise.secondaryMuscles
                            .map(value)
                            .joined(separator: language.listSeparator)
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(language.instructionsTitle)
                        .font(.title2.bold())

                    ForEach(
                        Array(instructions.enumerated()),
                        id: \.offset
                    ) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(.tint, in: Circle())

                            Text(instruction)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Text(exercise.attribution)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(exercise)
                } label: {
                    Image(systemName: favorites.contains(exercise) ? "heart.fill" : "heart")
                        .foregroundStyle(favorites.contains(exercise) ? Color.red : Color.primary)
                }
                .accessibilityLabel(favorites.contains(exercise) ? "取消收藏" : "收藏")
            }
        }
    }

    private var name: String {
        language == .chinese ? exercise.localizedName : exercise.name.capitalized
    }

    private var instructions: [String] {
        exercise.instructionSteps[language.code]
            ?? exercise.instructionSteps["en"]
            ?? []
    }

    private func value(_ value: String) -> String {
        language == .chinese ? ExerciseTerms.localized(value) : value.capitalized
    }
}

private enum DetailLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh"
    case english = "en"

    var id: Self { self }
    var code: String { rawValue }
    var title: String { self == .chinese ? "中文" : "English" }
    var bodyPartTitle: String { self == .chinese ? "锻炼部位" : "Body Part" }
    var equipmentTitle: String { self == .chinese ? "所需器械" : "Equipment" }
    var targetTitle: String { self == .chinese ? "目标肌肉" : "Target Muscle" }
    var muscleGroupTitle: String { self == .chinese ? "协同肌群" : "Muscle Group" }
    var secondaryMusclesTitle: String { self == .chinese ? "辅助肌群" : "Secondary Muscles" }
    var instructionsTitle: String { self == .chinese ? "动作步骤" : "Instructions" }
    var listSeparator: String { self == .chinese ? "、" : ", " }
}

private struct DetailItem: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct LocalExerciseImage: View {
    let path: String

    var body: some View {
        if let url = Bundle.main.resourceURL?.appending(path: path),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LocalGIFView: UIViewRepresentable {
    let path: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = Bundle.main.resourceURL?.appending(path: path) else {
            return
        }

        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                html, body {
                    width: 100%;
                    height: 100%;
                    margin: 0;
                    overflow: hidden;
                    background: transparent;
                }
                img {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                }
            </style>
        </head>
        <body><img src="\(url.lastPathComponent)"></body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }
}
