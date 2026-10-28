//
//  SensorPatchDTO.swift
//  My Weather Sensors
//
//  Created by Chris Riddick on 7/19/25.
//
/*
 This structure holds the data for a rename request to the REST API
 */
struct SensorPatchDTO: Codable {
    var ID: Int?
    var SENSORNAME: String?
    var LOCATION: String?
    var DESCRIPTION: String?
    var ACTIVE: Int?  // True = 1, False = 0
}
