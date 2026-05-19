//
//  TabItem.swift
//  TabarCustom
//
//  Created by Luu Dinh Nam on 4/14/21.
//

import SwiftUI

struct TabItem: View {
    @State private var favoriteColor = 0
    init() {
        UISegmentedControl.appearance().setBackgroundImage(imageWithColor(color:UIColor.green),
														   for: .normal,
														   barMetrics: .default)
        UISegmentedControl.appearance().setBackgroundImage(imageWithColor(color:UIColor.red),
														   for: .selected,
														   barMetrics: .default)
        UISegmentedControl.appearance().setDividerImage(imageWithColor(color: UIColor.clear),
														forLeftSegmentState: .normal,
														rightSegmentState: .normal,
														barMetrics: .default)
    }
    
    private func imageWithColor(color: UIColor) -> UIImage {
            let rect = CGRect(x: 0.0, y: 0.0, width:  50.0, height: 30.0)
            UIGraphicsBeginImageContext(rect.size)
            let context = UIGraphicsGetCurrentContext()
            context!.setFillColor(color.cgColor);
            context!.fill(rect);
            let image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            return image!
        }
    var body: some View {
        VStack {
            Picker(selection: $favoriteColor, label: Text("What is your favorite color?")) {
                Text("Red").tag(0)
                Text("Green").tag(1)
                Text("Blue").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.top,0)
            Text("hello")
            Spacer()
        }
    }
}

struct TabItem_Previews: PreviewProvider {
    static var previews: some View {
        TabItem()
    }
}
