//
//  AddHubFormView.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 8/17/26.
//

import Foundation
import SwiftUI
import SwiftData

struct AddHubFormView: View {
    /// Return nil on success, or an error message on failure
    let onAdd: (_ station: String, _ url: String, _ name: String) -> String?
    let onDismissSuccess: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Sensor.sensorName) private var sensors: [Sensor]
    @Query(sort: \Hub.station) private var hubs: [Hub]
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var station: String = ""
    @State private var urlError: String?
    @State private var submitError: String?
    @State private var errorMessage: String?

    @State private var isDiscovering = false
    @State private var discoverErrorMessage: String?
    @State private var didDiscoverCount: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {

                    TextField("Local Hub Name", text: $name)

                    TextField("Host Name", text: $station, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: url) { _, newValue in
                            validateURL(newValue)
                        }

                    if let urlError {
                        Text(urlError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    if let submitError {
                        Text(submitError)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New Hub")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        submitError = nil
                        let err = onAdd(station, url, name)
                        if let err {
                            submitError = err
                            return
                        }
                        dismiss()
                        onDismissSuccess()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                // Helps ensure canSave matches the current URL immediately
                validateURL(url)
            }
        }
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedURL.isEmpty && urlError == nil
    }

    private func validateURL(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            urlError =
                HubViewModel.URLValidationError.empty.localizedDescription
            return
        }

        do {
            _ = try HubViewModel.validatedURL(from: value)
            urlError = nil
        } catch {
            urlError = error.localizedDescription
        }
    }
}
