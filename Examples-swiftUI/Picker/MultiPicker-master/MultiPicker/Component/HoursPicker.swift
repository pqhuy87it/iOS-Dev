//
//  HoursPicker.swift
//  MultiPicker
//
//  Created by Heiner Gerdes on 17.05.20.
//  Copyright © 2020 Heiner Gerdes. All rights reserved.
//

import SwiftUI
import Combine

/// An expandable two row hours picker. When expanded the value can be changed.
///
/// # Features
/// - Title (+ caption title) view with hours value
/// - Expandable hours and minutes picker
/// - Picker expands/contracts on tap
/// - Picker expands/contracts with property `isExpanded` change
///
///```
///     -------------------------
///     |title             hours|  <- Title View
///     |caption                |
///     -------------------------
///     |                       |  <- Expandable Picker View
///     | |       |  |       |  |
///     | |   h   |  |  min  |  |
///     | |       |  |       |  |
///     |                       |
///     -------------------------
///```
///
/// # Example
/// ```
/// @State var hours: Double = 8.5
/// @State var isExpanded: Bool = false
///
/// HoursPicker(hours: $hours,
///             title: "Hours",
///             captionTitle: "Some hours you want to pick.",
///             isExpanded: $isExpanded)
/// ```
/// ---
///
/// # Parameters:
/// - `hours:` The decimal hours for the picker (e.g. 2.5 for 2 hours and 30 minutes)
/// - `title:` The title of the picker.
/// - `captionTitle:` The caption title of the picker.
/// - `isExanded:` The value to expand (`true`) / contract (`false`) the picker.
///
struct HoursPicker: View {
    @ObservedObject private var viewModel: HoursPickerVM
    private var hours: [Int] = Array(0...24)
    @Binding private var hoursValue: Double
    private var minutes: [Int]
    private var heightValue: CGFloat = 150
    @Binding private var isExpanded: Bool
    private var title: LocalizedStringKey
    private var captionTitle: LocalizedStringKey
    
    init(hours: Binding<Double>, title: LocalizedStringKey,
         captionTitle: LocalizedStringKey,
         isExpanded: Binding<Bool>) {
        self._hoursValue = hours
        self.hours = Array(0...23)
        let timeInterval = 1
        self.minutes = Array(stride(from: 0, through: 59, by: timeInterval))
        self.viewModel = HoursPickerVM(hours: hours.wrappedValue)
        self.title = title
        self.captionTitle = captionTitle
        self._isExpanded = isExpanded
    }
    
    var body: some View {
        VStack{
            Button(action: {
                self.isExpanded.toggle()
            }) {
                VStack{
                    TitleView(viewModel: self.viewModel,
                              title: self.title,
                              captionTitle: self.captionTitle,
                              isExpanded: self.$isExpanded)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .animation(.none)
            
            if self.isExpanded{
                
                MultiPicker(selection1: self.$viewModel.hourSelection,
                            selection2: self.$viewModel.minuteSelection,
                            values1: self.hours,
                            values2: self.minutes,
                            values1Suffix: "h",
                            values2Suffix: "m")
            }
        }
        .onReceive(self.viewModel.$hours) { newValue in
            if self.hoursValue != newValue {self.hoursValue = newValue}
        }
    }
}


private struct TitleView: View{
    @ObservedObject var viewModel: HoursPickerVM
    var title: LocalizedStringKey
    var captionTitle: LocalizedStringKey
    @Binding var isExpanded: Bool
    
    var body: some View {
        HStack{
            VStack {
                HStack {
                    Text(self.title)
                        .foregroundColor(.primary)
                    Spacer()
                }
                HStack {
                    Text(self.captionTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            Spacer()
            Group{
                Text("\(self.viewModel.hourSelection)h")
                Text("\(self.viewModel.minuteSelection)m")
            }
            .foregroundColor(self.isExpanded ? .accentColor : .secondary)
        }
        .foregroundColor(.primary)
    }
}

private class HoursPickerVM: ObservableObject{
    private let timeManager = TimeManager.shared
    @Published var hourSelection: Int = 0 {didSet{ self.setHours() }}
    @Published var minuteSelection: Int = 0 {didSet{ self.setHours() }}
    @Published var hours: Double = 0.0
    private var cancellableSet: Set<AnyCancellable> = []
    private var isInitializing: Bool = false
    
    
    init(hours: Double) {
        self.isInitializing = true
        self.hours = hours
        self.setHoursSelections()
        self.isInitializing = false
    }
    
    public func setHoursSelections(){
        let hourComponents = timeManager.hours2Components(hours: self.hours)
        self.hourSelection = hourComponents.hour
        self.minuteSelection = hourComponents.minute
    }
    
    private func setHours(){
        if !self.isInitializing{
            self.hours = timeManager.components2Hours(components: [self.hourSelection, self.minuteSelection])
        }
    }
}



