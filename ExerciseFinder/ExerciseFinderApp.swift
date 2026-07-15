import SwiftUI

@main
struct ExerciseFinderApp: App {
    @StateObject private var store = ExerciseStore()
    @StateObject private var favorites = FavoritesStore()
    @State private var selectedBodyPart = "全部部位"
    @State private var selectedEquipment = "全部器械"
    @State private var showsFavoritesOnly = false

    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 18.0, *) {
                    TabView {
                        Tab("动作", systemImage: "figure.strengthtraining.traditional") {
                            exerciseList(searchEnabled: false)
                        }

                        Tab(role: .search) {
                            exerciseList(searchEnabled: true)
                        }
                    }
                } else {
                    exerciseList(searchEnabled: true)
                }
            }
            .environmentObject(store)
            .environmentObject(favorites)
        }
    }

    private func exerciseList(searchEnabled: Bool) -> some View {
        ExerciseListView(
            searchEnabled: searchEnabled,
            selectedBodyPart: $selectedBodyPart,
            selectedEquipment: $selectedEquipment,
            showsFavoritesOnly: $showsFavoritesOnly
        )
    }
}
