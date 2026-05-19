//
//  Example2View.swift
//  MultiPicker
//
//  Created by Heiner Gerdes on 17.05.20.
//  Copyright © 2020 Heiner Gerdes. All rights reserved.
//

import SwiftUI

struct Example2View: View {
    var hoursValues: [Int] = Array(0...23)
    var minutesValues: [Int] = Array(0...59)
    @State var hoursSelection: Int = 8
    @State var minuteSelection: Int = 0
    
    var body: some View {
        NavigationView{
            VStack{
                MultiPicker(selection1: self.$hoursSelection,
                            selection2: self.$minuteSelection,
                            values1: self.hoursValues,
                            values2: self.minutesValues,
                            values1Prefix: "",
                            values1Suffix: "h",
                            values2Prefix: "",
                            values2Suffix: "m",
                            middleText: "")
                HStack{
                    Text("\(self.hoursValues[hoursSelection])h")
                    Text("\(self.minutesValues[minuteSelection])m")
                }
            }
            .navigationBarTitle("Example 2", displayMode: .inline)
        }
    }
}
