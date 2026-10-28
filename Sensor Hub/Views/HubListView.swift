//
//  HubListView.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 7/24/26.
//

import SwiftData
import SwiftUI

@MainActor
struct HubListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Hub.station) private var hubs: [Hub]

    @Binding var isDiscovering: Bool
    @Binding var discoverErrorMessage: String?
    @Binding var didDiscoverCount: Int
    @Binding var discoveredTotal: Int
    @Binding var discoveredProcessed: Int

    @Binding var isConfiguringNewHub: Bool
    @Binding var configureNewHubErrorMessage: String?
    @Binding var configureNewHubStepText: String

    @State private var hubToEdit: Hub?

    enum OverlayMode { case configuringNewHub, discoveringHubs, none }
    @State private var overlayMode: OverlayMode = .none

    var body: some View {
        VStack {
            hubList
                .disabled(isDiscovering)
                .overlay { configurationOverlay }
                .overlay { discoveryOverlay }
                .safeAreaInset(edge: .bottom) { discoveryCountView }
                .overlay { discoveryErrorView }
        }  // VStack
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Sensor Hubs")
        .sheet(item: $hubToEdit) { hub in HubEditView(hub: hub) }
    }

    private func deleteHubs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(hubs[index])
        }
        do { try modelContext.save() } catch {}
    }
}

extension HubListView {
    fileprivate var hubList: some View {
        List {
            ForEach(hubs) { hub in
                hubRow(for: hub)
            }
            .onDelete(perform: deleteHubs)
        }
    }

    fileprivate func hubRow(for hub: Hub) -> some View {
        Button {
            hubToEdit = hub
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(hub.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(hub.station)
                    .font(.headline)

                Text(hub.urlString)
                    .font(.footnote)
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

extension HubListView {
    @ViewBuilder
    fileprivate var configurationOverlay: some View {
        if isConfiguringNewHub {
            ZStack {
                Color.black
                    .opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    ProgressView()

                    Text(
                        configureNewHubStepText.isEmpty
                            ? "Set up new Sensor Hub…"
                            : configureNewHubStepText
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)

                    if let message = configureNewHubErrorMessage,
                        !message.isEmpty
                    {
                        Text(message)
                            .font(
                                .system(
                                    size: 14,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.red.opacity(0.95))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    fileprivate var discoveryOverlay: some View {
        if isDiscovering {
            VStack(spacing: 10) {
                ProgressView()

                Text(discoveryStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    fileprivate var discoveryStatusText: String {
        guard discoveredTotal > 0 else {
            return "Finding Sensor Hubs…"
        }

        return "Finding Sensor Hubs… "
            + "\(discoveredProcessed + 1)/\(discoveredTotal)"
    }

    @ViewBuilder
    fileprivate var discoveryCountView: some View {
        if didDiscoverCount > 0 {
            Text("Added \(didDiscoverCount) new hub(s).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    fileprivate var discoveryErrorView: some View {
        if let message = discoverErrorMessage,
            !message.isEmpty
        {
            VStack {
                Spacer()

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 12)
            }
        }
    }
}

enum HubViewModel {
    enum URLValidationError: LocalizedError {
        case empty
        case invalid

        var errorDescription: String? {
            switch self {
            case .empty: return "URL is required."
            case .invalid:
                return "Please enter a valid URL (include http/https)."
            }
        }
    }

    static func validatedURL(from raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw URLValidationError.empty }

        let candidates: [String]
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            candidates = [trimmed]
        } else {
            candidates = ["https://" + trimmed, "http://" + trimmed]
        }

        for s in candidates {
            if let url = URL(string: s),
                let scheme = url.scheme?.lowercased(),
                scheme == "http" || scheme == "https",
                url.host != nil
            {
                return url
            }
        }

        throw URLValidationError.invalid
    }
}

//#Preview {
//    HubListView()
//        .modelContainer(for: [Hub.self], inMemory: true)
//}

struct HubSetupChoiceView: View {
    @Environment(\.dismiss) private var dismiss

    let onManualAdd: () -> Void
    let onConfigureNewHub: () -> Void
    let isConfiguring: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("New Hub")
                    .font(.headline)
                Text(
                    "Would you like to add a hub manually, or configure a new hub?"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button {
                        onManualAdd()
                    } label: {
                        Text("Manually add a Hub")
                            .frame(maxWidth: .infinity)
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onConfigureNewHub()
                    } label: {
                        Text("Set up a new Hub")
                            .frame(maxWidth: .infinity)
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isConfiguring)

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.secondary)
                    .disabled(isConfiguring)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: 420)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    HubSetupChoiceView(
        onManualAdd: {},
        onConfigureNewHub: {},
        isConfiguring: false
    )
}
