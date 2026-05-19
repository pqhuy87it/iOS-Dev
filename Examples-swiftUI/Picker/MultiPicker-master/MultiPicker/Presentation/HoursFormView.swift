//
//  HoursFormView.swift
//  MultiPicker
//
//  Created by Heiner Gerdes on 17.05.20.
//  Copyright © 2020 Heiner Gerdes. All rights reserved.
//

import SwiftUI

struct HoursFormView: View {
    let title: LocalizedStringKey = "Picked Hours"
    let caption: LocalizedStringKey = "These are some hours you want to pick."
    @State var decimalHours: Double = 5.3
    @State var isExpanded: Bool = false
    
    var body: some View {
        NavigationView{
            Form{
                Text("Another Row")
                HoursPicker(hours: self.$decimalHours,
                            title: self.title,
                            captionTitle: self.caption,
                            isExpanded: self.$isExpanded)
                Text("Another Row")
                Text("Another Row")
            }
            .navigationBarTitle("Hours Form", displayMode: .inline)
        }
    }
}
