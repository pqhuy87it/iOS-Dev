//
//  StackView3.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/06/22.
//

import SwiftUI

struct StackView3: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
//		createView1()
//		createView2()
		createView3()
//		createView4()
//		createView5()
//		createView6()
//		createView7()
//		createView8()
    }

	// MARK: - Build Views

	func createView1() -> some View {
		VStack {
			Text("Hello world!")
				.padding()
				.background(Color.red)

			Spacer()
		}
	}

	func createView2() -> some View {
		VStack {
			Spacer()

			Text("Hello world!")
				.padding()
				.background(Color.red)
		}
	}

	func createView3() -> some View {
		HStack {
			VStack {
				Text("Hello world!")
					.padding()
					.background(Color.red)

				Spacer()
			}

			Spacer()
		}
		.padding()
	}

	func createView4() -> some View {
		HStack {
			VStack {
				Spacer()

				Text("Hello world!")
					.padding()
					.background(Color.red)
			}

			Spacer()
		}
		.padding()
	}

	func createView5() -> some View {
//		HStack(alignment: .top) {
		HStack {
			VStack {
				Text("Hello world!")
					.padding()
					.background(Color.red)

				Spacer()
			}

			Text("SwiftUI!")
				.padding()
				.background(Color.blue)

			Spacer()
		}
		.padding()
	}

	func createView6() -> some View {
		HStack(alignment: .top) {
			VStack {
				Text("Hello world!")
					.padding()
					.background(Color.red)

				Spacer()
			}

			VStack(alignment: .leading) {
				Text("SwiftUI!")
					.padding()
					.background(Color.blue)
			}

			Spacer()
		}
		.padding()
	}

	func createView7() -> some View {
		HStack(spacing: 15) {
			Text("Hello world!")
				.padding()
				.background(Color.red)

			VStack(alignment: .leading) {
				Text("Event title").font(.title)
				Text("Location")
			}
			Spacer()
		}
	}

	func createView8() -> some View {
		ZStack(alignment: .topTrailing) {
			Text("Hello world!")
				.padding()
				.background(Color.red)
				.offset(x: 3, y: -3)
		}
	}
}

struct StackView3_Previews: PreviewProvider {
    static var previews: some View {
        StackView3()
    }
}
