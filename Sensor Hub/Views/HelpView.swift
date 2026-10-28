//
//  HelpView.swift
//  Sensor Hub
//
//  Created by Chris Riddick on 7/21/26.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack {
            Text("Sensor Hub Help")
                .multilineTextAlignment(.center)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            ScrollView {
                Text(helpText)
                    .font(.body)
                    .padding()
            }
        }
        .padding([.top, .bottom], 50)
    }
}

#Preview {
    HelpView()
}

let helpText = "Sensor Hub displays temperature and humidity sensors from several vendors (AcuRite, LaCrosse, Ambient). You can select which sensors to display and what to name them. You can annotate the sensors with location and description information.\n \nSensor Hub looks for a local wifi sensor hub. The sensor hub supplies a list of sensors it sees.\n \nThe Updated field is red when a sensor has not reported for over two hours.\n"
