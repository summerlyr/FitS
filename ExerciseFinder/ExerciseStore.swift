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
                let datasetExercises = try JSONDecoder().decode([Exercise].self, from: data)
                return (datasetExercises + Exercise.builtInActivities).sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
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

    func replace(with exerciseIDs: Set<String>) {
        self.exerciseIDs = exerciseIDs
        UserDefaults.standard.set(Array(exerciseIDs), forKey: defaultsKey)
    }
}

struct TrainingEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let exerciseID: String
    let exerciseName: String
    let date: Date
    let notes: String
    let cardioDurationMinutes: Int?
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

    func add(
        _ exercise: Exercise,
        notes: String,
        cardioDurationMinutes: Int? = nil,
        date: Date = .now
    ) {
        entries.insert(
            TrainingEntry(
                id: UUID(),
                exerciseID: exercise.id,
                exerciseName: exercise.localizedName,
                date: date,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                cardioDurationMinutes: exercise.isCardio ? cardioDurationMinutes : nil
            ),
            at: 0
        )
        save()
    }

    func update(
        _ entry: TrainingEntry,
        date: Date,
        notes: String,
        cardioDurationMinutes: Int? = nil
    ) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        entries[index] = TrainingEntry(
            id: entry.id,
            exerciseID: entry.exerciseID,
            exerciseName: entry.exerciseName,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            cardioDurationMinutes: cardioDurationMinutes
        )
        entries.sort { $0.date > $1.date }
        save()
    }

    func delete(_ entry: TrainingEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func moveEntries(
        on date: Date,
        fromOffsets: IndexSet,
        toOffset: Int
    ) {
        let calendar = Calendar.current
        var sessionEntries = entries.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        sessionEntries.move(fromOffsets: fromOffsets, toOffset: toOffset)

        let orderingBase = calendar.startOfDay(for: date).addingTimeInterval(12 * 60 * 60)
        let reorderedDates = Dictionary(uniqueKeysWithValues: sessionEntries.enumerated().map {
            index, entry in
            (entry.id, orderingBase.addingTimeInterval(Double(sessionEntries.count - index)))
        })

        entries = entries.map { entry in
            guard let reorderedDate = reorderedDates[entry.id] else {
                return entry
            }

            return TrainingEntry(
                id: entry.id,
                exerciseID: entry.exerciseID,
                exerciseName: entry.exerciseName,
                date: reorderedDate,
                notes: entry.notes,
                cardioDurationMinutes: entry.cardioDurationMinutes
            )
        }
        entries.sort { $0.date > $1.date }
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
                notes: entry.notes,
                cardioDurationMinutes: entry.cardioDurationMinutes
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
                notes: entry.notes,
                cardioDurationMinutes: entry.cardioDurationMinutes
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

    func backupPhotos() throws -> [FitSBackupPhoto] {
        try photos.map { photo in
            do {
                return FitSBackupPhoto(
                    id: photo.id,
                    date: photo.date,
                    fileName: photo.fileName,
                    data: try Data(contentsOf: url(for: photo), options: .mappedIfSafe)
                )
            } catch {
                throw FitSBackupError.photoUnavailable(photo.fileName)
            }
        }
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

    func restore(from backup: FitSBackup) throws {
        let entryIDs = backup.trainingEntries.map(\.id)
        guard Set(entryIDs).count == entryIDs.count else {
            throw FitSBackupError.invalidContents
        }

        if backup.includesPhotos {
            try restorePhotos(from: backup.trainingPhotos)
        }

        entries = backup.trainingEntries.sorted { $0.date > $1.date }
        save()
    }

    private func restorePhotos(from backupPhotos: [FitSBackupPhoto]) throws {
        let photoIDs = backupPhotos.map(\.id)
        let fileNames = backupPhotos.map(\.fileName)
        guard Set(photoIDs).count == photoIDs.count,
              Set(fileNames).count == fileNames.count,
              backupPhotos.allSatisfy({ photo in
                  photo.fileName == URL(fileURLWithPath: photo.fileName).lastPathComponent
                      && !photo.fileName.isEmpty
                      && !photo.data.isEmpty
                      && CGImageSourceCreateWithData(photo.data as CFData, nil) != nil
              }) else {
            throw FitSBackupError.invalidContents
        }

        let fileManager = FileManager.default
        let parentDirectory = photosDirectory.deletingLastPathComponent()
        let stagingDirectory = parentDirectory.appending(
            path: "TrainingPhotos-Restore-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let rollbackDirectory = parentDirectory.appending(
            path: "TrainingPhotos-Rollback-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )

        do {
            try fileManager.createDirectory(
                at: stagingDirectory,
                withIntermediateDirectories: true
            )
            for photo in backupPhotos {
                try photo.data.write(
                    to: stagingDirectory.appending(path: photo.fileName),
                    options: .atomic
                )
            }

            let hadExistingPhotos = fileManager.fileExists(atPath: photosDirectory.path)
            if hadExistingPhotos {
                try fileManager.moveItem(at: photosDirectory, to: rollbackDirectory)
            }

            do {
                try fileManager.moveItem(at: stagingDirectory, to: photosDirectory)
            } catch {
                if hadExistingPhotos {
                    try? fileManager.moveItem(at: rollbackDirectory, to: photosDirectory)
                }
                throw error
            }

            if hadExistingPhotos {
                try? fileManager.removeItem(at: rollbackDirectory)
            }
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }

        photos = backupPhotos
            .map { TrainingPhoto(id: $0.id, date: $0.date, fileName: $0.fileName) }
            .sorted { $0.date > $1.date }
        savePhotos()
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

struct FitSBackupPhoto: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let fileName: String
    let data: Data
}

struct FitSBackup: Codable {
    static let currentVersion = 2
    static let maximumFileSize = 250 * 1_024 * 1_024

    let version: Int
    let exportedAt: Date
    let favoriteExerciseIDs: [String]
    let trainingEntries: [TrainingEntry]
    let trainingPhotos: [FitSBackupPhoto]

    var includesPhotos: Bool {
        version >= 2
    }

    init(
        favoriteExerciseIDs: [String],
        trainingEntries: [TrainingEntry],
        trainingPhotos: [FitSBackupPhoto]
    ) {
        version = Self.currentVersion
        exportedAt = .now
        self.favoriteExerciseIDs = favoriteExerciseIDs
        self.trainingEntries = trainingEntries
        self.trainingPhotos = trainingPhotos
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case exportedAt
        case favoriteExerciseIDs
        case trainingEntries
        case trainingPhotos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard (1...Self.currentVersion).contains(version) else {
            throw FitSBackupError.unsupportedVersion
        }
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        favoriteExerciseIDs = try container.decode([String].self, forKey: .favoriteExerciseIDs)
        trainingEntries = try container.decode([TrainingEntry].self, forKey: .trainingEntries)
        if version >= 2 {
            trainingPhotos = try container.decode(
                [FitSBackupPhoto].self,
                forKey: .trainingPhotos
            )
        } else {
            trainingPhotos = []
        }
    }

    func encoded() throws -> Data {
        let data = try JSONEncoder().encode(self)
        guard data.count <= Self.maximumFileSize else {
            throw FitSBackupError.fileTooLarge
        }
        return data
    }

    static func decode(from data: Data) throws -> FitSBackup {
        guard data.count <= maximumFileSize else {
            throw FitSBackupError.fileTooLarge
        }

        let backup = try JSONDecoder().decode(FitSBackup.self, from: data)
        guard (1...currentVersion).contains(backup.version) else {
            throw FitSBackupError.unsupportedVersion
        }
        return backup
    }
}

enum FitSBackupError: LocalizedError {
    case fileTooLarge
    case invalidContents
    case photoUnavailable(String)
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            L10n.string("备份文件过大。")
        case .invalidContents:
            L10n.string("备份文件内容无效或已损坏。")
        case .photoUnavailable(let fileName):
            L10n.format("无法读取训练图片 %@，备份未导出。", fileName)
        case .unsupportedVersion:
            L10n.string("此备份来自不受支持的 FitS 版本。")
        }
    }
}

private enum DatasetError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        L10n.string("找不到内置的动作数据库。")
    }
}
