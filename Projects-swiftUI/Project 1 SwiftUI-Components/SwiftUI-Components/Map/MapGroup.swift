//
//  MapGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import MapKit
import SwiftUI

struct MapGroup: View {

	@State private var coordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3348, longitude: -122.0090),
															 span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))

	var body: some View {
		SectionView(
			headerTitle: "Map",
			footerTitle: "A map",
			content: {
				Map(coordinateRegion: $coordinateRegion)
					.frame(minWidth: 200, idealWidth: 500, maxWidth: .infinity, minHeight: 200, idealHeight: 500, maxHeight: .infinity)
			}
		)
	}

}

struct MapGroup_Previews: PreviewProvider {
	static var previews: some View {
		MapGroup()
			.previewLayout(.sizeThatFits)
	}
}
