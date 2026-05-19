
import SwiftUI

struct GuideView: View {

	@State var lineWidth: CGFloat = 0
	@State var scale: CGFloat = 0.0
	@State var strokeColor: Color = Color.red

	var body: some View {
		ZStack {
			let style = StrokeStyle(lineWidth: lineWidth,
									lineCap: .round,
									lineJoin: .round)
			GuidePath(scale: scale)
				.stroke(strokeColor, style: style)
		}
	}
}

struct GuidePath: Shape {

	@State var scale: CGFloat = 0.0

	func path(in rect: CGRect) -> Path {
		Path { path in
			path.addLines([
				.zero,
				CGPoint(x: rect.width / scale, y: 0)
			])

			path.addLines([
				.zero,
				CGPoint(x: 0, y: rect.width / scale)
			])

			path.addLines([
				CGPoint(x: ((scale - 1) / scale) * rect.width, y: 0),
				CGPoint(x: rect.width, y: 0)
			])

			path.addLines([
				CGPoint(x: rect.width, y: 0),
				CGPoint(x: rect.width, y: rect.width / scale)
			])

			path.addLines([
				CGPoint(x: 0, y: rect.height - (1 / scale) * rect.width),
				CGPoint(x: 0, y: rect.height)
			])

			path.addLines([
				CGPoint(x: 0, y: rect.height),
				CGPoint(x: rect.width / scale, y: rect.height)
			])

			path.addLines([
				CGPoint(x: ((scale - 1) / scale) * rect.width, y: rect.height),
				CGPoint(x: rect.width, y: rect.height)
			])

			path.addLines([
				CGPoint(x: rect.width, y: rect.height - (1 / scale) * rect.width),
				CGPoint(x: rect.width, y: rect.height)
			])
		}
	}
}

struct GuideView_Previews: PreviewProvider {
	static var previews: some View {
		GuideView()
	}
}
