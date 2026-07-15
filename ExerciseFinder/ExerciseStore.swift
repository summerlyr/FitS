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

private enum DatasetError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        "找不到内置的动作数据库。"
    }
}
