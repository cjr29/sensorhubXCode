//
//  HubEditView.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 7/24/26.
//

import SwiftUI
import SwiftData

struct HubEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var hub: Hub

    @State private var station: String
    @State private var name: String
    @State private var urlString: String

    @State private var errorMessage: String?

    init(hub: Hub) {
        self._hub = Bindable(wrappedValue: hub)
        _name = State(initialValue: hub.name)  // local name of hub
        _station = State(initialValue: hub.station)  // sensorhubxxxxxxxxxxxx
        _urlString = State(initialValue: hub.urlString)  // URL for hub http://sensorhubxxxxxxxxxxxx.local:5000
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Local Name", text: $name)
                TextField("Hub Name", text: $station)
                TextField("URL", text: $urlString)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Edit Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        do {
                            hub.name = name
                            hub.station = station
                            hub.urlString = urlString

                            try modelContext.save()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}
