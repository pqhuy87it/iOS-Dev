//
//  Example1View.swift
//  MultiPicker
//
//  Created by Heiner Gerdes on 17.05.20.
//  Copyright © 2020 Heiner Gerdes. All rights reserved.
//

import SwiftUI

struct Example1View: View {
    let prefix: String = "➡️"
    let suffix: String = "⬅️"
    
    var intValues1: [Int] = Array(-5...10)
    var intValues2: [Int] = Array(-10...10)
    @State var intSelection1: Int = 0
    @State var intSelection2: Int = 0
    
    var stringValues1: [String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J" ]
    var stringValues2: [String] = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
    @State var stringSelection1: Int = 0
    @State var stringSelection2: Int = 0
    
    var doubleValues1: [Double] = Array(stride(from: 5.0, through: 7.0, by: 0.1))
    var doubleValues2: [Double] = Array(stride(from: 100.5, through: 103.3, by: 0.1))
    @State var doubleSelection1: Int = 0
    @State var doubleSelection2: Int = 0
    
    var body: some View {
        NavigationView{
            VStack{
                //Int Picker
                MultiPicker(selection1: self.$intSelection1,
                            selection2: self.$intSelection2,
                            values1: self.intValues1,
                            values2: self.intValues2,
                            values1Prefix: self.prefix,
                            values1Suffix: self.suffix,
                            values2Prefix: self.prefix,
                            values2Suffix: self.suffix,
                            middleText: "-")
                VStack(alignment: .leading){
                    Text("Int Value 1: \(self.intValues1[intSelection1])")
                    Text("Int Value 2: \(self.intValues2[intSelection2])")
                }
                
                //String Picker
                MultiPicker(selection1: self.$stringSelection1,
                            selection2: self.$stringSelection2,
                            values1: self.stringValues1,
                            values2: self.stringValues2,
                            values1Prefix: self.prefix,
                            values1Suffix: self.suffix,
                            values2Prefix: self.prefix,
                            values2Suffix: self.suffix,
                            middleText: ":")
                VStack(alignment: .leading){
                    Text("String Value 1: \(self.stringValues1[stringSelection1])")
                    Text("String Value 2: \(self.stringValues2[stringSelection2])")
                }
                
                //Double Picker
                MultiPicker(selection1: self.$doubleSelection1,
                            selection2: self.$doubleSelection2,
                            values1: self.doubleValues1,
                            values2: self.doubleValues2,
                            values1Prefix: self.prefix,
                            values1Suffix: self.suffix,
                            values2Prefix: self.prefix,
                            values2Suffix: self.suffix,
                            middleText: "--")
                VStack(alignment: .leading){
                    Text("Double Value 1: \(self.doubleValues1[doubleSelection1])")
                    Text("Double Value 2: \(self.doubleValues2[doubleSelection2])")
                }
            }
            .navigationBarTitle("Example 1", displayMode: .inline)
        }
    }
}
