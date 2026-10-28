//
//  AppStore.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 7/31/26.
//

import Foundation
import SwiftData

@MainActor
final class AppStore {
    static let shared = AppStore()
    private init() {}

    private(set) var homeSensor: Sensor?
    // If you want to store only one "homeSensor" and one "currentHub" via SwiftData,
    // you need some way to query them. Here we do that via SwiftData fetches.

    func load(from context: ModelContext) async {
        homeSensor = fetchHomeSensor(from: context)
    }

    func setHomeSensor(_ sensor: Sensor?, context: ModelContext) async {
        if let sensor {
            try? setOnlyHomeSensor(sensor, in: context)
            homeSensor = sensor
        } else {
            try? clearHomeSensor(in: context)
            homeSensor = nil
        }
        await save(context: context)
    }

    func currentHubConfigured() -> Bool {
        UserDefaults.standard.bool(forKey: "currentHubConfigured")
    }

    // MARK: - SwiftData helpers

    private func save(context: ModelContext) async {
        do {
            try context.save()
        } catch {
            // handle/log if you want
        }
    }
}

extension AppStore {

    private func fetchHomeSensor(from context: ModelContext) -> Sensor? {
        let descriptor = FetchDescriptor<Sensor>(
            predicate: #Predicate { $0.isHome == true }
        )
        return try? context.fetch(descriptor).first
    }

    private func setOnlyHomeSensor(
        _ sensor: Sensor,
        in context: ModelContext
    ) throws {
        let all = try context.fetch(FetchDescriptor<Sensor>())
        for s in all where s.isHome {
            s.isHome = false
        }
        sensor.isHome = true
    }

    private func clearHomeSensor(in context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<Sensor>())
        for s in all where s.isHome {
            s.isHome = false
        }
    }
}
