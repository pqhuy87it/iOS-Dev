//
//  GesturesGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct GesturesGroup: View {

	var body: some View {
		Group{
			SectionView(headerTitle: "A Gesture that requires a certain number of taps.") {
				TapGestureBlock()
			}

			SectionView(headerTitle: "A Gesture that detects drag motion.") {
				DragGestureBlock()
			}

			SectionView(headerTitle: "A Gesture that detects a Long Press.") {
				LongPressGestureBlock()
			}
		}
	}
}

struct GesturesGroup_Previews: PreviewProvider {
	static var previews: some View {
		GesturesGroup()
	}
}

extension DragGesture.Value {
	var distance: CGFloat {
		return sqrt(pow(self.predictedEndLocation.x,2) + pow(self.predictedEndLocation.y,2))
	}
}
