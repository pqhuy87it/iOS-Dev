//
//  PhoneNumberTextField.swift
//  PhoneNumberKit
//
//  Created by Roy Marmelstein on 07/11/2015.
//  Copyright © 2021 Roy Marmelstein. All rights reserved.
//

#if canImport(UIKit)

import Foundation
import UIKit

/// Custom text field that formats phone numbers
open class CustomTextField: UITextField, UITextFieldDelegate {

	/// Override setText so number will be automatically formatted when setting text by code
	open override var text: String? {
		set {
			super.text = newValue

			NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: self)
		}
		get {
			return super.text
		}
	}

	/// allows text to be set without formatting
	open func setTextUnformatted(newValue: String?) {
		super.text = newValue
	}

	public var withExamplePlaceholder: Bool = false {
		didSet {
			attributedPlaceholder = nil
		}
	}

	public var maxCharacters: Int?

	let numbericLetterSet: NSCharacterSet = {
		var mutableSet = NSMutableCharacterSet.letter().inverted
		mutableSet.remove(charactersIn: "0123456789")
		return mutableSet as NSCharacterSet
	}()

	private weak var _delegate: UITextFieldDelegate?

	open override var delegate: UITextFieldDelegate? {
		get {
			return self._delegate
		}
		set {
			self._delegate = newValue
		}
	}

	// MARK: Status

	open override func layoutSubviews() {
		super.layoutSubviews()
	}

	// MARK: Lifecycle


	/**
	Init with frame and phone number kit instance.

	- parameter frame: UITextfield frame
	- parameter phoneNumberKit: A PhoneNumberKit instance to be used by the text field.

	- returns: UITextfield
	*/
	public override init(frame: CGRect) {
		super.init(frame: frame)
		self.setup()
	}


	/**
	Init with coder

	- parameter aDecoder: decoder

	- returns: UITextfield
	*/
	public required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)!
		self.setup()
	}

	func setup() {
		self.autocorrectionType = .no
		self.keyboardType = .phonePad
		super.delegate = self
	}


	// MARK: Phone number formatting

	/**
	*  To keep the cursor position, we find the character immediately after the cursor and count the number of times it repeats in the remaining string as this will remain constant in every kind of editing.
	*/

	internal struct CursorPosition {
		let numberAfterCursor: String
		let repetitionCountFromEnd: Int
	}

	internal func extractCursorPosition() -> CursorPosition? {
		var repetitionCountFromEnd = 0
		// Check that there is text in the UITextField
		guard let text = text, let selectedTextRange = selectedTextRange else {
			return nil
		}
		let textAsNSString = text as NSString
		let cursorEnd = offset(from: beginningOfDocument, to: selectedTextRange.end)
		// Look for the next valid number after the cursor, when found return a CursorPosition struct
		for i in cursorEnd..<textAsNSString.length {
			let cursorRange = NSRange(location: i, length: 1)
			let candidateNumberAfterCursor: NSString = textAsNSString.substring(with: cursorRange) as NSString
			if candidateNumberAfterCursor.rangeOfCharacter(from: self.numbericLetterSet as CharacterSet).location == NSNotFound {
				for j in cursorRange.location..<textAsNSString.length {
					let candidateCharacter = textAsNSString.substring(with: NSRange(location: j, length: 1))
					if candidateCharacter == candidateNumberAfterCursor as String {
						repetitionCountFromEnd += 1
					}
				}
				return CursorPosition(numberAfterCursor: candidateNumberAfterCursor as String, repetitionCountFromEnd: repetitionCountFromEnd)
			}
		}
		return nil
	}

	// Finds position of previous cursor in new formatted text
	internal func selectionRangeForNumberReplacement(textField: UITextField, formattedText: String) -> NSRange? {
		let textAsNSString = formattedText as NSString
		var countFromEnd = 0
		guard let cursorPosition = extractCursorPosition() else {
			return nil
		}

		for i in stride(from: textAsNSString.length - 1, through: 0, by: -1) {
			let candidateRange = NSRange(location: i, length: 1)
			let candidateCharacter = textAsNSString.substring(with: candidateRange)
			if candidateCharacter == cursorPosition.numberAfterCursor {
				countFromEnd += 1
				if countFromEnd == cursorPosition.repetitionCountFromEnd {
					return candidateRange
				}
			}
		}

		return nil
	}

	public func calculateMaximumCharacter(_ input: String) -> String {
		var result = input

		if let maxCharacters = maxCharacters {
			let extra = input.count - maxCharacters

			if extra > 0 {
				result = String(input.dropLast(extra))
			}
		}

		return result
	}

	open func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		// This allows for the case when a user autocompletes a phone number:
		if range == NSRange(location: 0, length: 0) && string.isBlank {
			return true
		}

		guard let text = text else {
			return false
		}

		// allow delegate to intervene
		guard self._delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true else {
			return false
		}

		let textAsNSString = text as NSString
		let changedRange = textAsNSString.substring(with: range) as NSString
		let modifiedTextField = textAsNSString.replacingCharacters(in: range, with: string)

		let filteredCharacters = modifiedTextField.filter {
			String($0).rangeOfCharacter(from: (textField as! CustomTextField).numbericLetterSet as CharacterSet) == nil
		}
		let rawNumberString = String(filteredCharacters)

		let formattedNationalNumber = (calculateMaximumCharacter(rawNumberString) as String)
		var selectedTextRange: NSRange?

		let nonNumericRange = (changedRange.rangeOfCharacter(from: self.numbericLetterSet as CharacterSet).location != NSNotFound)

		if range.length == 1, string.isEmpty, nonNumericRange {
			selectedTextRange = self.selectionRangeForNumberReplacement(textField: textField, formattedText: modifiedTextField)
			textField.text = modifiedTextField
		} else {
			selectedTextRange = self.selectionRangeForNumberReplacement(textField: textField, formattedText: formattedNationalNumber)
			textField.text = formattedNationalNumber
		}

		sendActions(for: .editingChanged)

		if let selectedTextRange = selectedTextRange, let selectionRangePosition = textField.position(from: beginningOfDocument, offset: selectedTextRange.location) {
			let selectionRange = textField.textRange(from: selectionRangePosition, to: selectionRangePosition)
			textField.selectedTextRange = selectionRange
		}

		return false
	}

	// MARK: UITextfield Delegate

	open func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
		return self._delegate?.textFieldShouldBeginEditing?(textField) ?? true
	}

	open func textFieldDidBeginEditing(_ textField: UITextField) {
		self._delegate?.textFieldDidBeginEditing?(textField)
	}

	open func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
		return self._delegate?.textFieldShouldEndEditing?(textField) ?? true
	}

	open func textFieldDidEndEditing(_ textField: UITextField) {
		updateTextFieldDidEndEditing(textField)
		self._delegate?.textFieldDidEndEditing?(textField)
	}

	@available (iOS 10.0, tvOS 10.0, *)
	open func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
		updateTextFieldDidEndEditing(textField)
		if let _delegate = _delegate {
			if (_delegate.responds(to: #selector(textFieldDidEndEditing(_:reason:)))) {
				_delegate.textFieldDidEndEditing?(textField, reason: reason)
			} else {
				_delegate.textFieldDidEndEditing?(textField)
			}
		}
	}

	open func textFieldShouldClear(_ textField: UITextField) -> Bool {
		return self._delegate?.textFieldShouldClear?(textField) ?? true
	}

	open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		return self._delegate?.textFieldShouldReturn?(textField) ?? true
	}

	private func updateTextFieldDidEndEditing(_ textField: UITextField) {
		if self.withExamplePlaceholder,
		   let text = textField.text {
//		   text == internationalPrefix(for: countryCode) {
			textField.text = ""
			sendActions(for: .editingChanged)
		}
	}
}

extension String {
	var isBlank: Bool {
		return allSatisfy({ $0.isWhitespace })
	}
}

#endif
