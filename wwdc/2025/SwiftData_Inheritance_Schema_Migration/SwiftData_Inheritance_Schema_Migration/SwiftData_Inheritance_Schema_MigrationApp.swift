import SwiftUI
import SwiftData

@main
struct SwiftData_Inheritance_Schema_MigrationApp: App {
    var sharedModelContainer: ModelContainer = {
            let schema = Schema([
                Trip.self,
                PersonalTrip.self,
                BusinessTrip.self
            ])
            
            // Sử dụng Schema Migration Plan
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            
            do {
                // Khởi tạo container với migration plan
                return try ModelContainer(
                    for: schema,
                    migrationPlan: TripsMigrationPlan.self,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Không thể khởi tạo ModelContainer: \(error)")
            }
        }()

        var body: some Scene {
            WindowGroup {
                ContentView()
            }
            .modelContainer(sharedModelContainer)
        }
}
