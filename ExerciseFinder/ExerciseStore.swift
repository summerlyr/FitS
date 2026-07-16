import SwiftUI

@MainActor
final class ExerciseStore: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    func load() async {
        guard exercises.isEmpty else {
            isLoading = false
            return
        }

        do {
            guard let url = Bundle.main.url(
                forResource: "exercises",
                withExtension: "json",
                subdirectory: "data"
            ) else {
                throw DatasetError.missingFile
            }

            exercises = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([Exercise].self, from: data)
            }.value
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var exerciseIDs: Set<String>

    private let defaultsKey = "favoriteExerciseIDs"

    init() {
        exerciseIDs = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }

    func contains(_ exercise: Exercise) -> Bool {
        exerciseIDs.contains(exercise.id)
    }

    func toggle(_ exercise: Exercise) {
        if exerciseIDs.contains(exercise.id) {
            exerciseIDs.remove(exercise.id)
        } else {
            exerciseIDs.insert(exercise.id)
        }

        UserDefaults.standard.set(Array(exerciseIDs), forKey: defaultsKey)
    }
}

struct TrainingEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let exerciseID: String
    let exerciseName: String
    let date: Date
    let notes: String
}

@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var entries: [TrainingEntry]

    private let defaultsKey = "trainingEntries"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let savedEntries = try? JSONDecoder().decode([TrainingEntry].self, from: data) {
            entries = savedEntries.sorted { $0.date > $1.date }
        } else {
            entries = []
        }
    }

    func add(_ exercise: Exercise, notes: String, date: Date = .now) {
        entries.insert(
            TrainingEntry(
                id: UUID(),
                exerciseID: exercise.id,
                exerciseName: exercise.localizedName,
                date: date,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            at: 0
        )
        save()
    }

    func update(_ entry: TrainingEntry, date: Date, notes: String) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        entries[index] = TrainingEntry(
            id: entry.id,
            exerciseID: entry.exerciseID,
            exerciseName: entry.exerciseName,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        entries.sort { $0.date > $1.date }
        save()
    }

    func delete(_ entry: TrainingEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

private enum DatasetError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        "找不到内置的动作数据库。"
    }
}
