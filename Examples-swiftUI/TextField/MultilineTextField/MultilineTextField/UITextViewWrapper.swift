//
//  UITextViewWrapper.swift
//  MultilineTextField
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI
import UIKit

struct UITextViewWrapper: UIViewRepresentable {
	typealias UIViewType = UITextView

	@Binding var text: String
	@Binding var calculatedHeight: CGFloat
	var onDone: (() -> Void)?

	func makeUIView(context: UIViewRepresentableContext<UITextViewWrapper>) -> UITextView {
		let textField = UITextView()
		textField.delegate = context.coordinator

		textField.isEditable = true
		textField.font = UIFont.preferredFont(forTextStyle: .body)
		textField.isSelectable = true
		textField.isUserInteractionEnabled = true
		textField.isScrollEnabled = false
		textField.backgroundColor = UIColor.clear
		if nil != onDone {
			textField.returnKeyType = .done
		}

		textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		return textField
	}

	func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<UITextViewWrapper>) {
		if uiView.text != self.text {
			uiView.text = self.text
		}
		if uiView.window != nil, !uiView.isFirstResponder {
			uiView.becomeFirstResponder()
		}
		UITextViewWrapper.recalculateHeight(view: uiView, result: $calculatedHeight)
	}

	fileprivate static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
		let newSize = view.sizeThatFits(CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
		if result.wrappedValue != newSize.height {
			DispatchQueue.main.async {
				result.wrappedValue = newSize.height // !! must be called asynchronously
			}
		}
	}

	func makeCoordinator() -> Coordinator {
		return Coordinator(text: $text, height: $calculatedHeight, onDone: onDone)
	}

	final class Coordinator: NSObject, UITextViewDelegate {
		var text: Binding<String>
		var calculatedHeight: Binding<CGFloat>
		var onDone: (() -> Void)?

		init(text: Binding<String>, height: Binding<CGFloat>, onDone: (() -> Void)? = nil) {
			self.text = text
			self.calculatedHeight = height
			self.onDone = onDone
		}

		func textViewDidChange(_ uiView: UITextView) {
			text.wrappedValue = uiView.text
			UITextViewWrapper.recalculateHeight(view: uiView, result: calculatedHeight)
		}

		func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
			if let onDone = self.onDone, text == "\n" {
				textView.resignFirstResponder()
				onDone()
				return false
			}
			return true
		}
	}

}
