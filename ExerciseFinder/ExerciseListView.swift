import SwiftUI

struct ExerciseListView: View {
    let searchEnabled: Bool
    @Binding var selectedBodyPart: String
    @Binding var selectedEquipment: String
    @Binding var showsFavoritesOnly: Bool

    @EnvironmentObject private var store: ExerciseStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var searchText = ""

    private var bodyParts: [String] {
        ["全部部位"] + Set(store.exercises.map(\.bodyPart)).sorted()
    }

    private var equipmentOptions: [String] {
        ["全部器械"] + Set(store.exercises.map(\.equipment)).sorted()
    }

    private var filteredExercises: [Exercise] {
        let queries = searchText.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        return store.exercises.filter { exercise in
            let matchesBodyPart = selectedBodyPart == "全部部位"
                || exercise.bodyPart == selectedBodyPart
            let matchesEquipment = selectedEquipment == "全部器械"
                || exercise.equipment == selectedEquipment
            let matchesFavorite = !showsFavoritesOnly || favorites.contains(exercise)
            let matchesSearch: Bool
            if queries.isEmpty {
                matchesSearch = true
            } else {
                let searchableTerms = exercise.searchableTerms
                matchesSearch = queries.allSatisfy {
                    searchableTerms.localizedCaseInsensitiveContains($0)
                }
            }

            return matchesBodyPart && matchesEquipment && matchesFavorite && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("正在加载动作数据库…")
                } else if let errorMessage = store.errorMessage {
                    ContentUnavailableView(
                        "无法加载数据",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    exerciseContent
                }
            }
            .navigationTitle("训练动作")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            showsFavoritesOnly.toggle()
                        }
                    } label: {
                        Image(systemName: "heart")
                            .symbolVariant(showsFavoritesOnly ? .fill : .none)
                            .foregroundStyle(showsFavoritesOnly ? Color.red : Color.primary)
                    }
                    .accessibilityLabel(showsFavoritesOnly ? "显示全部动作" : "只显示收藏")
                }
            }
        }
        .modifier(SearchConfiguration(isEnabled: searchEnabled, text: $searchText))
        .task {
            await store.load()
        }
    }

    private var exerciseContent: some View {
        List {
            filterBar
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemBackground))

            if filteredExercises.isEmpty {
                ContentUnavailableView(
                    "未找到动作",
                    systemImage: "magnifyingglass",
                    description: Text(emptyStateDescription)
                )
                .frame(maxWidth: .infinity, minHeight: 320)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredExercises) { exercise in
                    NavigationLink(value: exercise) {
                        ExerciseRow(exercise: exercise)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }

    private var emptyStateDescription: String {
        if showsFavoritesOnly {
            return "当前条件下没有收藏的动作。"
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "当前筛选条件下没有匹配的动作。"
        }
        return "没有找到与“\(searchText)”匹配的动作，请尝试其他关键词。"
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            FilterMenu(
                title: selectedBodyPart,
                systemImage: "figure.strengthtraining.traditional",
                options: bodyParts,
                selection: $selectedBodyPart
            )

            FilterMenu(
                title: selectedEquipment,
                systemImage: "dumbbell",
                options: equipmentOptions,
                selection: $selectedEquipment
            )

            Spacer(minLength: 0)

            Text("\(filteredExercises.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Button {
                clearFilters()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary.opacity(0.45))
            .disabled(!hasActiveFilters)
            .accessibilityLabel("清除筛选")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(nil, value: showsFavoritesOnly)
    }

    private var hasActiveFilters: Bool {
        selectedBodyPart != "全部部位"
            || selectedEquipment != "全部器械"
            || showsFavoritesOnly
    }

    private func clearFilters() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedBodyPart = "全部部位"
            selectedEquipment = "全部器械"
            showsFavoritesOnly = false
        }
    }
}

private struct SearchConfiguration: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(
                text: $text,
                prompt: "搜索名字、部位、器械或目标肌群"
            )
        } else {
            content
        }
    }
}

private struct FilterMenu: View {
    let title: String
    let systemImage: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(localized(option)).tag(option)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(localized(title))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .opacity(0.7)
            }
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private func localized(_ value: String) -> String {
        if value.hasPrefix("全部") {
            return value
        }
        return ExerciseTerms.localized(value)
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 14) {
            LocalExerciseImage(path: exercise.image)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.localizedName)
                    .font(.headline)
                    .foregroundColor(Color(uiColor: .label))
                    .lineLimit(2)

                Group {
                    Label(ExerciseTerms.localized(exercise.bodyPart), systemImage: "figure.mixed.cardio")
                    Label(ExerciseTerms.localized(exercise.equipment), systemImage: "dumbbell")
                    Label(
                        "目标：\(ExerciseTerms.localized(exercise.target))",
                        systemImage: "scope"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
