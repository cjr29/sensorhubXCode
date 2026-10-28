//
//  Sensor.swift
//
//  Created by Chris Riddick on 7/23/26.
//  using duck.ai
//
/**
    Sensor
 Sensor is a SwiftData model used to persist data used by SwiftUI views.
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
final class Sensor {
    @Attribute(.unique)
    var uniqueKey: String

    var id: Int
    var isHome: Bool
    var active: Bool
    var battery: Int
    var channel: String
    var descriptionText: String
    var location: String
    var model: String
    var sensorId: Int
    var sensorName: String
    var station: String
    var timeText: String
    var humidity: Int?
    var temperature: Double?

    var hubs: [Hub] = []
    
    init(
        id: Int,
        station: String,
        active: Bool,
        battery: Int,
        channel: String,
        descriptionText: String,
        humidity: Int?,
        location: String,
        model: String,
        sensorId: Int,
        sensorName: String,
        temperature: Double?,
        timeText: String,
        isHome: Bool = false
    ) {
        self.sensorId = sensorId
        self.station = station
        self.uniqueKey = Sensor.makeKey(
            sensorId: sensorId,
            station: station
        )
        self.isHome = isHome
        self.active = active
        self.battery = battery
        self.channel = channel
        self.descriptionText = descriptionText
        self.humidity = humidity
        self.location = location
        self.model = model
        self.id = id
        self.sensorName = sensorName
        self.temperature = temperature
        self.timeText = timeText
    }
    
    static func makeKey(sensorId: Int, station: String) -> String {
        "\(sensorId)|\(station)"
    }

    func setAsGlobalHome(in context: ModelContext) throws {
        // Fetch everything (no predicate conjugation), then filter in memory
        let allSensors = try context.fetch(FetchDescriptor<Sensor>())

        for s in allSensors where s.isHome == true && s.uniqueKey != self.uniqueKey {
            s.isHome = false
        }

        self.isHome = true
    }
}

struct SensorDTO: Decodable, Sendable {
    let ACTIVE: Int
    let BATTERY: Int
    let CHANNEL: String
    let DESCRIPTION: String
    let HUMIDITY: Int
    let ID: Int
    let LOCATION: String
    let MODEL: String
    let SENSORID: Int
    let SENSORNAME: String
    let STATION: String
    let TEMPERATURE: Double
    let TIME: String
}

extension SensorDTO {
    func toEntity() -> Sensor {
        let mappedHumidity: Int? =
            HUMIDITY == -99 ? nil : HUMIDITY

        let mappedTemperature: Double? =
            abs(TEMPERATURE - (-999.9)) < 0.0001
            ? nil
            : TEMPERATURE

        return Sensor(
            id: ID,
            station: STATION,
            active: ACTIVE == 1,
            battery: BATTERY,
            channel: CHANNEL,
            descriptionText: DESCRIPTION,
            humidity: mappedHumidity,
            location: LOCATION,
            model: MODEL,
            sensorId: SENSORID,
            sensorName: SENSORNAME,
            temperature: mappedTemperature,
            timeText: TIME
        )
    }
}

