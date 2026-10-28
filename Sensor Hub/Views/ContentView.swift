//
//  ContentView.swift
//  My Weather Sensors
//
//  Created by Chris Riddick on 7/9/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hub.station) private var hubs: [Hub]
    @State private var showVerifyAlert = false
    @State private var isPinging = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private let service = SensorService()
    
    @State private var selectedTab: AppTab = .home
    @State private var showAboutView = false
    @State private var showHelpView = false
    
    @State private var isPresentingAddForm = false
    @State private var addErrorMessage: String?
    @State private var isShowingConnectionFailure = false
    @State private var isShowingConnectionSuccess = false
    @State private var connectionFailureMessage = ""
    @State private var connectionSuccessMessage = ""

    @State private var isPresentingHubSetupChoice = false
    @State private var isConfiguringNewHub = false
    @State private var configureNewHubErrorMessage: String?
    @State private var configureNewHubStepText = ""

    @State private var isDiscovering = false
    @State private var discoverErrorMessage: String?
    @State private var didDiscoverCount = 0
    @State private var discoveredTotal = 0
    @State private var discoveredProcessed = 0

    @State private var isShowingWiFiCredentials = false
    @State private var wifiCredentialsContinuation:
        CheckedContinuation<WiFiCredentials?, Never>?

    @State private var selectedSSID = ""
    @State private var selectedPassword = ""
    
    enum OverlayMode { case configuringNewHub, discoveringHubs, none }
    @State private var overlayMode: OverlayMode = .none

    private let sensorService = SensorService()

    enum AppTab: Hashable {
        case home
        case sensors
        case inactive
        case hubs
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(AppTab.home)

                SensorListView()
                    .tabItem {
                        Label("Sensors", systemImage: "thermometer.variable")
                    }
                    .tag(AppTab.sensors)

                SensorConfigurationView()
                    .tabItem {
                        Label("Inactive", systemImage: "gear")
                    }
                    .tag(AppTab.inactive)

                HubListView(
                    isDiscovering: $isDiscovering,
                    discoverErrorMessage: $discoverErrorMessage,
                    didDiscoverCount: $didDiscoverCount,
                    discoveredTotal: $discoveredTotal,
                    discoveredProcessed: $discoveredProcessed,
                    isConfiguringNewHub: $isConfiguringNewHub,
                    configureNewHubErrorMessage: $configureNewHubErrorMessage,
                    configureNewHubStepText: $configureNewHubStepText
                )
                    .tabItem {
                        Label("Hubs", systemImage: "externaldrive")
                    }
                    .tag(AppTab.hubs)
            }
            .navigationTitle(titleForSelectedTab)
            .toolbar {
                sharedToolbar
            }
        }
        .sheet(isPresented: $showHelpView) {
            HelpView()
        }
        .sheet(isPresented: $showAboutView) {
            AboutView()
        }
        .fullScreenCover(isPresented: $isPresentingHubSetupChoice) {
            HubSetupChoiceView(
                onManualAdd: {
                    isPresentingHubSetupChoice = false

                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        isPresentingAddForm = true
                    }
                },
                onConfigureNewHub: {
                    isPresentingHubSetupChoice = false

                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))

                        isConfiguringNewHub = true
                        configureNewHubErrorMessage = nil
                        configureNewHubStepText = "Configure new hub…"

                        await configureNewHubFlow()
                    }
                },
                isConfiguring: isConfiguringNewHub
            )
        }
        .sheet(isPresented: $isPresentingAddForm) {
            addHubForm
        }
        .sheet(isPresented: $isPresentingAddForm) {
            AddHubFormView { station, urlString, name in
                // Move the existing add-hub save logic here,
                // or call a shared model.
                return nil
            } onDismissSuccess: {
                isPresentingAddForm = false
            }
        }
        .sheet(
            isPresented: $isShowingWiFiCredentials,
            onDismiss: {
                finishWiFiCredentialsRequest(with: nil)
                isShowingWiFiCredentials = false
            }
        ) {
            WiFiCredentialsView { credentials in
                finishWiFiCredentialsRequest(with: credentials)
            }
        }
        .alert(
            "Connection successful",
            isPresented: $isShowingConnectionSuccess
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectionSuccessMessage)
        }
        .alert(
            "Connection failed",
            isPresented: $isShowingConnectionFailure
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectionFailureMessage)
        }
        .overlay{ refreshOverlay }
    }

    private var titleForSelectedTab: String {
        switch selectedTab {
        case .home:
            "Weather Sensors"
        case .sensors:
            "Active Sensors"
        case .inactive:
            "Configure New Sensors"
        case .hubs:
            "Active Hubs"
        }
    }
    
    @ToolbarContentBuilder
    private var sharedToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("About") {
                    showAboutView = true
                }

                Button("Help") {
                    showHelpView = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
            }
        }

        if selectedTab == .hubs {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingHubSetupChoice = true
                } label: {
                    Label("Add Hub", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startDiscovery()
                } label: {
                    Label(
                        isDiscovering
                            ? "Finding Sensor Hubs"
                            : "Find Sensor Hubs",
                        systemImage: "magnifyingglass"
                    )
                }
                .disabled(isDiscovering)
            }
        }

        if selectedTab == .sensors {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { @MainActor in
                        await refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
    }

    @MainActor
    private func startDiscovery() {
        Task { @MainActor in
            isDiscovering = true
            discoverErrorMessage = nil
            didDiscoverCount = 0
            discoveredTotal = 0
            discoveredProcessed = 0

            defer {
                isDiscovering = false
            }

            do {
                _ = await refreshHubsBonjour(
                    container: modelContext.container,
                    timeout: 10
                )

                let sensorRepo = SensorRepository(
                    context: modelContext
                )

                let sensorsDTO = await sensorService.fetchAllSensors(
                    hubs: hubs
                )

                try sensorRepo.upsert(
                    sensorsDTO,
                    forHubs: hubs
                )
            } catch is CancellationError {
                // Ignore cancellation.
            } catch {
                discoverErrorMessage = error.localizedDescription
                print("Failed to discover sensors: \(error)")
            }
        }
    }
    
    @MainActor
    private func refresh() async {
        let repo = SensorRepository(context: modelContext)
        isRefreshing = true
        defer { isRefreshing = false }

        // First remove expired and orphaned Sensor records from persistent repository
        do {
            let removed = try repo.removeExpiredSensors()
            print("Removed \(removed) expired sensor records")
        } catch {
            print("Failed to remove expired sensors: \(error)")
        }

        do {
            print("Hubs in view:", hubs.count)

            let hubs = try modelContext.fetch(FetchDescriptor<Hub>())
            let results = await service.fetchAllSensors(
                hubs: hubs
            )
            try repo.upsert(
                results,
                forHubs: hubs
            )

            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    

    @ViewBuilder
    fileprivate var refreshOverlay: some View {
        if isRefreshing {
                ProgressView()
        }
    }
    
    @ViewBuilder
    private var addHubForm: some View {
        AddHubFormView { station, urlString, name in
            do {
                let url = try HubViewModel.validatedURL(
                    from: urlString
                )

                let newHub = Hub(
                    station: station,
                    urlString: url.absoluteString,
                    name: name
                )

                modelContext.insert(newHub)
                try modelContext.save()

                return nil
            } catch {
                return error.localizedDescription
            }
        } onDismissSuccess: {
            isPresentingAddForm = false
        }
    }
    
    @MainActor
    private func configureNewHubFlow() async {
        defer {
            isConfiguringNewHub = false
            configureNewHubStepText = ""
            overlayMode = .none
        }

        do {
            configureNewHubStepText =
                "Sensor hub needs to connect to Wi-Fi\nEnter SSID and password"

            guard let credentials = await requestWiFiCredentials() else {
                configureNewHubStepText =
                    "Wi-Fi network selected: \(selectedSSID)"
                return
            }

            selectedSSID = credentials.ssid
            selectedPassword = credentials.password

            configureNewHubStepText = "Connecting to SensorHub…"

            let ipAddress = try await connectAndFetchHotspotIPv4(
                ssid: "SensorHub",
                passphrase: "ConfigureMe123"
            )

            guard !ipAddress.isEmpty else {
                connectionFailureMessage =
                    "Unable to connect to the SensorHub hotspot. Please ensure the hub is nearby and try again."

                isShowingConnectionFailure = true
                return
            }

            connectionSuccessMessage = "Connected to SensorHub."
            isShowingConnectionSuccess = true

            try await Task.sleep(for: .seconds(3))

            // Tell Hub to change to the selected SSID
            do {
                try await SensorHubClient().tellHubToConnectToWiFi(
                    host: ipAddress,
                    ssid: selectedSSID,
                    password: selectedPassword
                )
                print("Sensor Hub connected to WiFi \(selectedSSID)")
            } catch {
                print("Request failed:", error.localizedDescription)
            }

            try await Task.sleep(for: .seconds(3))
            configureNewHubStepText =
                "SensorHub IP: \(ipAddress)\nSensorHub WiFi configured…"

            await disconnectFromHotspot(ssid: "SensorHub")
            try await Task.sleep(for: .seconds(5))

            configureNewHubStepText = "Disconnected from SensorHub."
            try await Task.sleep(for: .seconds(5))

            configureNewHubStepText = "Saving configuration on New Hub…"
            _ = await refreshHubsBonjour(
                container: modelContext.container,
                timeout: 10
            )

            try await Task.sleep(for: .seconds(5))

            // Save your SwiftData changes here.

        } catch is CancellationError {
            // The task was cancelled; no error UI is necessary.
        } catch {
            configureNewHubErrorMessage = error.localizedDescription
        }
    }

    private func deleteHubs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(hubs[index])
        }
        do { try modelContext.save() } catch {}
    }

    @MainActor
    private func requestWiFiCredentials() async -> WiFiCredentials? {
        await withCheckedContinuation { continuation in
            wifiCredentialsContinuation = continuation
            isShowingWiFiCredentials = true
        }
    }

    @MainActor
    private func finishWiFiCredentialsRequest(
        with credentials: WiFiCredentials?
    ) {
        guard let continuation = wifiCredentialsContinuation else {
            return
        }

        // Clear it before resuming so the sheet's onDismiss does not resume it again.
        wifiCredentialsContinuation = nil
        continuation.resume(returning: credentials)
    }


}

#Preview {
    ContentView()
}
