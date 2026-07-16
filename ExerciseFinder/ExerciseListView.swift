import SwiftUI

struct ExerciseListView: View {
    let searchEnabled: Bool
    @Binding var selectedBodyPart: String
    @Binding var selectedEquipment: String
    let showsFavoritesOnly: Bool

    @EnvironmentObject private var store: ExerciseStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var searchText = ""
    @State private var exerciseToLog: Exercise?

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
            .navigationTitle(showsFavoritesOnly ? "我的收藏" : "训练动作")
        }
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
                    emptyStateTitle,
                    systemImage: showsFavoritesOnly ? "heart" : "magnifyingglass",
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            exerciseToLog = exercise
                        } label: {
                            Label("今日训练", systemImage: "calendar.badge.plus")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
        .modifier(SearchConfiguration(isEnabled: searchEnabled, text: $searchText))
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .sheet(item: $exerciseToLog) { exercise in
            AddTrainingEntrySheet(exercise: exercise)
        }
    }

    private var emptyStateDescription: String {
        if showsFavoritesOnly {
            return hasActiveFilters
                ? "当前筛选条件下没有收藏动作。"
                : "收藏动作后，它们会显示在这里。"
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
    }

    private var emptyStateTitle: String {
        showsFavoritesOnly ? "暂无收藏" : "未找到动作"
    }

    private var hasActiveFilters: Bool {
        selectedBodyPart != "全部部位"
            || selectedEquipment != "全部器械"
    }

    private func clearFilters() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedBodyPart = "全部部位"
            selectedEquipment = "全部器械"
        }
    }
}

private struct AddTrainingEntrySheet: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var training: TrainingStore
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("训练动作") {
                    Text(exercise.localizedName)
                        .font(.headline)
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("例如：60 kg × 8 次 × 4 组")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("训练记录")
                } footer: {
                    Text("重量、次数和组数暂时作为自由文本记录。")
                }

                Section("训练日期") {
                    Text(Date.now.formatted(
                        .dateTime
                            .year()
                            .month()
                            .day()
                            .weekday()
                            .locale(Locale(identifier: "zh_CN"))
                    ))
                }
            }
            .navigationTitle("加入今日训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") {
                        training.add(exercise, notes: notes)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TrainingView: View {
    @EnvironmentObject private var training: TrainingStore
    @EnvironmentObject private var store: ExerciseStore
    @State private var entryToEdit: TrainingEntry?
    @State private var entryToDelete: TrainingEntry?
    @State private var isShowingDeleteConfirmation = false

    private var trainingDates: [Date] {
        Set(training.entries.map { Calendar.current.startOfDay(for: $0.date) })
            .sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            Group {
                if training.entries.isEmpty {
                    ContentUnavailableView(
                        "还没有训练记录",
                        systemImage: "calendar.badge.plus",
                        description: Text("从动作或收藏列表左滑，将动作加入今日训练。")
                    )
                } else {
                    List {
                        ForEach(trainingDates, id: \.self) { date in
                            Section {
                                ForEach(entries(on: date)) { entry in
                                    TrainingEntryRow(
                                        entry: entry,
                                        exercise: exercise(for: entry)
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            entryToDelete = entry
                                            isShowingDeleteConfirmation = true
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }

                                        Button {
                                            entryToEdit = entry
                                        } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            } header: {
                                Text(date.formatted(
                                    .dateTime
                                        .year()
                                        .month()
                                        .day()
                                        .weekday()
                                        .locale(Locale(identifier: "zh_CN"))
                                ))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("训练记录")
        }
        .task {
            await store.load()
        }
        .sheet(item: $entryToEdit) { entry in
            EditTrainingEntrySheet(entry: entry)
        }
        .alert(
            "删除训练记录？",
            isPresented: $isShowingDeleteConfirmation,
            presenting: entryToDelete
        ) { entry in
            Button("删除", role: .destructive) {
                training.delete(entry)
                entryToDelete = nil
            }
            Button("取消", role: .cancel) {
                entryToDelete = nil
            }
        } message: { entry in
            Text("将删除“\(entry.exerciseName)”这条训练记录。")
        }
    }

    private func entries(on date: Date) -> [TrainingEntry] {
        training.entries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private func exercise(for entry: TrainingEntry) -> Exercise? {
        store.exercises.first { $0.id == entry.exerciseID }
    }
}

private struct TrainingEntryRow: View {
    let entry: TrainingEntry
    let exercise: Exercise?

    var body: some View {
        if let exercise {
            NavigationLink {
                ExerciseDetailView(exercise: exercise)
            } label: {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.exerciseName)
                .font(.headline)
                .foregroundStyle(.primary)

            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EditTrainingEntrySheet: View {
    let entry: TrainingEntry

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var training: TrainingStore
    @State private var notes: String
    @State private var date: Date

    init(entry: TrainingEntry) {
        self.entry = entry
        _notes = State(initialValue: entry.notes)
        _date = State(initialValue: entry.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("训练动作") {
                    Text(entry.exerciseName)
                        .font(.headline)
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                } header: {
                    Text("训练记录")
                } footer: {
                    Text("重量、次数和组数暂时作为自由文本记录。")
                }

                Section("训练日期") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
            }
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .navigationTitle("编辑训练记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        training.update(entry, date: date, notes: notes)
                        dismiss()
                    }
                }
            }
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
