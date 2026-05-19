//
//  MyForm.swift
//  Advanced SwiftUI Transitions
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct MyForm: View {
	@Binding var show: Bool

	@State private var departure = Date()
	@State private var checkin = Date()

	@State private var pets = true
	@State private var nonsmoking = true
	@State private var airport: Double = 7.3

	var body: some View {

		VStack {
			Text("Booking").font(.title).foregroundColor(.white)

			Form {
				DatePicker(selection: $departure, label: {
					HStack {
						Image(systemName: "airplane")
						Text("Departure")
					}
				})

				DatePicker(selection: $checkin, label: {
					HStack {
						Image(systemName: "house.fill")
						Text("Check-In")
					}
				})

				Toggle(isOn: $pets, label: { HStack { Image(systemName: "hare.fill"); Text("Have Pets") } })
				Toggle(isOn: $nonsmoking, label: { HStack { Image(systemName: "nosign"); Text("Non-Smoking") } })
				Text("Max Distance to Airport \(String(format: "%.2f", self.airport as Double)) km")
				Slider(value: $airport, in: 0...10) { EmptyView() }

				Button(action: {
					withAnimation(.easeInOut(duration: 1.0)) {
						self.show = false
					}
				}) {
					HStack { Spacer(); Text("Save"); Spacer() }
				}

			}
		}.padding(20)
	}
}
