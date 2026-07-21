import SwiftUI

@main
struct ExerciseFinderApp: App {
    @StateObject private var store = ExerciseStore()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var training = TrainingStore()
    @StateObject private var language = LanguageStore()
    @State private var selectedBodyPart = "全部部位"
    @State private var selectedEquipment = "全部器械"
    @State private var favoriteBodyPart = "全部部位"
    @State private var favoriteEquipment = "全部器械"
    @State private var selectedTab = AppTab.favorites
    @State private var lastNonSearchTab = AppTab.favorites

    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 18.0, *) {
                    TabView(selection: $selectedTab) {
                        Tab(
                            "动作",
                            systemImage: "figure.strengthtraining.traditional",
                            value: AppTab.exercises
                        ) {
                            exerciseList(
                                searchEnabled: false,
                                favoritesOnly: false,
                                bodyPart: $selectedBodyPart,
                                equipment: $selectedEquipment
                            )
                        }

                        Tab("收藏", systemImage: "heart", value: AppTab.favorites) {
                            exerciseList(
                                searchEnabled: false,
                                favoritesOnly: true,
                                bodyPart: $favoriteBodyPart,
                                equipment: $favoriteEquipment
                            )
                        }

                        Tab("训练", systemImage: "calendar", value: AppTab.training) {
                            TrainingView()
                        }

                        Tab(value: AppTab.search, role: .search) {
                            exerciseList(
                                searchEnabled: true,
                                automaticallyFocusSearch: selectedTab == .search,
                                onSearchDismiss: {
                                    selectedTab = lastNonSearchTab
                                },
                                favoritesOnly: false,
                                bodyPart: $selectedBodyPart,
                                equipment: $selectedEquipment
                            )
                        }
                    }
                    .onChange(of: selectedTab) { _, tab in
                        if tab != .search {
                            lastNonSearchTab = tab
                        }
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        exerciseList(
                            searchEnabled: true,
                            favoritesOnly: false,
                            bodyPart: $selectedBodyPart,
                            equipment: $selectedEquipment
                        )
                            .tabItem {
                                Label("动作", systemImage: "figure.strengthtraining.traditional")
                            }
                            .tag(AppTab.exercises)

                        exerciseList(
                            searchEnabled: true,
                            favoritesOnly: true,
                            bodyPart: $favoriteBodyPart,
                            equipment: $favoriteEquipment
                        )
                            .tabItem {
                                Label("收藏", systemImage: "heart")
                            }
                            .tag(AppTab.favorites)

                        TrainingView()
                            .tabItem {
                                Label("训练", systemImage: "calendar")
                            }
                            .tag(AppTab.training)
                    }
                }
            }
            .environmentObject(store)
            .environmentObject(favorites)
            .environmentObject(training)
            .environmentObject(language)
            .environment(\.locale, language.language.locale)
            .id(language.language.rawValue)
        }
    }

    private func exerciseList(
        searchEnabled: Bool,
        automaticallyFocusSearch: Bool = false,
        onSearchDismiss: @escaping () -> Void = {},
        favoritesOnly: Bool,
        bodyPart: Binding<String>,
        equipment: Binding<String>
    ) -> some View {
        ExerciseListView(
            searchEnabled: searchEnabled,
            automaticallyFocusSearch: automaticallyFocusSearch,
            onSearchDismiss: onSearchDismiss,
            selectedBodyPart: bodyPart,
            selectedEquipment: equipment,
            showsFavoritesOnly: favoritesOnly
        )
    }
}

private enum AppTab: Hashable {
    case exercises
    case favorites
    case training
    case search
}
