//
//  SensorDetailView.swift
//  My Weather Sensors
//
//  Created by Chris Riddick on 7/9/25.
//

import SwiftUI
import SwiftData

struct SensorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var sensor: Sensor

    @State private var sensorName: String
    @State private var location: String
    @State private var descriptionText: String
    
    @State private var showingPopover = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: Error?
    @State private var saveError: Error?

    init(sensor: Sensor) {
        self._sensor = Bindable(wrappedValue: sensor)
        _sensorName = State(initialValue: sensor.sensorName)
        _location = State(initialValue: sensor.location)
        _descriptionText = State(initialValue: sensor.descriptionText)
    }
    
    let lightGreen = Color(hue: 0.4, saturation: 0.1, brightness: 0.8)
    let moonGray = Color(white: 0.9, opacity: 0.7)
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(" ").padding(.leading, 5)
            Text("Station: " + sensor.station).padding(.leading, 5)
            Text("Id: " + String(sensor.sensorId)).padding(.leading, 5)
            Text("Channel: " + sensor.channel).padding(.leading, 5)
            Text("Model: " + sensor.model)
                .padding(.leading, 5)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(1...2)
                .multilineTextAlignment(.leading)
            Text("Updated: " + sensor.timeText).padding(.leading, 5)
            Text(" ").padding(.leading, 5)
        }
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.gray)
        .frame(maxWidth: .infinity, alignment: .leading)

        Spacer()

        Text("The following properties are editable.\n")
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(.red)

        Form {
            HStack {
                Text("Sensor Name:")
                    .fontWeight(.bold)

                TextField("New Name", text: $sensor.sensorName, axis: .vertical)
                    .lineLimit(2)
            }

            HStack {
                Text("Location:")
                    .fontWeight(.bold)

                TextField("New Location", text: $sensor.location, axis: .vertical)
                    .lineLimit(2)
            }

            HStack {
                Text("Description:")
                    .fontWeight(.bold)

                TextField(
                    "New Description",
                    text: $sensor.descriptionText,
                    axis: .vertical
                )
                .lineLimit(5)
            }

            Toggle(isOn: $sensor.active) {
                Text("Sensor active:")
                    .fontWeight(.bold)
            }
            .toggleStyle(.switch)

            Button {
                do {
                    try sensor.setAsGlobalHome(in: modelContext)
                    try modelContext.save()
                    showingPopover = true
                } catch {
                    print(error)
                }
            } label: {
                Text("Add Sensor to Home Screen")
            }
            .buttonStyle(GreenButton())
            .frame(maxWidth: .infinity)
            .popover(isPresented: $showingPopover) {
                VStack {
                    Text("\(sensor.sensorName) added to home screen")
                        .font(.system(size: 18, weight: .heavy))

                    Button("Dismiss") {
                        showingPopover = false
                    }
                    .buttonStyle(BlueButton())
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }

            // Delete button
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Sensor", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Sensor Info")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        await saveSensor()

                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            saveError = error
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this sensor?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Sensor", role: .destructive) {
                deleteSensor()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes the sensor from the local store.")
        }
        .alert(
            "Unable to Delete Sensor",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError?.localizedDescription ?? "An unknown error occurred.")
        }
    }

    private func deleteSensor() {
        do {
            modelContext.delete(sensor)
            try modelContext.save()
            // Dismiss only after the deletion has been persisted.
            dismiss()
        } catch {
            deleteError = error
        }
    }
    
    // This function writes local stat to the Hub (station)
    @MainActor
    private func saveSensor() async {
        let sensorPatch = SensorPatchDTO(
            ID: sensor.id,
            SENSORNAME: sensor.sensorName,
            LOCATION: sensor.location,
            DESCRIPTION: sensor.descriptionText,
            ACTIVE: sensor.active ? 1 : 0
        )

        do {
            let patchData = try JSONEncoder().encode(sensorPatch)

            guard !sensor.hubs.isEmpty else {
                print("Sensor has no associated hubs")
                return
            }

            for hub in sensor.hubs {
                guard let baseURL = URL(string: hub.urlString) else {
                    print("Invalid hub URL: \(hub.urlString)")
                    continue
                }

                let patchURL = baseURL.appendingPathComponent("sensor/full")

                var request = URLRequest(url: patchURL)
                request.httpMethod = "PATCH"
                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Content-Type"
                )
                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Accept"
                )
                request.httpBody = patchData

                let (data, response) = try await URLSession.shared.data(
                    for: request
                )

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response from \(hub.urlString)")
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    print(
                        "PATCH failed for \(hub.urlString): " +
                        "\(httpResponse.statusCode)"
                    )
                    print(String(data: data, encoding: .utf8) ?? "")
                    continue
                }

            }
        } catch {
            print("Error during PATCH request: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SensorDetailView(sensor: Sensor(id: 2, station: "station", active: true, battery: -1, channel: " ", descriptionText: "test-temp only in Study", humidity: nil, location: "study", model: "LaCrosse-TX", sensorId: 15, sensorName: "Study",  temperature: 75.56, timeText: "2024-01-01 11:00:00", ))
}
