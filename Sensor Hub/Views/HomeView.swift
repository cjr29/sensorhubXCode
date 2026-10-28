import SwiftData
//
//  HomeView.swift
//  My Weather Sensors
//
//  Created by Chris Riddick on 6/17/25.
//
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hub.station) private var hubs: [Hub]

    @State private var homeSensor: Sensor?
    @State private var buildNumber: String = ""
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private let service = SensorService()

    var body: some View {
        VStack {
            Image(information.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(10)
                .padding(40)
                .onTapGesture { Task { await refresh() } }
                .overlay {
                    if let home = homeSensor, home.isHome == true {
                        VStack {
                            Text(home.sensorName)
                                .font(.system(size: 48, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.white.opacity(0.0))
                            HStack {
                                Text(
                                    "\(home.temperature ?? -999.9, format: .number.precision(.fractionLength(1)))"
                                )
                                .font(.system(size: 48, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.white.opacity(0.0))
                                Image(systemName: "degreesign.fahrenheit")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.white.opacity(0.0))
                                    .cornerRadius(5)
                            }

                            HStack {
                                Text(
                                    home.humidity ?? 0,
                                    format: .number.precision(.fractionLength(1))
                                )
                                .font(.system(size: 48, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(5)
                                .opacity(home.humidity == nil ? 0 : 1)
                                Image(systemName: "humidity")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.white.opacity(0.0))
                                    .cornerRadius(5)
                                    .opacity(home.humidity == nil ? 0 : 1)
                            }

                            Text(home.timeText)
                                .font(.system(size: 24, weight: .medium).italic())
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.white.opacity(0.0))
                        }
                    } else {
                        VStack {
                            Text(" ")
                                .foregroundColor(.clear)
                        }
                    }
                }

            Text(information.name)
                .font(.caption)
                .padding()

            Text("Development Build # \(buildNumber)")
                .font(.caption)
        }
        .task {
            if let build = getAppBuildNumber() {
                buildNumber = build
            } else {
                print("Could not retrieve app build number.")
            }
            await refresh()
        }
        .onAppear { Task { await refresh() } }
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let repo = SensorRepository(context: modelContext)
        do {
            let results = await service.fetchAllSensors(
                hubs: hubs
            )
            try repo.upsert(
                results,
                forHubs: hubs
            )

            try await MainActor.run {
                let descriptor = FetchDescriptor<Sensor>(
                    predicate: #Predicate { $0.isHome == true }
                )
                homeSensor = try modelContext.fetch(descriptor).first
            }
        } catch {
            errorMessage = error.localizedDescription
            homeSensor = nil
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
