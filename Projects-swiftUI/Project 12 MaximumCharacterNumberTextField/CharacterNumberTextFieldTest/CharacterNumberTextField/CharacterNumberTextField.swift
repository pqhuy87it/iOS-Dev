//
//  iPhoneNumberField.swift
//  iPhoneNumberField
//
//  Created by Seyed Mojtaba Hosseini Zeidabadi on 10/23/20.
//  Copyright © 2020 Chenzook. All rights reserved.
//
//  StackOverflow: https://stackoverflow.com/story/mojtabahosseini
//  Linkedin: https://linkedin.com/in/MojtabaHosseini
//  GitHub: https://github.com/MojtabaHs
//

import SwiftUI
//import PhoneNumberKit

/// A text field view representable structure that formats the user's phone number as they type.
public struct CharacterNumberTextField: UIViewRepresentable {
    
    /// The formatted phone number `String`.
    /// This variable writes to the binding provided in the initializer.
    @Binding public var text: String
    @State private var displayedText: String
    
    /// Whether or not the phone number field is editing.
    /// This variable is `nil` unless the user passes in an `isEditing` binding.
    private var externalIsFirstResponder: Binding<Bool>?

    /// Whether or not the phone number field is editing.
    /// This variable is used only if an `isEditing` binding was not provided in the initializer.
    @State private var internalIsFirstResponder: Bool = false

    /// Whether or not the phone number field is editing. 💬
    /// This variable uses `externalIsFirstResponder` binding variable if an `isEditing` binding was provided in the initializer, otherwise it uses the `internalIsFirstResponder` state variable.
    private var isFirstResponder: Bool {
        get { externalIsFirstResponder?.wrappedValue ?? internalIsFirstResponder }
        set {
            if externalIsFirstResponder != nil {
                externalIsFirstResponder!.wrappedValue = newValue
            } else {
                internalIsFirstResponder = newValue
            }
        }
    }

    /// The maximum number of digits the phone number field allows. 🔢
    internal var maxCharacters: Int?

    /// The font of the phone number field. 🔡
    internal var font: UIFont?

    /// The phone number field's "clear button" mode. 🚫
    internal var clearButtonMode: UITextField.ViewMode = .never

    /// The text displayed in the phone number field when no number has been typed yet.
    /// Setting this `nil` will display a default phone number as the placeholder.
    private let placeholder: String?

    /// Whether tapping the flag should show a sheet containing all of the country flags. 🏴‍☠️
    internal var selectableFlag: Bool = false

    /// Whether the country code should be automatically displayed for the end user. 🎓
    internal var previewPrefix: Bool = false

    /// Change the default prefix number by setting the region. 🇮🇷
    internal var defaultRegion: String?

    /// The color of the text of the phone number field. 🎨
    internal var textColor: UIColor?
    
    /// The color of the phone number field's cursor and highlighting. 🖍
    internal var accentColor: UIColor?

    /// The color of the number (excluding country code) portion of the placeholder.
    internal var numberPlaceholderColor: UIColor?

    /// The color of the country code portion of the placeholder color.
    internal var countryCodePlaceholderColor: UIColor?

    /// The visual style of the phone number field. 🎀
    /// For now, this uses `UITextField.BorderStyle`. Updates on this modifier to come.
    internal var borderStyle: UITextField.BorderStyle = .none

    /// An action to perform when editing on the phone number field begins. ▶️
    /// The closure requires a `PhoneNumberTextField` parameter, which is the underlying `UIView`, that you can change each time this is called, if desired.
    internal var onBeginEditingHandler = { (view: CustomTextField) in }

    /// An action to perform when any characters in the phone number field are changed. 💬
    /// The closure requires a `PhoneNumberTextField` parameter, which is the underlying `UIView`, that you can change each time this is called, if desired.
    internal var onEditingChangeHandler = { (view: CustomTextField) in }

    /// An action to perform when any characters in the phone number field are changed. ☎️
    /// The closure requires a `PhoneNumber` parameter, that you can change each time this is called, if desired.
    internal var onPhoneNumberChangeHandler = { (phoneNumber: CustomTextField?) in }

    /// An action to perform when editing on the phone number field ends. ⏹
    /// The closure requires a `PhoneNumberTextField` parameter, which is the underlying `UIView`, that you can change each time this is called, if desired.
    internal var onEndEditingHandler = { (view: CustomTextField) in }
    
    /// An action to perform when the phone number field is cleared. ❌
    /// The closure requires a `PhoneNumberTextField` parameter, which is the underlying `UIView`, that you can change each time this is called, if desired.
    internal var onClearHandler = { (view: CustomTextField) in }
    
    /// An action to perform when the return key on the phone number field is pressed. ↪️
    /// The closure requires a `PhoneNumberTextField` parameter, which is the underlying `UIView`, that you can change each time this is called, if desired.
    internal var onReturnHandler = { (view: CustomTextField) in }

    /// A closure that requires a `PhoneNumberTextField` object to be configured in the body. ⚙️
    public var configuration = { (view: CustomTextField) in }
    
    @Environment(\.layoutDirection) internal var layoutDirection: LayoutDirection
    /// The horizontal alignment of the phone number field.
    internal var textAlignment: NSTextAlignment?
    
    /// Whether the phone number field clears when editing begins. 🎬
    internal var clearsOnBeginEditing = false
    
    /// Whether the phone number field clears when text is inserted. 👆
    internal var clearsOnInsertion = false
    
    /// Whether the phone number field is enabled for interaction. ✅
    internal var isUserInteractionEnabled = true

    public init(_ title: String? = nil,
                text: Binding<String>,
                isEditing: Binding<Bool>? = nil,
                configuration: @escaping (UIViewType) -> () = { _ in } ) {

        self.placeholder = "sfsdffsfsdfds"
        self.externalIsFirstResponder = isEditing
        self._text = text
        self._displayedText = State(initialValue: text.wrappedValue)
        self.configuration = configuration
    }

    public func makeUIView(context: UIViewRepresentableContext<Self>) -> CustomTextField {
        let uiView = UIViewType()
        
        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        uiView.addTarget(context.coordinator,
                         action: #selector(Coordinator.textViewDidChange),
                         for: .editingChanged)
        uiView.delegate = context.coordinator
        uiView.withExamplePlaceholder = placeholder == nil
        
        return uiView
    }

    public func updateUIView(_ uiView: CustomTextField, context: UIViewRepresentableContext<Self>) {
        configuration(uiView)
        
        uiView.text = displayedText
        uiView.font = font
        uiView.maxCharacters = maxCharacters
        uiView.clearButtonMode = clearButtonMode
        uiView.placeholder = placeholder
        uiView.borderStyle = borderStyle
        uiView.textColor = textColor
        uiView.withExamplePlaceholder = placeholder == nil
        uiView.tintColor = accentColor

        if let textAlignment = textAlignment {
            uiView.textAlignment = textAlignment
        }

        if isFirstResponder {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
                    displayedText: $displayedText,
                    isFirstResponder: externalIsFirstResponder ?? $internalIsFirstResponder,
                    onBeginEditing: onBeginEditingHandler,
                    onEditingChange: onEditingChangeHandler,
                    onEndEditing: onEndEditingHandler,
                    onClear: onClearHandler,
                    onReturn: onReturnHandler)
    }

    public class Coordinator: NSObject, UITextFieldDelegate {
        internal init(
            text: Binding<String>,
            displayedText: Binding<String>,
            isFirstResponder: Binding<Bool>,
            onBeginEditing: @escaping (CustomTextField) -> () = { (view: CustomTextField) in },
            onEditingChange: @escaping (CustomTextField) -> () = { (view: CustomTextField) in },
            onEndEditing: @escaping (CustomTextField) -> () = { (view: CustomTextField) in },
            onClear: @escaping (CustomTextField) -> () = { (view: CustomTextField) in },
            onReturn: @escaping (CustomTextField) -> () = { (view: CustomTextField) in } )
        {
            self.text = text
            self.displayedText = displayedText
            self.isFirstResponder = isFirstResponder
            self.onBeginEditing = onBeginEditing
            self.onEditingChange = onEditingChange
            self.onEndEditing = onEndEditing
            self.onClear = onClear
            self.onReturn = onReturn
        }

        var text: Binding<String>
        var displayedText: Binding<String>
        var isFirstResponder: Binding<Bool>
		var isReturn: Bool = false

        var onBeginEditing = { (view: CustomTextField) in }
        var onEditingChange = { (view: CustomTextField) in }
        var onEndEditing = { (view: CustomTextField) in }
        var onClear = { (view: CustomTextField) in }
        var onReturn = { (view: CustomTextField) in }

        @objc public func textViewDidChange(_ textField: UITextField) {
            guard let textField = textField as? CustomTextField else {
                return assertionFailure("Undefined state")
            }
            
			text.wrappedValue = textField.text ?? ""
            
            displayedText.wrappedValue = textField.text ?? ""
            onEditingChange(textField)
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            isFirstResponder.wrappedValue = true
            onBeginEditing(textField as! CustomTextField)
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
			if isReturn {
				isReturn = false
			} else {
				isFirstResponder.wrappedValue = false
			}

            onEndEditing(textField as! CustomTextField)
        }
        
        public func textFieldShouldClear(_ textField: UITextField) -> Bool {
            displayedText.wrappedValue = ""
            onClear(textField as! CustomTextField)
            return true
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
			isReturn = true
			isFirstResponder.wrappedValue = false
            onReturn(textField as! CustomTextField)
            return true
        }

		public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
			return true
		}
    }
}
