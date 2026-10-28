//
//  WiFiCredentialsView.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 8/22/26.
//

import Foundation
import SwiftUI

struct WiFiCredentials {
    let ssid: String
    let password: String
}

struct WiFiCredentialsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var ssid = ""
    @State private var password = ""

    let onSave: (WiFiCredentials) -> Void

    private var canSave: Bool {
        !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Wi-Fi Network") {
                    TextField("SSID", text: $ssid)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }
            }
            .navigationTitle("Wi-Fi Credentials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let credentials = WiFiCredentials(
                            ssid: ssid.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )

                        onSave(credentials)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }
}
