//
//  ContentView.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/09.
//

import SwiftUI

struct ContentView: View {
    var list: some View {
        List {
			Section(header: Text("Section 1")) {
				Grouping(title: "Buttons", icon: "capsule", content: { ButtonsGroup() })
				Grouping(title: "Text", icon: "text.aligncenter", content: { TextGroup() })
				Display(title: "Navigation Bar", icon: "text.aligncenter", content: { NavigationBarGroup() })
				Display(title: "Stack", icon: "text.aligncenter", content: { StackGroup() })
				Grouping(title: "Fonts", icon: "textformat", content: { FontsGroup() })
				Grouping(title: "Colors", icon: "paintpalette", content: { ColorsGroup() })
				Grouping(title: "Images", icon: "photo", content: { ImagesGroup() })
				Grouping(title: "Map", icon: "map", content: { MapGroup() })
				Grouping(title: "Controls", icon: "slider.horizontal.3", content: { ControlsGroup() })
				Grouping(title: "Shapes", icon: "square.on.circle", content: { ShapesGroup() })
			}

			Section(header: Text("Section 2")) {
				Grouping(title: "Indicators", icon: "speedometer", content: { IndicatorsGroup() })
				Grouping(title: "Gestures", icon: "hand.tap", content: { GesturesGroup() })
				Grouping(title: "Haptics", icon: "waveform", content: { HapticsGroup() })
				Display(title: "Lists", icon: "text.aligncenter", content: { ListsGroup() })
				Display(title: "StateAndDataFlow", icon: "text.aligncenter", content: { StateAndDataFlowGroup() })
			}
        }
		.listStyle(GroupedListStyle())
    }
    
    var body: some View {
        NavigationView {
            list.navigationBarTitle("SwiftUI")
        }
        .accentColor(.accentColor)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
