import SwiftUI
import WebKit

struct ExerciseDetailView: View {
    let exercise: Exercise
    @EnvironmentObject private var store: ExerciseStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var language: DetailLanguage
    @State private var shareImage: UIImage?

    init(exercise: Exercise) {
        self.exercise = exercise
        _language = State(initialValue: L10n.prefersEnglish ? .english : .chinese)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(name)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Picker("语言 / Language", selection: $language) {
                    ForEach(detailLanguages) { language in
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

                if !alternativeExercises.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(language.alternativesTitle)
                            .font(.title2.bold())

                        Text(language.alternativesSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(alternativeExercises) { alternative in
                            NavigationLink {
                                ExerciseDetailView(exercise: alternative)
                            } label: {
                                AlternativeExerciseRow(
                                    exercise: alternative,
                                    language: language
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(ShareSheetPresenter(image: $shareImage))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareImage = makeShareImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(language.shareTitle)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(exercise)
                } label: {
                    Image(systemName: favorites.contains(exercise) ? "heart.fill" : "heart")
                        .foregroundStyle(favorites.contains(exercise) ? Color.red : Color.secondary)
                }
                .accessibilityLabel(
                    L10n.string(favorites.contains(exercise) ? "取消收藏" : "收藏")
                )
            }
        }
    }

    private var name: String {
        language == .chinese ? exercise.chineseName : exercise.name.capitalized
    }

    private var detailLanguages: [DetailLanguage] {
        L10n.prefersEnglish ? [.english, .chinese] : [.chinese, .english]
    }

    private var instructions: [String] {
        exercise.instructionSteps[language.code]
            ?? exercise.instructionSteps["en"]
            ?? []
    }

    private var alternativeExercises: [Exercise] {
        let candidates = store.exercises.filter { candidate in
            candidate.id != exercise.id
                && (candidate.target == exercise.target
                    || candidate.muscleGroup == exercise.muscleGroup
                    || candidate.bodyPart == exercise.bodyPart)
        }

        return Array(
            candidates.sorted { left, right in
                let leftScore = alternativeScore(for: left)
                let rightScore = alternativeScore(for: right)

                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
            .prefix(5)
        )
    }

    private func alternativeScore(for candidate: Exercise) -> Int {
        var score = 0

        if candidate.target == exercise.target { score += 120 }
        if candidate.muscleGroup == exercise.muscleGroup { score += 30 }
        if candidate.bodyPart == exercise.bodyPart { score += 15 }
        if candidate.category == exercise.category { score += 5 }
        if candidate.equipment == exercise.equipment { score += 4 }

        let sharedSecondaryMuscles = Set(candidate.secondaryMuscles)
            .intersection(Set(exercise.secondaryMuscles))
        score += sharedSecondaryMuscles.count * 4

        if candidate.secondaryMuscles.contains(exercise.target) { score += 10 }
        if exercise.secondaryMuscles.contains(candidate.target) { score += 10 }

        let sharedNameTokens = movementTokens(for: candidate)
            .intersection(movementTokens(for: exercise))
        score += sharedNameTokens.count * 12

        return score
    }

    private func movementTokens(for exercise: Exercise) -> Set<String> {
        Set(
            exercise.name
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 2 && !Self.variantWords.contains($0) }
        )
    }

    private static let variantWords: Set<String> = [
        "and", "with", "the", "one", "single", "alternating",
        "assisted", "weighted", "standing", "seated", "lying",
        "incline", "decline", "reverse", "wide", "close", "grip",
        "arm", "leg", "barbell", "dumbbell", "cable", "band", "machine"
    ]

    private func value(_ value: String) -> String {
        language == .chinese ? ExerciseTerms.localizedChinese(value) : value.capitalized
    }

    @MainActor
    private func makeShareImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: ExerciseShareCard(exercise: exercise, language: language)
                .environment(\.colorScheme, .light)
        )
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        renderer.scale = 2
        return renderer.uiImage
    }
}

private struct ShareSheetPresenter: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard let image, !context.coordinator.isPresenting else {
            return
        }

        context.coordinator.isPresenting = true
        let imageBinding = $image

        DispatchQueue.main.async {
            let activityController = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            activityController.completionWithItemsHandler = { _, _, _, _ in
                context.coordinator.isPresenting = false
                imageBinding.wrappedValue = nil
            }
            viewController.present(activityController, animated: true)
        }
    }

    final class Coordinator {
        var isPresenting = false
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
    var alternativesTitle: String { self == .chinese ? "替代动作" : "Alternatives" }
    var alternativesSubtitle: String {
        self == .chinese
            ? "根据目标肌肉、锻炼部位和动作特征推荐"
            : "Recommended by target muscle, body part, and movement pattern"
    }
    var shareTitle: String { self == .chinese ? "分享详情长图" : "Share Full Detail Image" }
    var listSeparator: String { self == .chinese ? "、" : ", " }
}

private struct AlternativeExerciseRow: View {
    let exercise: Exercise
    let language: DetailLanguage

    var body: some View {
        HStack(spacing: 12) {
            LocalExerciseImage(path: exercise.image)
                .frame(width: 72, height: 72)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(equipment)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(target)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }

    private var name: String {
        language == .chinese ? exercise.chineseName : exercise.name.capitalized
    }

    private var equipment: String {
        language == .chinese
            ? ExerciseTerms.localizedChinese(exercise.equipment)
            : exercise.equipment.capitalized
    }

    private var target: String {
        let value = language == .chinese
            ? ExerciseTerms.localizedChinese(exercise.target)
            : exercise.target.capitalized
        let separator = language == .chinese ? "：" : ": "
        return "\(language.targetTitle)\(separator)\(value)"
    }
}

private struct ExerciseShareCard: View {
    let exercise: Exercise
    let language: DetailLanguage

    private var name: String {
        language == .chinese ? exercise.chineseName : exercise.name.capitalized
    }

    private var instructions: [String] {
        exercise.instructionSteps[language.code]
            ?? exercise.instructionSteps["en"]
            ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("FitS", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(.tint)

            Text(name)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)

            LocalExerciseImage(path: exercise.image)
                .frame(height: 342)
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

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text(language.instructionsTitle)
                    .font(.title2.bold())

                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.tint, in: Circle())

                        Text(instruction)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Text(exercise.attribution)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 390, alignment: .leading)
        .background(Color.white)
    }

    private func value(_ value: String) -> String {
        language == .chinese ? ExerciseTerms.localizedChinese(value) : value.capitalized
    }
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
