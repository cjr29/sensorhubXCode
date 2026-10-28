//
//  SensorRowView.swift
//  My Weather Sensors
//
//  Created by Chris Riddick on 6/19/25.
//

import SwiftUI

struct SensorRowView: View {
    let item: Sensor
    
    var body: some View {
        
        HStack {
            // First block with a fixed width
            Rectangle()
                .fill(Color.clear)
                .frame(width: 260, height: 70)
                .background(Color.clear)
                .overlay(
                    VStack (alignment: .leading) {
                        HStack {
                            if twoHoursOld(date: item.timeText) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 16)
                            } else {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 16)
                            }

                            Text(item.sensorName)
                                .font(.system(size: 18, weight: .heavy))
                                .italic()
                        } // Name
                        Text("Station: \(item.station)")
                            .font(.system(size: 12))
                        if twoHoursOld(date: item.timeText) {
                            Text("Updated: \(item.timeText)")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Updated: \(item.timeText)")
                                .font(.system(size: 12))
                                .multilineTextAlignment(.center)
                        }
                    } // ID, Model, Channel
                ) // end first column overlay
            
            // Second block that takes up the remaining available space
            Rectangle()
                .fill(Color.clear)
                .background(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    VStack {
                        HStack {
                            if (item.temperature == nil){
                                Text("Temperature:")
                                    .font(.system(size: 28, weight: .heavy))
                                    .hidden()
                            } else {
                                Text("\(item.temperature ?? -999.9, format: .number.precision(.fractionLength(1)))")
                                    .font(.system(size: 28, weight: .heavy))
                                //                                    .padding(.trailing, 5)
                                Image(systemName: "degreesign.fahrenheit")
                                    .font(.system(size: 21, weight: .medium))
                                //                                    .padding(.trailing, 5)
                            }
                        }
                        HStack {
                            if item.humidity == nil {
                                Text("Humidity:")
                                    .font(.system(size: 18, weight: .heavy))
                                    .hidden()
                            } else {
                                Text("\(item.humidity ?? -99)")
                                    .font(.system(size: 18, weight: .medium))
                                Image(systemName: "humidity")
                                    .font(.system(size: 18, weight: .medium))
                            }
                        } // Humidity
                    }
                ) // end second column overlay
        } // End of HStack
    } // end of body
} // SensorRowView

struct SensorRowView_Previews: PreviewProvider {
    static var previews: some View {
        SensorRowView(item: Sensor(id: 2, station: "station", active: true, battery: -1, channel: " ", descriptionText: "test-temp only in Study", humidity: nil, location: "study", model: "LaCrosse-TX", sensorId: 15, sensorName: "Study",    temperature: 75.56, timeText: "2024-01-01 11:00:00", ))
    }
}
