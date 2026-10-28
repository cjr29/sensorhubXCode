import Foundation
import SwiftUI
import SwiftData

struct HubSensorResult: Sendable {
    let hubKey: String
    let sensors: [SensorDTO]
}

private struct HubRequest: Sendable {
    let hubKey: String
    let urlString: String
}

enum SensorServiceError: Error {
    case badURL
    case badResponse
    case decodeFailed
}

final class SensorService: Sendable {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchSensors(
        forHubURLString urlString: String
    ) async throws -> [SensorDTO] {
        guard let url = URL(string: urlString + "/sensors") else {
            throw SensorServiceError.badURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response): (Data, URLResponse)
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SensorServiceError.badResponse
        }
        
        do {
            return try JSONDecoder().decode(
                [SensorDTO].self,
                from: data
            )
        } catch {
            throw SensorServiceError.decodeFailed
        }
    }
    
    func fetchAllSensors(
        hubs: [Hub]
    ) async -> [HubSensorResult] {
        let requests = hubs.map {
            HubRequest(
                hubKey: $0.uniqueKey,
                urlString: $0.urlString
            )
        }
        
        return await withTaskGroup(
            of: HubSensorResult?.self
        ) { group in
            for request in requests {
                group.addTask { [self] in
                    do {
                        let sensors = try await fetchSensors(
                            forHubURLString: request.urlString
                        )
                        
                        return HubSensorResult(
                            hubKey: request.hubKey,
                            sensors: sensors
                        )
                    } catch {
                        print(
                            "Failed to fetch sensors from " +
                            "\(request.urlString): \(error)"
                        )
                        return nil
                    }
                }
            }
            
            var results: [HubSensorResult] = []
            
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            
            return results
        }
    }
    
    func fetchSensorsForHub(
        hub: Hub
    ) async throws -> HubSensorResult {
        let sensors = try await fetchSensors(
            forHubURLString: hub.urlString
        )
        
        return HubSensorResult(
            hubKey: hub.uniqueKey,
            sensors: sensors
        )
    }
}

extension SensorService {
    @MainActor
    func upsertSensor(
        _ dto: SensorDTO,
        forHub hub: Hub,
        in context: ModelContext
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

        // Apply the DTO regardless of whether the object was new or existing.
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
    
    @MainActor
    func upsert(
        _ results: [HubSensorResult],
        forHubs hubs: [Hub],
        in context: ModelContext
    ) throws {
        let hubsByKey = Dictionary(
            uniqueKeysWithValues: hubs.map {
                ($0.uniqueKey, $0)
            }
        )

        for result in results {
            guard let hub = hubsByKey[result.hubKey] else {
                print(
                    "No local Hub found for key \(result.hubKey)"
                )
                continue
            }

            for dto in result.sensors {
                try upsertSensor(
                    dto,
                    forHub: hub,
                    in: context
                )
            }
        }

        try context.save()
    }
}
