//
//  StoryView.swift
//  My Weather Sensors
//
//  Created by Chris Riddick on 6/17/25.
//
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack {
            Text("About Sensor Hub")
                .multilineTextAlignment(.center)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            ScrollView {
                Text(information.story)
                    .font(.body)
                    .padding()
            }
        }
        .padding([.top, .bottom], 50)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}

struct Info {
    let image: String
    let name: String
    let story: String
}

let information = Info(
    image: "Clouds",
    name: "(c) Christopher J. Riddick, 2025, 2026",
    story: "Sensor Hub displays temperature and humidity sensors from several vendors (AcuRite, LaCrosse, Ambient). You can select which sensors to display and what to name them. You can annotate the sensors with location and description information.\n \nSensor Hub looks for a local wifi sensor hub. The sensor hub supplies a list of sensors it sees.\n \nThe Updated field is red when a sensor has not reported for over two hours.\n",
)

