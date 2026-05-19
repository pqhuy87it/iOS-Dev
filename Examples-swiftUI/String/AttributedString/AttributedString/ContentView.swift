//
//  ContentView.swift
//  AttributedString
//
//  Created by mybkhn on 2021/02/03.
//

import SwiftUI

extension Text {
	init(_ astring: NSAttributedString) {
		self.init("")

		astring.enumerateAttributes(in: NSRange(location: 0, length: astring.length), options: []) { (attrs, range, _) in

			var t = Text(astring.attributedSubstring(from: range).string)

			if let color = attrs[NSAttributedString.Key.foregroundColor] as? UIColor {
				t  = t.foregroundColor(Color(color))
			}

			if let font = attrs[NSAttributedString.Key.font] as? UIFont {
				t  = t.font(.init(font))
			}

			if let kern = attrs[NSAttributedString.Key.kern] as? CGFloat {
				t  = t.kerning(kern)
			}


			if let striked = attrs[NSAttributedString.Key.strikethroughStyle] as? NSNumber, striked != 0 {
				if let strikeColor = (attrs[NSAttributedString.Key.strikethroughColor] as? UIColor) {
					t = t.strikethrough(true, color: Color(strikeColor))
				} else {
					t = t.strikethrough(true)
				}
			}

			if let baseline = attrs[NSAttributedString.Key.baselineOffset] as? NSNumber {
				t = t.baselineOffset(CGFloat(baseline.floatValue))
			}

			if let underline = attrs[NSAttributedString.Key.underlineStyle] as? NSNumber, underline != 0 {
				if let underlineColor = (attrs[NSAttributedString.Key.underlineColor] as? UIColor) {
					t = t.underline(true, color: Color(underlineColor))
				} else {
					t = t.underline(true)
				}
			}

			self = self + t

		}
	}
}

struct AttributedText: View {
	@State private var size: CGSize = .zero
	let attributedString: NSAttributedString

	init(_ attributedString: NSAttributedString) {
		self.attributedString = attributedString
	}

	var body: some View {
		AttributedTextRepresentable(attributedString: attributedString, size: $size)
			.frame(width: size.width, height: size.height)
	}

	struct AttributedTextRepresentable: UIViewRepresentable {

		let attributedString: NSAttributedString
		@Binding var size: CGSize

		func makeUIView(context: Context) -> UILabel {
			let label = UILabel()

			label.lineBreakMode = .byClipping
			label.numberOfLines = 0

			return label
		}

		func updateUIView(_ uiView: UILabel, context: Context) {
			uiView.attributedText = attributedString

			DispatchQueue.main.async {
				size = uiView.sizeThatFits(uiView.superview?.bounds.size ?? .zero)
			}
		}
	}
}

struct ContentView: View {
	let myAttributedString: NSMutableAttributedString = {

		let a1: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.systemRed, .kern: 5]
		let s1 = NSMutableAttributedString(string: "Red spaced ", attributes: a1)

		let a2: [NSAttributedString.Key: Any] = [.strikethroughStyle: 1, .strikethroughColor: UIColor.systemBlue]
		let s2 = NSAttributedString(string: "strike through", attributes: a2)

		let a3: [NSAttributedString.Key: Any] = [.baselineOffset: 10]
		let s3 = NSAttributedString(string: " raised ", attributes: a3)

		let a4: [NSAttributedString.Key: Any] = [.font: UIFont(name: "Papyrus", size: 36.0)!, .foregroundColor: UIColor.green]
		let s4 = NSAttributedString(string: " papyrus font ", attributes: a4)

		let a5: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.systemBlue, .underlineStyle: 1, .underlineColor: UIColor.systemRed]
		let s5 = NSAttributedString(string: "underlined ", attributes: a5)

		s1.append(s2)
		s1.append(s3)
		s1.append(s4)
		s1.append(s5)

		return s1
	}()

    var body: some View {
		AttributedText(myAttributedString)
			.padding(10)
			.border(Color.black)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
