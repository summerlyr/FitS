import SwiftUI
import ImageIO
import UIKit

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

struct TrainingPhoto: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let fileName: String
}

@MainActor
final class TrainingStore: ObservableObject {
    @Published private(set) var entries: [TrainingEntry]
    @Published private(set) var photos: [TrainingPhoto]

    private let defaultsKey = "trainingEntries"
    private let photosDefaultsKey = "trainingPhotos"
    private let photosDirectory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    )[0].appending(path: "TrainingPhotos", directoryHint: .isDirectory)

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let savedEntries = try? JSONDecoder().decode([TrainingEntry].self, from: data) {
            entries = savedEntries.sorted { $0.date > $1.date }
        } else {
            entries = []
        }

        if let data = UserDefaults.standard.data(forKey: photosDefaultsKey),
           let savedPhotos = try? JSONDecoder().decode([TrainingPhoto].self, from: data) {
            photos = savedPhotos.sorted { $0.date > $1.date }
        } else {
            photos = []
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

    func deleteSession(on date: Date) {
        let sessionPhotos = photos.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }

        for photo in sessionPhotos {
            try? FileManager.default.removeItem(at: url(for: photo))
        }

        entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        photos.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        save()
        savePhotos()
    }

    func moveSession(from sourceDate: Date, to targetDate: Date) {
        let calendar = Calendar.current
        guard !calendar.isDate(sourceDate, inSameDayAs: targetDate) else {
            return
        }

        let sourceStart = calendar.startOfDay(for: sourceDate)
        let targetStart = calendar.startOfDay(for: targetDate)
        let offset = targetStart.timeIntervalSince(sourceStart)

        entries = entries.map { entry in
            guard calendar.isDate(entry.date, inSameDayAs: sourceDate) else {
                return entry
            }

            return TrainingEntry(
                id: entry.id,
                exerciseID: entry.exerciseID,
                exerciseName: entry.exerciseName,
                date: entry.date.addingTimeInterval(offset),
                notes: entry.notes
            )
        }
        photos = photos.map { photo in
            guard calendar.isDate(photo.date, inSameDayAs: sourceDate) else {
                return photo
            }

            return TrainingPhoto(
                id: photo.id,
                date: photo.date.addingTimeInterval(offset),
                fileName: photo.fileName
            )
        }

        entries.sort { $0.date > $1.date }
        photos.sort { $0.date > $1.date }
        save()
        savePhotos()
    }

    @discardableResult
    func copySession(on sourceDate: Date, to targetDate: Date = .now) -> Int {
        let sourceEntries = entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: sourceDate) }
            .sorted { $0.date < $1.date }

        guard !sourceEntries.isEmpty else {
            return 0
        }

        let copiedEntries = sourceEntries.enumerated().map { index, entry in
            TrainingEntry(
                id: UUID(),
                exerciseID: entry.exerciseID,
                exerciseName: entry.exerciseName,
                date: targetDate.addingTimeInterval(Double(index) / 1000),
                notes: entry.notes
            )
        }

        entries.append(contentsOf: copiedEntries)
        entries.sort { $0.date > $1.date }
        save()
        return copiedEntries.count
    }

    @discardableResult
    func addPhoto(data: Data, to date: Date) -> Bool {
        guard let jpegData = preparedPhotoData(from: data) else {
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: photosDirectory,
                withIntermediateDirectories: true
            )
            let fileName = "\(UUID().uuidString).jpg"
            try jpegData.write(
                to: photosDirectory.appending(path: fileName),
                options: .atomic
            )
            photos.insert(
                TrainingPhoto(id: UUID(), date: date, fileName: fileName),
                at: 0
            )
            savePhotos()
            return true
        } catch {
            return false
        }
    }

    func photos(on date: Date) -> [TrainingPhoto] {
        photos.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func url(for photo: TrainingPhoto) -> URL {
        photosDirectory.appending(path: photo.fileName)
    }

    @discardableResult
    func delete(_ photo: TrainingPhoto) -> Bool {
        let photoURL = url(for: photo)

        do {
            if FileManager.default.fileExists(atPath: photoURL.path) {
                try FileManager.default.removeItem(at: photoURL)
            }
            photos.removeAll { $0.id == photo.id }
            savePhotos()
            return true
        } catch {
            return false
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func savePhotos() {
        guard let data = try? JSONEncoder().encode(photos) else {
            return
        }
        UserDefaults.standard.set(data, forKey: photosDefaultsKey)
    }

    private func preparedPhotoData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2048,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary
              ) else {
            return nil
        }

        return UIImage(cgImage: image).jpegData(compressionQuality: 0.82)
    }
}

private enum DatasetError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        "找不到内置的动作数据库。"
    }
}
