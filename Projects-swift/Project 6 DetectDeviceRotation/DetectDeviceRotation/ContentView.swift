//
//  ContentView.swift
//  DetectDeviceRotation
//
//  Created by mybkhn on 2021/03/23.
//

import SwiftUI

struct ContentView: View {
	@State private var orientation = UIDeviceOrientation.unknown
	
	var body: some View {
		Group {
			if orientation.isPortrait {
				Text("Portrait")
			} else if orientation.isLandscape {
				Text("Landscape")
			} else if orientation.isFlat {
				Text("Flat")
			} else {
				Text("Unknown")
			}
		}
		.onRotate { newOrientation in
			orientation = newOrientation
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
