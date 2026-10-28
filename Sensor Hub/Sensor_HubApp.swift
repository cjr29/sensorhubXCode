import SwiftUI
import SwiftData

enum LoadPhase: Equatable {
    case loading
    case ready
    case hubNotFound
}

@main
struct SensorsApp: App {
    private let container: ModelContainer = {
        let fm = FileManager.default
        let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        // Ensure directory exists
        try? fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        let storeURL = appSupportDir.appendingPathComponent("SwiftData.sqlite")

        if ProcessInfo.processInfo.arguments.contains("-ResetSwiftData") {
            try? fm.removeItem(at: storeURL)
            try? fm.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? fm.removeItem(at: storeURL.appendingPathExtension("shm"))
        }

        let config = ModelConfiguration(url: storeURL)
        return try! ModelContainer(for: Sensor.self, Hub.self, configurations: config)
    }()

    var body: some Scene {
        WindowGroup {
            RootGateView(container: container)
                .modelContainer(container)
        }
    }
}

@MainActor
struct RootGateView: View {
    let container: ModelContainer
    @State private var phase: LoadPhase = .loading
    @State private var hubs: [Hub] = []

    private let sensorService = SensorService()

    var body: some View {
        Group {
            switch phase {
            case .ready: ContentView()
            case .loading:
                ProgressView("     Finding Sensor Hubs.\nThis may take up to a minute...")
                    .task { await seedOrFail() }
            case .hubNotFound: ContentView()
            }
        }
        .sheet(isPresented: Binding(
            get: { phase == .hubNotFound },
            set: { if !$0 { phase = .ready } }
        )) {
            HubNotFoundModal { phase = .ready }
        }
    }

    private func seedOrFail() async {
        let context = ModelContext(container)  // <-- local

        let sensorRepo = SensorRepository(context: context)

        do {
            let existingCount = try context.fetchCount(FetchDescriptor<Hub>())
            guard existingCount == 0 else {
                phase = .ready
                return
            }
            _ = await refreshHubsBonjour(container: container, timeout: 10)

            let hubs = try context.fetch(FetchDescriptor<Hub>())
            let results = await sensorService.fetchAllSensors(
                hubs: hubs
            )
            try sensorRepo.upsert(
                results,
                forHubs: hubs
            )

            phase = .ready
        } catch {
            phase = .hubNotFound
        }
    }
}

func getAppBuildNumber() -> String? {
    // Access the main bundle's info dictionary
    guard let infoDictionary = Bundle.main.infoDictionary else {
        return nil
    }
    // Retrieve the value associated with the "CFBundleVersion" key
    guard let buildNumber = infoDictionary["CFBundleVersion"] as? String else {
        return nil
    }
    // Add to user settings
    UserDefaults.standard.set(buildNumber, forKey: "AppBuildNumber")
    return buildNumber
}
