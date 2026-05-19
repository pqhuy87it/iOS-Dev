//
//  ContentView.swift
//  onReceiveJustExample
//
//  Created by mybkhn on 2021/06/30.
//

import SwiftUI
import Combine

struct ContentView: View {

	@State var messageText: String = ""

	@State var hasCapitalLetter: Bool = false
	@State var hasSymbol: Bool = false
	@State var lengthExceeds16: Bool = false

	var body: some View {

		Form {
			TextField("メッセージ", text: $messageText)
				.onReceive(Just(messageText)) { _ in
					self.lengthExceeds16 = (messageText.count > 16)
					// 大文字
					let capitalLetterExpression  = ".*[A-Z]+.*"
					let capitalLetterCondition = NSPredicate(format:"SELF MATCHES %@", capitalLetterExpression)
					self.hasCapitalLetter = capitalLetterCondition.evaluate(with: messageText)
					// 数字: ".*[0-9]+.*"
					// 符号
					let symbolExpression  = ".*[!&^%$#@()/]+.*"
					let symbolCondition = NSPredicate(format:"SELF MATCHES %@", symbolExpression)
					self.hasSymbol = symbolCondition.evaluate(with: messageText)
				}
				.padding()
			// ユーザーによるパスワード入力をご希望の場合は、`SecureField` をご利用下さい。
			Text(String(messageText.count))
				.keyboardType(.asciiCapable)
				.autocapitalization(.none)
				.disableAutocorrection(true)
			// パスワード 条件
			PasswordConditionDisplay(isConditionMet: $hasCapitalLetter, conditionName: "大文字")
			PasswordConditionDisplay(isConditionMet: $hasSymbol, conditionName: "符号")
			PasswordConditionDisplay(isConditionMet: $lengthExceeds16, conditionName: "パスワードは16文字を越える必要があります")
		}

	}

}
