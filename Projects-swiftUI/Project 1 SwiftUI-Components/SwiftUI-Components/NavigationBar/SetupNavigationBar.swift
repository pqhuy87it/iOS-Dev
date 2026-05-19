//
//  SetupNavigationBar.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct SetupNavigationBar: View {
	init() {
		self.setupApperance()
	}

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }

	private func setupApperance() {
		UINavigationBar.appearance().largeTitleTextAttributes = [
			NSAttributedString.Key.foregroundColor: UIColor.red,
			NSAttributedString.Key.font: UIFont.systemFont(ofSize: 40)]

		UINavigationBar.appearance().titleTextAttributes = [
			NSAttributedString.Key.foregroundColor: UIColor.blue,
			NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18)]

		UIBarButtonItem.appearance().setTitleTextAttributes([
																NSAttributedString.Key.foregroundColor: UIColor.red,
																NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)],
															for: .normal)

		UIWindow.appearance().tintColor = UIColor.blue
	}
}

struct SetupNavigationBar_Previews: PreviewProvider {
    static var previews: some View {
        SetupNavigationBar()
    }
}
