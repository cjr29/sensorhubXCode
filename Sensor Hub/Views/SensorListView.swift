//
//  NewSensorListView.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 7/26/26.
//

import Foundation
import SwiftUI
import SwiftData

struct SensorListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Sensor.sensorId) private var sensors: [Sensor]
    @Query(sort: \Hub.name) private var hubs: [Hub]

    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var selectedStation: String = "" // must be Hub.station

    private let service = SensorService()

    private var uniqueStations: [Hub] {
        var seenStations = Set<String>()
        var result: [Hub] = []

        // `hubs` is already sorted by urlString, so the first Hub
        // for a station supplies the displayed name.
        for hub in hubs {
            if seenStations.insert(hub.station).inserted {
                result.append(hub)
            }
        }

        return result
    }

    private var filteredSensors: [Sensor] {
        guard !selectedStation.isEmpty else {
            return sensors.filter(\.active)
        }

        return sensors.filter { sensor in
            sensor.active &&
            sensor.hubs.contains { hub in
                hub.station == selectedStation
            }
        }
    }
    
    let lime = Color(hue: 0.2, saturation: 0.1, brightness: 0.9)
    let moonGray = Color(white: 0.9, opacity: 0.7)
    
    var body: some View {
        VStack {
            Text("\(filteredSensors.count) sensors")
                .foregroundStyle(.blue)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(hubs, id: \.urlString) { hub in
                        let isSelected = selectedStation == hub.station

                        Button {
                            selectedStation = hub.station
                        } label: {
                            Text(hub.name)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(isSelected ? .white : .blue)
                                .background(
                                    isSelected ? Color.blue : Color.clear,
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule().stroke(Color.blue, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 44)
            .background(moonGray)
            .onAppear {
                if selectedStation.isEmpty {
                    selectedStation = uniqueStations.first?.station ?? ""
                }
                Task {
                    await refresh()
                }
            }
            .onChange(of: selectedStation) {
                Task { await refresh() }
            }
            .onChange(of: hubs) {
                let stations = Set(uniqueStations.map(\.station))
                if !stations.contains(selectedStation) {
                    selectedStation = uniqueStations.first?.station ?? ""
                }
            }
            .pickerStyle(.segmented)
            .tint(.blue)
            .frame(height:35)
            .background(
                RoundedRectangle(cornerRadius: 0, style: .continuous).fill(moonGray)
                    .stroke(moonGray, lineWidth: 0))
            
            NavigationStack {
                List {
                    ForEach(filteredSensors, id: \.self) { sensor in
                        NavigationLink(value: sensor) {
                            SensorRowView(item: sensor)
                                .frame(width: 400)
                        }
                        // alternating row colors
                        .listRowBackground(
                            (filteredSensors.firstIndex(where: { $0.id == sensor.id }) ?? 0) % 2 == 0 ? lime : moonGray)
                    }
                }
                .navigationDestination(for: Sensor.self) { sensor in
                    SensorDetailView(sensor:sensor)
                }
                .task {
                    Task { await refresh() }
                }
                .refreshable {
                    Task { await refresh() }
                }
                .onAppear {
                    Task { await refresh() }
                }
            } // NavigationStack
        } // VStack
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

#Preview {
    SensorListView()
}
