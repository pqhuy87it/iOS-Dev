//
//  List3.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct List3: View {
    var body: some View {
		List(landmarks) { landmark in
			NavigationLink(destination: LandmarkDetail(landmark: landmark)) {
				LandmarkRow(landmark: landmark)
			}
		}
		.navigationTitle("Landmarks")
    }
}

struct List3_Previews: PreviewProvider {
    static var previews: some View {
        List3()
    }
}
