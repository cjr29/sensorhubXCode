import Foundation
import SwiftData

struct SensorRecord {
    let dto: SensorDTO
    let hub: Hub
}

@MainActor
final class SensorRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(
        _ results: [HubSensorResult],
        forHubs hubs: [Hub]
    ) throws {
        let hubsByKey = Dictionary(
            uniqueKeysWithValues: hubs.map {
                ($0.uniqueKey, $0)
            }
        )

        for result in results {
            guard let hub = hubsByKey[result.hubKey] else {
                print(
                    "No local Hub found for key: \(result.hubKey)"
                )
                continue
            }

            for dto in result.sensors {
                try upsertOne(
                    dto,
                    from: hub
                )
            }
        }

        try context.save()
    }

    private func upsertOne(
        _ dto: SensorDTO,
        from hub: Hub
    ) throws {
        let key = "\(dto.SENSORID)|\(dto.STATION)"

        let descriptor = FetchDescriptor<Sensor>(
            predicate: #Predicate<Sensor> { sensor in
                sensor.uniqueKey == key
            }
        )

        let sensor: Sensor

        if let existing = try context.fetch(descriptor).first {
            sensor = existing
        } else {
            sensor = dto.toEntity()
            sensor.uniqueKey = key
            context.insert(sensor)
        }

        sensor.active = dto.ACTIVE == 1
        sensor.battery = dto.BATTERY
        sensor.channel = dto.CHANNEL
        sensor.descriptionText = dto.DESCRIPTION
        sensor.humidity =
            dto.HUMIDITY == -99 ? nil : dto.HUMIDITY
        sensor.location = dto.LOCATION
        sensor.model = dto.MODEL
        sensor.sensorId = dto.SENSORID
        sensor.sensorName = dto.SENSORNAME
        sensor.station = dto.STATION
        sensor.temperature =
            dto.TEMPERATURE == -999.9
            ? nil
            : dto.TEMPERATURE
        sensor.timeText = dto.TIME

        if !sensor.hubs.contains(where: {
            $0.persistentModelID == hub.persistentModelID
        }) {
            sensor.hubs.append(hub)
        }
    }
    
    private let timeTextFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current  // Use UTC instead if the API sends UTC times
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    @discardableResult
    func removeExpiredSensors(now: Date = Date()) throws -> Int {
        let cutoff = now.addingTimeInterval(-600 * 60)

        let candidates = try context.fetch(
            FetchDescriptor<Sensor>(
                predicate: #Predicate<Sensor> { sensor in
                    sensor.active == false || sensor.sensorName == "UNKNOWN"
                }
            )
        )

        var deletedCount = 0

        for sensor in candidates {
            let shouldDelete: Bool

            if sensor.active == false {
                shouldDelete = true
            } else if sensor.sensorName == "UNKNOWN",
                let sensorDate = timeTextFormatter.date(
                    from: sensor.timeText
                ),
                sensorDate < cutoff
            {
                shouldDelete = true
            } else {
                shouldDelete = false
            }

            if shouldDelete {
                context.delete(sensor)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try context.save()
        }

        return deletedCount
    }
}
