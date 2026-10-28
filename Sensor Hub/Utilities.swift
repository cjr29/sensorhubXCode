//
//  Utilities.swift
//  My Weather Sensors
//
//  Created by Chris Riddick on 6/26/25.
//

import Foundation
import SwiftUI

// Convert from a Date/Time string to a Date/Time object
func dateFromString(dateString: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let date = formatter.date(from: dateString)
    return date!
}

// Convert from a Date type to a formatted string
func dateToString(date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let formattedString = formatter.string(from: date)
    return formattedString
}

// Calculates two hours in the past and returns True if greater than two hours in the past
func twoHoursOld(date: String) -> Bool {
    let now = Date()
    let modifiedDate = Calendar.current.date(byAdding: .hour, value: -2, to: now)!
    let sensorDate = dateFromString(dateString: date)
    if sensorDate < modifiedDate {
        return true
    } else {
        return false
    }
}

struct BlueButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.blue.opacity(0.3))
            .foregroundStyle(.black)
            .foregroundColor(.black)
            .clipShape(Capsule())
    }
}

struct GreenButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.green.opacity(0.5))
            .foregroundStyle(.black)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Example: scale effect
            .opacity(configuration.isPressed ? 0.8 : 1.0) // Example: opacity change
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed) // Animate the change
    }
}

struct RedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.red.opacity(0.5))
            .foregroundStyle(.black)
            .clipShape(Capsule())
    }
}

