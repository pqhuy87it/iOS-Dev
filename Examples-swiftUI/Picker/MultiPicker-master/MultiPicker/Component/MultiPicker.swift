//
//  MultiPicker.swift
//  MultiPicker
//
//  Created by Heiner Gerdes on 17.05.20.
//  Copyright © 2020 Heiner Gerdes. All rights reserved.
//

import SwiftUI

/// Picker for two values which conform to LosslessStringConvertible (e.g. String, Int, Double)
///
/// # Example
///     struct ContentView: View {
///         var intValues1: [Int] = Array(-5...10)
///         var intValues2: [Int] = Array(-10...10)
///         @State var intSelection1: Int = 0
///         @State var intSelection2: Int = 0
///
///         var body: some View {
///             VStack{
///                 MultiplePicker(selection1: self.$intSelection1,
///                                 selection2: self.$intSelection2,
///                                 values1: self.intValues1,
///                                 values2: self.intValues2,
///                                 values1Prefix: "P",
///                                 values1Suffix: "S",
///                                 values2Prefix: "P",
///                                 values2Suffix: "S",
///                                 middleText: ":")
///                 VStack(alignment: .leading){
///                     Text("Int Value 1: \(self.intValues1[intSelection1])")
///                     Text("Int Value 2: \(self.intValues2[intSelection2])")
///                 }
///             }
///         }
///     }
///
/// # Parameters
/// - `selection1`: The index of the picked value of the left picker
/// - `selection2`: The index of the picked value of the right picker
/// - `values1`: The values for the left picker (must conform to `LosslessStringConvertible`)
/// - `values2`: The values for the right picker (must conform to `LosslessStringConvertible`)
/// - `values1Prefix`: The text which is displayed in on the left side of the values of the left picker.
/// - `values1Suffix`: The text which is displayed in on the right side of the values of the left picker.
/// - `values2Prefix`: The text which is displayed in on the left side of the values of the left picker.
/// - `values2Suffix`: The text which is displayed in on the right side of the values of the right picker.
/// - `middleText`: The text which is displayed between the two pickers.
///
struct MultiPicker: View {
    @Binding private var selection1: Int
    @Binding private var selection2: Int
    private var values1: [String]
    private var values2: [String]
    private var values1Prefix: String?
    private var values1Suffix: String?
    private var values2Prefix: String?
    private var values2Suffix: String?
    private var middleText: String?
    private var heightValue: CGFloat = 150
    
    init<T: LosslessStringConvertible>(selection1: Binding<Int>,
                                       selection2: Binding<Int>,
                                       values1: [T],
                                       values2: [T],
                                       values1Prefix: String? = nil,
                                       values1Suffix: String? = nil,
                                       values2Prefix: String? = nil,
                                       values2Suffix: String? = nil,
                                       middleText: String? = nil) {
        self._selection1 = selection1
        self._selection2 = selection2
        self.values1 = values1.map { String($0) }
        self.values2 = values2.map { String($0) }
        self.values1Prefix = values1Prefix
        self.values1Suffix = values1Suffix
        self.values2Prefix = values2Prefix
        self.values2Suffix = values2Suffix
        self.middleText = middleText
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack{
                // addded to center the view in GeometryReader in iOS14
                Rectangle().opacity(0)
                HStack {
                    
                    Picker(selection: self.$selection1, label: Text("")) {
                        ForEach(0 ..< self.values1.count, id: \.self) { index in
                            HStack{
                                if self.values1Prefix != nil{
                                    Text("\(self.values1Prefix ?? "")")
                                }
                                Text("\(self.values1[index])").tag(index)
                                if self.values1Suffix != nil{
                                    Text("\(self.values1Suffix ?? "")")
                                }
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: geometry.size.width/3,
                           height: self.heightValue,
                           alignment: .center).clipped()
                    
                    if self.middleText != nil{
                        Text("\(self.middleText ?? "")")
                    }
                    
                    Picker(selection: self.$selection2, label: Text("")) {
                        ForEach(0 ..< self.values2.count, id: \.self) { index in
                            HStack{
                                if self.values2Prefix != nil{
                                    Text("\(self.values2Prefix ?? "")")
                                }
                                Text("\(self.values2[index])").tag(index)
                                if self.values2Suffix != nil{
                                    Text("\(self.values2Suffix ?? "")")
                                }
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: geometry.size.width/3,
                           height: self.heightValue,
                           alignment: .center).clipped()
                    
                }
            }
        }
        .frame(height:heightValue + 25)
    }
}
