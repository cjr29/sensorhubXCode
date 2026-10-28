//
//  Hub.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 7/23/26.
//  using duck.ai
//
/**
    Hub
 Hub is a SwiftData model used to persist data used by SwiftUI views.
 It must be mutated on the main actor thread.
 All SwiftData objects are observable and views using them are automatically updated
 when an object changes.
    Because SwiftData model context must be on the main thread, these objects should not
 be used for background processing and data transfer. For processing off the main thread, create
 Data Transfer Object versions that are Sendable across thread boundaries.

 */

import Foundation
import SwiftData

@Model
final class Hub {
    @Attribute(.unique)
    var uniqueKey: String

    var station: String
    var urlString: String
    var name: String

    @Relationship(inverse: \Sensor.hubs)
    var sensors: [Sensor] = []

    init(station: String, urlString: String, name: String) {
        self.station = station
        self.urlString = urlString
        self.name = name
        self.uniqueKey = Hub.makeKey(
            station: station,
            urlString: urlString
        )
    }

    static func makeKey(station: String, urlString: String) -> String {
        "\(station)|\(urlString)"
    }
}

struct HubDTO: Sendable, Hashable {
    let station: String
    let urlString: String
    let name: String
}

actor HubStore {
    let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func existingURLs() throws -> Set<String> {
        let context = ModelContext(container)
        let hubs = try context.fetch(FetchDescriptor<Hub>())
        return Set(hubs.map(\.urlString))
    }

    func insertNewHubs(_ dtos: [HubDTO]) throws {
        let context = ModelContext(container)

        guard !dtos.isEmpty else {
            return
        }

        let normalizedURLs = Set(
            dtos.map { normalizedURLString($0.urlString) }
        )

        let descriptor = FetchDescriptor<Hub>(
            predicate: #Predicate<Hub> { hub in
                normalizedURLs.contains(hub.urlString)
            }
        )

        var insertedURLs = Set(
            try context.fetch(descriptor).map(\.urlString)
        )

        for dto in dtos {
            let normalizedURL = normalizedURLString(dto.urlString)

            guard insertedURLs.insert(normalizedURL).inserted else {
                continue
            }

            context.insert(
                Hub(
                    station: dto.station,
                    urlString: normalizedURL,
                    name: dto.name
                )
            )
        }

        try context.save()
    }
    
    func normalizedURLString(_ url: String) -> String {
        var normalized = url.lowercased()

        while normalized.last == "/" {
            normalized.removeLast()
        }

        return normalized
    }
}
