import SwiftUI

@main
struct ExerciseFinderApp: App {
    @StateObject private var store = ExerciseStore()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var training = TrainingStore()
    @State private var selectedBodyPart = "全部部位"
    @State private var selectedEquipment = "全部器械"
    @State private var favoriteBodyPart = "全部部位"
    @State private var favoriteEquipment = "全部器械"

    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 18.0, *) {
                    TabView {
                        Tab("动作", systemImage: "figure.strengthtraining.traditional") {
                            exerciseList(
                                searchEnabled: false,
                                favoritesOnly: false,
                                bodyPart: $selectedBodyPart,
                                equipment: $selectedEquipment
                            )
                        }

                        Tab("收藏", systemImage: "heart") {
                            exerciseList(
                                searchEnabled: false,
                                favoritesOnly: true,
                                bodyPart: $favoriteBodyPart,
                                equipment: $favoriteEquipment
                            )
                        }

                        Tab("训练", systemImage: "calendar") {
                            TrainingView()
                        }

                        Tab(role: .search) {
                            exerciseList(
                                searchEnabled: true,
                                favoritesOnly: false,
                                bodyPart: $selectedBodyPart,
                                equipment: $selectedEquipment
                            )
                        }
                    }
                } else {
                    TabView {
                        exerciseList(
                            searchEnabled: true,
                            favoritesOnly: false,
                            bodyPart: $selectedBodyPart,
                            equipment: $selectedEquipment
                        )
                            .tabItem {
                                Label("动作", systemImage: "figure.strengthtraining.traditional")
                            }

                        exerciseList(
                            searchEnabled: true,
                            favoritesOnly: true,
                            bodyPart: $favoriteBodyPart,
                            equipment: $favoriteEquipment
                        )
                            .tabItem {
                                Label("收藏", systemImage: "heart")
                            }

                        TrainingView()
                            .tabItem {
                                Label("训练", systemImage: "calendar")
                            }
                    }
                }
            }
            .environmentObject(store)
            .environmentObject(favorites)
            .environmentObject(training)
        }
    }

    private func exerciseList(
        searchEnabled: Bool,
        favoritesOnly: Bool,
        bodyPart: Binding<String>,
        equipment: Binding<String>
    ) -> some View {
        ExerciseListView(
            searchEnabled: searchEnabled,
            selectedBodyPart: bodyPart,
            selectedEquipment: equipment,
            showsFavoritesOnly: favoritesOnly
        )
    }
}
