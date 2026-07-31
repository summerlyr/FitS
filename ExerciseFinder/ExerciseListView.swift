import SwiftUI
import PhotosUI

struct ExerciseListView: View {
    let searchEnabled: Bool
    let isSearchTabActive: Bool
    let onSearchDismiss: () -> Void
    @Binding var selectedBodyPart: String
    @Binding var selectedEquipment: String
    let showsFavoritesOnly: Bool

    @EnvironmentObject private var store: ExerciseStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var language: LanguageStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var isVisible = false
    @FocusState private var isSearchFocused: Bool
    @State private var exerciseToLog: Exercise?
    @State private var presentedExercise: Exercise?
    @State private var shouldRestoreSearchFocus = false
    @State private var isShowingSettings = false

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
        let _ = language.language

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
            .navigationTitle(L10n.string(showsFavoritesOnly ? "我的收藏" : "训练动作"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    AppLanguageButton()

                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.string("设置"))
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .modifier(
            SearchConfiguration(
                isEnabled: searchEnabled,
                text: $searchText,
                isPresented: $isSearchPresented,
                isFocused: $isSearchFocused
            )
        )
        .onSubmit(of: .search) {
            dismissSearchKeyboard()
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
                    exerciseLink(for: exercise)
                    .id(language.language.rawValue)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            exerciseToLog = exercise
                        } label: {
                            Label("今日训练", systemImage: "calendar.badge.plus")
                        }
                        .tint(.blue)

                        Button {
                            favorites.toggle(exercise)
                        } label: {
                            Label(
                                L10n.string(favorites.contains(exercise) ? "取消收藏" : "收藏"),
                                systemImage: favorites.contains(exercise) ? "heart.fill" : "heart"
                            )
                        }
                        .tint(favorites.contains(exercise) ? .red : .gray)
                    }
                }
            }
        }
        .listStyle(.plain)
        .modifier(
            ScrollKeyboardDismissConfiguration {
                dismissSearchKeyboard()
            }
        )
        .onAppear {
            isVisible = true
        }
        .onChange(of: isSearchPresented) { wasPresented, isPresented in
            if isSearchTabActive && wasPresented && !isPresented {
                DispatchQueue.main.async {
                    if isVisible && presentedExercise == nil {
                        onSearchDismiss()
                    }
                }
            }
        }
        .onDisappear {
            isVisible = false
            isSearchFocused = false
            if !isSearchTabActive {
                isSearchPresented = false
            }
        }
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .sheet(item: $exerciseToLog) { exercise in
            AddTrainingEntrySheet(exercise: exercise)
        }
        .fullScreenCover(item: $presentedExercise, onDismiss: restoreSearchFocusIfNeeded) {
            SearchExerciseDetailPresentation(exercise: $0)
        }
    }

    private func dismissSearchKeyboard() {
        if #available(iOS 18.0, *) {
            isSearchFocused = false
        } else {
            isSearchPresented = false
        }
    }

    @ViewBuilder
    private func exerciseLink(for exercise: Exercise) -> some View {
        if isSearchTabActive {
            Button {
                shouldRestoreSearchFocus = isSearchFocused
                isSearchFocused = false
                presentedExercise = exercise
            } label: {
                HStack(spacing: 8) {
                    ExerciseRow(exercise: exercise)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: exercise) {
                ExerciseRow(exercise: exercise)
            }
        }
    }

    private func restoreSearchFocusIfNeeded() {
        guard shouldRestoreSearchFocus else { return }
        shouldRestoreSearchFocus = false
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private var emptyStateDescription: String {
        if showsFavoritesOnly {
            return hasActiveFilters
                ? L10n.string("当前筛选条件下没有收藏动作。")
                : L10n.string("收藏动作后，它们会显示在这里。")
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L10n.string("当前筛选条件下没有匹配的动作。")
        }
        return L10n.format("没有找到与“%@”匹配的动作，请尝试其他关键词。", searchText)
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
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
                .lineLimit(1)
                .frame(width: 40, alignment: .trailing)

            Button {
                clearFilters()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary.opacity(0.45))
            .disabled(!hasActiveFilters)
            .accessibilityLabel(L10n.string("清除筛选"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyStateTitle: String {
        L10n.string(showsFavoritesOnly ? "暂无收藏" : "未找到动作")
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

private struct SearchExerciseDetailPresentation: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExerciseDetailView(exercise: exercise)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel(L10n.string("返回"))
                    }
                }
        }
    }
}

private struct AddTrainingEntrySheet: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var training: TrainingStore
    @State private var notes = ""
    @State private var cardioDurationMinutes = 30

    var body: some View {
        NavigationStack {
            Form {
                Section("训练动作") {
                    Text(exercise.localizedName)
                        .font(.headline)
                }

                if exercise.isCardio {
                    Section("有氧记录") {
                        Stepper(
                            L10n.format("%ld 分钟", cardioDurationMinutes),
                            value: $cardioDurationMinutes,
                            in: 5...600,
                            step: 5
                        )
                    }
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text(exercise.isBuiltInActivity
                                 ? "例如：自由泳，1,000 m"
                                 : (exercise.isCardio
                                    ? "例如：轻松跑，5 km"
                                    : "例如：60 kg × 8 次 × 4 组"))
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
                    Text(exercise.isBuiltInActivity
                         ? "可在备注中记录距离、泳姿或配速。"
                         : (exercise.isCardio
                            ? "可在备注中记录距离、配速或阻力。"
                            : "重量、次数和组数暂时作为自由文本记录。"))
                }

                Section("训练日期") {
                    Text(L10n.formattedDate(.now))
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
                        training.add(
                            exercise,
                            notes: notes,
                            cardioDurationMinutes: exercise.isCardio ? cardioDurationMinutes : nil
                        )
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
    @EnvironmentObject private var language: LanguageStore
    @State private var presentationMode = TrainingPresentationMode.calendar
    @State private var visibleMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDate: Date?
    @State private var sessionDateToDelete: Date?
    @State private var isShowingSessionDeleteConfirmation = false
    @State private var isShowingSettings = false

    private var trainingDates: [Date] {
        Set(training.entries.map { Calendar.current.startOfDay(for: $0.date) })
            .sorted(by: >)
    }

    private var cardioTrainingDates: Set<Date> {
        let cardioExerciseIDs = Set(store.exercises.filter(\.isCardio).map(\.id))
        return Set(training.entries.compactMap { entry in
            guard cardioExerciseIDs.contains(entry.exerciseID) else { return nil }
            return Calendar.current.startOfDay(for: entry.date)
        })
    }

    private var strengthTrainingDates: Set<Date> {
        let cardioExerciseIDs = Set(store.exercises.filter(\.isCardio).map(\.id))
        return Set(training.entries.compactMap { entry in
            guard !cardioExerciseIDs.contains(entry.exerciseID) else { return nil }
            return Calendar.current.startOfDay(for: entry.date)
        })
    }

    var body: some View {
        let _ = language.language

        NavigationStack {
            Group {
                switch presentationMode {
                case .calendar:
                    calendarView
                case .list:
                    listView
                }
            }
            .navigationTitle(L10n.string("训练记录"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        presentationMode.toggle()
                    } label: {
                        Image(systemName: presentationMode.toggleIcon)
                    }
                    .accessibilityLabel(L10n.string(presentationMode.toggleLabel))

                    AppLanguageButton()

                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.string("设置"))
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .task {
            await store.load()
        }
        .alert(
            "删除训练？",
            isPresented: $isShowingSessionDeleteConfirmation,
            presenting: sessionDateToDelete
        ) { date in
            Button("删除", role: .destructive) {
                training.deleteSession(on: date)
                sessionDateToDelete = nil
            }
            Button("取消", role: .cancel) {
                sessionDateToDelete = nil
            }
        } message: { date in
            Text(L10n.format(
                "将删除 %@ 的 %ld 个动作和 %ld 张图片，此操作无法恢复。",
                formattedDate(date),
                entries(on: date).count,
                training.photos(on: date).count
            ))
        }
    }

    @ViewBuilder
    private var listView: some View {
        if training.entries.isEmpty {
            emptyState
        } else {
            List {
                ForEach(trainingDates, id: \.self) { date in
                    Section {
                        NavigationLink {
                            TrainingSessionDetailView(date: date)
                        } label: {
                            TrainingSessionRow(
                                entries: entries(on: date),
                                exercises: store.exercises,
                                photoCount: training.photos(on: date).count
                            )
                        }
                        .id(language.language.rawValue)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                sessionDateToDelete = date
                                isShowingSessionDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    } header: {
                        Text(formattedDate(date))
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 20) {
                TrainingCalendar(
                    visibleMonth: $visibleMonth,
                    selectedDate: $selectedDate,
                    strengthTrainingDates: strengthTrainingDates,
                    cardioTrainingDates: cardioTrainingDates
                )

                calendarSelection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var calendarSelection: some View {
        if let selectedDate {
            let selectedEntries = entries(on: selectedDate)

            VStack(alignment: .leading, spacing: 10) {
                Text(formattedDate(selectedDate))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if selectedEntries.isEmpty {
                    Text("当日没有训练记录")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                } else {
                    NavigationLink {
                        TrainingSessionDetailView(date: selectedDate)
                    } label: {
                        HStack(spacing: 12) {
                            TrainingSessionRow(
                                entries: selectedEntries,
                                exercises: store.exercises,
                                photoCount: training.photos(on: selectedDate).count
                            )

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if training.entries.isEmpty {
            emptyState
                .frame(minHeight: 220)
        } else {
            ContentUnavailableView(
                "选择训练日期",
                systemImage: "calendar.badge.checkmark",
                description: Text("选择带标记的日期查看训练记录。")
            )
            .frame(minHeight: 220)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "还没有训练记录",
            systemImage: "calendar.badge.plus",
            description: Text("从动作或收藏列表左滑，将动作加入今日训练。")
        )
    }

    private func entries(on date: Date) -> [TrainingEntry] {
        training.entries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        L10n.formattedDate(date)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var training: TrainingStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var backupShareItem: BackupShareItem?
    @State private var temporaryBackupURL: URL?
    @State private var pendingBackup: FitSBackup?
    @State private var isImportingBackup = false
    @State private var isShowingRestoreConfirmation = false
    @State private var backupNotice: BackupNotice?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        prepareBackupExport()
                    } label: {
                        Label("导出备份", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isImportingBackup = true
                    } label: {
                        Label("导入备份", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("数据备份")
                } footer: {
                    Text("备份包含收藏、训练记录和训练图片。导入会覆盖当前数据。")
                }
            }
            .navigationTitle(L10n.string("设置"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $backupShareItem, onDismiss: {
            if let temporaryBackupURL {
                try? FileManager.default.removeItem(at: temporaryBackupURL)
                self.temporaryBackupURL = nil
            }
        }) { item in
            BackupShareSheet(url: item.url)
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleBackupImport(result)
        }
        .alert(
            "恢复备份？",
            isPresented: $isShowingRestoreConfirmation,
            presenting: pendingBackup
        ) { backup in
            Button("导入并覆盖", role: .destructive) {
                restore(backup)
            }
            Button("取消", role: .cancel) {
                pendingBackup = nil
            }
        } message: { backup in
            Text(restoreConfirmationMessage(for: backup))
        }
        .alert(item: $backupNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "FitS-Backup-\(formatter.string(from: .now))"
    }

    private func prepareBackupExport() {
        do {
            let backup = FitSBackup(
                favoriteExerciseIDs: favorites.exerciseIDs.sorted(),
                trainingEntries: training.entries,
                trainingPhotos: try training.backupPhotos()
            )
            let backupDirectory = FileManager.default.temporaryDirectory.appending(
                path: "FitSBackups",
                directoryHint: .isDirectory
            )
            try FileManager.default.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true
            )
            let backupURL = backupDirectory
                .appending(path: backupFileName)
                .appendingPathExtension("json")
            try backup.encoded().write(to: backupURL, options: .atomic)
            temporaryBackupURL = backupURL
            backupShareItem = BackupShareItem(url: backupURL)
        } catch {
            backupNotice = BackupNotice(
                title: L10n.string("无法导出备份"),
                message: error.localizedDescription
            )
        }
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard fileSize <= FitSBackup.maximumFileSize else {
                throw FitSBackupError.fileTooLarge
            }
            pendingBackup = try FitSBackup.decode(
                from: Data(contentsOf: url, options: .mappedIfSafe)
            )
            isShowingRestoreConfirmation = true
        } catch {
            if (error as NSError).code != NSUserCancelledError {
                backupNotice = BackupNotice(
                    title: L10n.string("无法导入备份"),
                    message: error.localizedDescription
                )
            }
        }
    }

    private func restore(_ backup: FitSBackup) {
        do {
            try training.restore(from: backup)
            favorites.replace(with: Set(backup.favoriteExerciseIDs))
            pendingBackup = nil
            backupNotice = BackupNotice(
                title: L10n.string("备份已恢复"),
                message: backup.includesPhotos
                    ? L10n.string("收藏、训练记录和训练图片已恢复。")
                    : L10n.string("收藏和训练记录已恢复，设备上的训练图片保持不变。")
            )
        } catch {
            backupNotice = BackupNotice(
                title: L10n.string("无法恢复备份"),
                message: error.localizedDescription
            )
        }
    }

    private func restoreConfirmationMessage(for backup: FitSBackup) -> String {
        if backup.includesPhotos {
            return L10n.format(
                "此备份包含 %ld 条训练记录、%ld 个收藏和 %ld 张图片。导入后会覆盖当前训练、收藏和训练图片。",
                backup.trainingEntries.count,
                backup.favoriteExerciseIDs.count,
                backup.trainingPhotos.count
            )
        }

        return L10n.format(
            "此备份包含 %ld 条训练记录和 %ld 个收藏。导入后会覆盖当前训练与收藏，设备上的训练图片会保留。",
            backup.trainingEntries.count,
            backup.favoriteExerciseIDs.count
        )
    }
}

private struct BackupNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct BackupShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct BackupShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

private enum TrainingPresentationMode {
    case calendar
    case list

    var toggleIcon: String {
        self == .calendar ? "list.bullet" : "calendar"
    }

    var toggleLabel: String {
        self == .calendar ? "切换到列表视图" : "切换到日历视图"
    }

    mutating func toggle() {
        self = self == .calendar ? .list : .calendar
    }
}

private struct TrainingCalendar: View {
    @Binding var visibleMonth: Date
    @Binding var selectedDate: Date?
    let strengthTrainingDates: Set<Date>
    let cardioTrainingDates: Set<Date>

    @EnvironmentObject private var language: LanguageStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var calendar: Calendar {
        _ = language.language
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = L10n.language.locale
        return calendar
    }

    private var normalizedStrengthTrainingDates: Set<Date> {
        Set(strengthTrainingDates.map { calendar.startOfDay(for: $0) })
    }

    private var normalizedCardioTrainingDates: Set<Date> {
        Set(cardioTrainingDates.map { calendar.startOfDay(for: $0) })
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leadingEmptyDays) + range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                monthButton(systemImage: "chevron.left", label: "上个月", offset: -1)

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                monthButton(systemImage: "chevron.right", label: "下个月", offset: 1)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 50 else {
                        return
                    }
                    changeMonth(by: value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var monthTitle: String {
        visibleMonth.formatted(
            .dateTime
                .year()
                .month(.wide)
                .locale(L10n.language.locale)
        )
    }

    private func monthButton(systemImage: String, label: String, offset: Int) -> some View {
        Button {
            changeMonth(by: offset)
        } label: {
            Image(systemName: systemImage)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel(L10n.string(label))
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let day = calendar.startOfDay(for: date)
        let hasStrengthTraining = normalizedStrengthTrainingDates.contains(day)
        let hasCardioTraining = normalizedCardioTrainingDates.contains(day)

        return Button {
            selectedDate = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 2) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.body.weight(isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary)
                    )
                    .frame(width: 34, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        }
                    }

                HStack(spacing: 3) {
                    if hasStrengthTraining {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 5, height: 5)
                    }

                    if hasCardioTraining {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            dayAccessibilityLabel(
                date,
                hasStrengthTraining: hasStrengthTraining,
                hasCardioTraining: hasCardioTraining
            )
        )
    }

    private func dayAccessibilityLabel(
        _ date: Date,
        hasStrengthTraining: Bool,
        hasCardioTraining: Bool
    ) -> String {
        let dateText = L10n.formattedDate(date)

        if hasStrengthTraining && hasCardioTraining {
            return "\(dateText)，\(L10n.string("有力量训练和心肺训练"))"
        }
        if hasCardioTraining {
            return "\(dateText)，\(L10n.string("有心肺训练"))"
        }
        if hasStrengthTraining {
            return "\(dateText)，\(L10n.string("有力量训练"))"
        }
        return dateText
    }

    private func changeMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: visibleMonth),
              let start = calendar.dateInterval(of: .month, for: newMonth)?.start else {
            return
        }

        withAnimation(.snappy) {
            visibleMonth = start
            selectedDate = nil
        }
    }
}

private struct TrainingSessionRow: View {
    let entries: [TrainingEntry]
    let exercises: [Exercise]
    let photoCount: Int

    @EnvironmentObject private var language: LanguageStore

    private var muscles: [MuscleSummaryItem] {
        muscleSummary(for: entries, exercises: exercises)
    }

    private var cardioMinutes: Int {
        entries.compactMap(\.cardioDurationMinutes).reduce(0, +)
    }

    private var cardioExerciseNames: [String] {
        let exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        return entries.reduce(into: [String]()) { result, entry in
            guard let exercise = exercisesByID[entry.exerciseID], exercise.isCardio else {
                return
            }
            let name = exercise.localizedName
            if !result.contains(name) {
                result.append(name)
            }
        }
    }

    var body: some View {
        let _ = language.language

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Label(
                    L10n.format("%ld 个动作", entries.count),
                    systemImage: "figure.strengthtraining.traditional"
                )

                if photoCount > 0 {
                    Label(L10n.format("%ld 张图片", photoCount), systemImage: "photo")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !cardioExerciseNames.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        cardioMinutes > 0
                            ? L10n.format("有氧 %ld 分钟", cardioMinutes)
                            : L10n.string("有氧训练"),
                        systemImage: "figure.run"
                    )
                    .foregroundStyle(Color.accentColor)

                    Text(cardioExerciseNames.prefix(3).joined(separator: L10n.listSeparator))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("主要肌群")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(muscles.isEmpty ? L10n.string("暂无肌群信息") : shortMuscleSummary)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 5)
    }

    private var shortMuscleSummary: String {
        let visibleMuscles = muscles.prefix(3).map(\.name).joined(separator: L10n.listSeparator)
        let remainingCount = max(0, muscles.count - 3)
        return remainingCount > 0
            ? L10n.format("%@ 等 %ld 个肌群", visibleMuscles, muscles.count)
            : visibleMuscles
    }
}

private struct TrainingSessionDetailView: View {
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var training: TrainingStore
    @EnvironmentObject private var store: ExerciseStore
    @State private var entryToEdit: TrainingEntry?
    @State private var entryToDelete: TrainingEntry?
    @State private var selectedPhoto: TrainingPhoto?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingSessionDeleteConfirmation = false
    @State private var isShowingCopyConfirmation = false
    @State private var isShowingImportError = false
    @State private var isImportingPhotos = false
    @State private var copiedEntryCount = 0
    @State private var shareImage: UIImage?
    @State private var selectedExercise: Exercise?

    private var entries: [TrainingEntry] {
        training.entries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    private var photos: [TrainingPhoto] {
        training.photos(on: date)
    }

    private var muscles: [MuscleSummaryItem] {
        muscleSummary(for: entries, exercises: store.exercises)
    }

    private var cardioMinutes: Int {
        entries.compactMap(\.cardioDurationMinutes).reduce(0, +)
    }

    var body: some View {
        List {
            Section("训练概览") {
                DatePicker(
                    "训练日期",
                    selection: sessionDate,
                    displayedComponents: .date
                )
                LabeledContent("动作数量", value: L10n.format("%ld 个", entries.count))

                if cardioMinutes > 0 {
                    LabeledContent(
                        "有氧时长",
                        value: L10n.format("%ld 分钟", cardioMinutes)
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("主要肌群")
                        .foregroundStyle(.secondary)

                    Text(detailedMuscleSummary)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 3)
            }

            if !photos.isEmpty {
                Section("训练图片") {
                    TrainingPhotoStrip(
                        photos: photos,
                        selectedPhoto: $selectedPhoto
                    )
                }
            }

            trainingEntriesSection

            Section {
                Button("删除训练", role: .destructive) {
                    isShowingSessionDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("训练详情")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .background(ShareSheetPresenter(image: $shareImage))
        .toolbar {
            if !Calendar.current.isDateInToday(date) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        copiedEntryCount = training.copySession(on: date)
                        isShowingCopyConfirmation = copiedEntryCount > 0
                    } label: {
                        Image(systemName: "square.on.square")
                    }
                    .accessibilityLabel(L10n.string("将整次训练复制到今天"))
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isImportingPhotos {
                    ProgressView()
                } else {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 6,
                        matching: .images
                    ) {
                        Image(systemName: "photo.badge.plus")
                    }
                    .accessibilityLabel(L10n.string("为这次训练添加图片"))
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareImage = makeShareImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.string("分享训练长图"))
            }
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else {
                return
            }

            isImportingPhotos = true
            Task {
                var importFailed = false

                for item in items {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          training.addPhoto(data: data, to: date) else {
                        importFailed = true
                        continue
                    }
                }

                selectedPhotoItems = []
                isImportingPhotos = false
                isShowingImportError = importFailed
            }
        }
        .sheet(item: $entryToEdit) { entry in
            EditTrainingEntrySheet(
                entry: entry,
                exercise: exercise(for: entry)
            )
        }
        .sheet(item: $selectedPhoto) { photo in
            TrainingPhotoDetail(photo: photo)
        }
        .alert("已复制到今天", isPresented: $isShowingCopyConfirmation) {
            Button("好", role: .cancel) {}
        } message: {
            Text(L10n.format("已复制 %ld 个训练动作，原有备注也已保留。", copiedEntryCount))
        }
        .alert("部分图片无法添加", isPresented: $isShowingImportError) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请换一张图片后重试。")
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
            Text(L10n.format(
                "将删除“%@”这条训练记录。",
                exercise(for: entry)?.localizedName ?? entry.exerciseName
            ))
        }
        .alert("删除训练？", isPresented: $isShowingSessionDeleteConfirmation) {
            Button("删除", role: .destructive) {
                training.deleteSession(on: date)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(L10n.format(
                "将删除 %@ 的 %ld 个动作和 %ld 张图片，此操作无法恢复。",
                L10n.formattedDate(date),
                entries.count,
                photos.count
            ))
        }
    }

    private var trainingEntriesSection: some View {
        Section("训练动作") {
            ForEach(entries) { entry in
                let entryExercise = exercise(for: entry)

                TrainingEntryRow(
                    entry: entry,
                    exercise: entryExercise,
                    onSelect: {
                        selectedExercise = entryExercise
                    }
                )
                .contextMenu {
                    Button {
                        entryToEdit = entry
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        entryToDelete = entry
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
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
            .onMove { offsets, destination in
                training.moveEntries(
                    on: date,
                    fromOffsets: offsets,
                    toOffset: destination
                )
            }
        }
    }

    private var sessionDate: Binding<Date> {
        Binding(
            get: { date },
            set: { targetDate in
                guard !Calendar.current.isDate(date, inSameDayAs: targetDate) else {
                    return
                }

                training.moveSession(from: date, to: targetDate)
                dismiss()
            }
        )
    }

    private var detailedMuscleSummary: String {
        guard !muscles.isEmpty else {
            return L10n.string("暂无肌群信息")
        }

        return muscles.map { muscle in
            muscle.count > 1 ? "\(muscle.name) × \(muscle.count)" : muscle.name
        }.joined(separator: L10n.listSeparator)
    }

    private func exercise(for entry: TrainingEntry) -> Exercise? {
        store.exercises.first { $0.id == entry.exerciseID }
    }

    @MainActor
    private func makeShareImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: TrainingShareCard(
                date: date,
                entries: entries,
                exercises: store.exercises,
                photoURLs: photos.map(training.url(for:))
            )
            .environment(\.colorScheme, .light)
            .environment(\.locale, L10n.language.locale)
        )
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        renderer.scale = 2
        return renderer.uiImage
    }
}

private struct TrainingShareCard: View {
    let date: Date
    let entries: [TrainingEntry]
    let exercises: [Exercise]
    let photoURLs: [URL]

    private var exercisesByID: [String: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    private var muscles: [MuscleSummaryItem] {
        muscleSummary(for: entries, exercises: exercises)
    }

    private var cardioMinutes: Int {
        entries.compactMap(\.cardioDurationMinutes).reduce(0, +)
    }

    private var muscleText: String {
        guard !muscles.isEmpty else {
            return L10n.string("暂无肌群信息")
        }

        return muscles.map { muscle in
            muscle.count > 1 ? "\(muscle.name) × \(muscle.count)" : muscle.name
        }.joined(separator: L10n.listSeparator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("FitS", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("训练记录"))
                    .font(.largeTitle.bold())
                Text(L10n.formattedDate(date))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                shareSummaryRow(
                    title: L10n.string("动作数量"),
                    value: L10n.format("%ld 个", entries.count)
                )

                if cardioMinutes > 0 {
                    shareSummaryRow(
                        title: L10n.string("有氧时长"),
                        value: L10n.format("%ld 分钟", cardioMinutes)
                    )
                }

                shareSummaryRow(
                    title: L10n.string("主要肌群"),
                    value: muscleText
                )
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string("训练动作"))
                    .font(.title2.bold())

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    shareEntry(entry, number: index + 1)

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }

            if !photoURLs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.string("训练图片"))
                        .font(.title2.bold())

                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        ForEach(Array(stride(from: 0, to: photoURLs.count, by: 2)), id: \.self) { index in
                            GridRow {
                                sharePhoto(photoURLs[index])

                                if index + 1 < photoURLs.count {
                                    sharePhoto(photoURLs[index + 1])
                                } else {
                                    Color.clear
                                        .frame(height: 160)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 390, alignment: .leading)
        .background(Color.white)
    }

    private func shareSummaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareEntry(_ entry: TrainingEntry, number: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(exercisesByID[entry.exerciseID]?.localizedName ?? entry.exerciseName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let minutes = entry.cardioDurationMinutes {
                    Label(L10n.format("%ld 分钟", minutes), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sharePhoto(_ url: URL) -> some View {
        TrainingPhotoImage(url: url, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MuscleSummaryItem {
    let name: String
    let count: Int
}

private func muscleSummary(
    for entries: [TrainingEntry],
    exercises: [Exercise]
) -> [MuscleSummaryItem] {
    let exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    let counts = entries.reduce(into: [String: Int]()) { result, entry in
        guard let target = exercisesByID[entry.exerciseID]?.target else {
            return
        }
        result[target, default: 0] += 1
    }

    return counts.map { target, count in
        MuscleSummaryItem(name: ExerciseTerms.localized(target), count: count)
    }.sorted { left, right in
        if left.count != right.count {
            return left.count > right.count
        }
        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }
}

private struct TrainingPhotoStrip: View {
    let photos: [TrainingPhoto]
    @Binding var selectedPhoto: TrainingPhoto?

    @EnvironmentObject private var training: TrainingStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    Button {
                        selectedPhoto = photo
                    } label: {
                        TrainingPhotoImage(
                            url: training.url(for: photo),
                            contentMode: .fill
                        )
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("查看训练图片"))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct TrainingPhotoDetail: View {
    let photo: TrainingPhoto

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var training: TrainingStore
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingDeleteError = false

    var body: some View {
        NavigationStack {
            TrainingPhotoImage(
                url: training.url(for: photo),
                contentMode: .fit
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("训练图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(L10n.string("删除训练图片"))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("删除这张训练图片？", isPresented: $isShowingDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    if training.delete(photo) {
                        dismiss()
                    } else {
                        isShowingDeleteError = true
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复。")
            }
            .alert("无法删除图片", isPresented: $isShowingDeleteError) {
                Button("好", role: .cancel) {}
            } message: {
                Text("请稍后重试。")
            }
        }
    }
}

private struct TrainingPhotoImage: View {
    let url: URL
    let contentMode: ContentMode

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TrainingEntryRow: View {
    let entry: TrainingEntry
    let exercise: Exercise?
    let onSelect: () -> Void

    var body: some View {
        if exercise != nil {
            Button(action: onSelect) {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise?.localizedName ?? entry.exerciseName)
                .font(.headline)
                .foregroundStyle(.primary)

            if let minutes = entry.cardioDurationMinutes {
                Label(L10n.format("%ld 分钟", minutes), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }

            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct EditTrainingEntrySheet: View {
    let entry: TrainingEntry
    let exercise: Exercise?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var training: TrainingStore
    @State private var notes: String
    @State private var date: Date
    @State private var cardioDurationMinutes: Int

    init(entry: TrainingEntry, exercise: Exercise?) {
        self.entry = entry
        self.exercise = exercise
        _notes = State(initialValue: entry.notes)
        _date = State(initialValue: entry.date)
        _cardioDurationMinutes = State(initialValue: entry.cardioDurationMinutes ?? 30)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("训练动作") {
                    Text(entry.exerciseName)
                        .font(.headline)
                }

                if isCardio {
                    Section("有氧记录") {
                        Stepper(
                            L10n.format("%ld 分钟", cardioDurationMinutes),
                            value: $cardioDurationMinutes,
                            in: 5...600,
                            step: 5
                        )
                    }
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                } header: {
                    Text("训练记录")
                } footer: {
                    Text(exercise?.isBuiltInActivity == true
                         ? "可在备注中记录距离、泳姿或配速。"
                         : (isCardio
                            ? "可在备注中记录距离、配速或阻力。"
                            : "重量、次数和组数暂时作为自由文本记录。"))
                }

                Section("训练日期") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
            }
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
                        training.update(
                            entry,
                            date: date,
                            notes: notes,
                            cardioDurationMinutes: isCardio ? cardioDurationMinutes : nil
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var isCardio: Bool {
        exercise?.isCardio == true || entry.cardioDurationMinutes != nil
    }
}

private struct ScrollKeyboardDismissConfiguration: ViewModifier {
    let dismiss: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .scrollDismissesKeyboard(.immediately)
                .onScrollPhaseChange { _, phase in
                    if phase != .idle {
                        dismiss()
                    }
                }
        } else {
            content.scrollDismissesKeyboard(.immediately)
        }
    }
}

private struct SearchConfiguration: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String
    @Binding var isPresented: Bool
    let isFocused: FocusState<Bool>.Binding

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            if #available(iOS 18.0, *) {
                searchableContent(content)
                    .searchFocused(isFocused)
            } else {
                searchableContent(content)
            }
        } else {
            content
        }
    }

    private func searchableContent(_ content: Content) -> some View {
        content.searchable(
            text: $text,
            isPresented: $isPresented,
            prompt: Text("搜索名字、部位、器械或目标肌群")
        )
    }
}

private struct FilterMenu: View {
    let title: String
    let systemImage: String
    let options: [String]
    @Binding var selection: String

    @EnvironmentObject private var language: LanguageStore

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(localized(option)).tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(localized(title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                    .frame(maxWidth: 84)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .opacity(0.7)
            }
            .font(.caption)
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private func localized(_ value: String) -> String {
        _ = language.language
        if value.hasPrefix("全部") {
            return L10n.string(value)
        }
        return ExerciseTerms.localized(value)
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    @EnvironmentObject private var language: LanguageStore

    var body: some View {
        let _ = language.language

        HStack(spacing: 14) {
            LocalExerciseImage(
                path: exercise.image,
                systemImage: exercise.mediaPlaceholderSystemImage
            )
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
                        L10n.format("目标：%@", ExerciseTerms.localized(exercise.target)),
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
