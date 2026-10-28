//
//  HubNotFoundModal.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 8/2/26.
//

import SwiftUI
import SwiftData

struct HubNotFoundModal: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("No hubs found")
                .font(.title2)
                .bold()

            Text("Make sure your sensor hub is powered on and visible on the local network.")
                .multilineTextAlignment(.center)

            Button("OK") { onDismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: 420)
    }
}
