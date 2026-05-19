https://stackoverflow.com/questions/17678881/how-to-change-status-bar-text-color-in-ios?page=1&tab=votes#tab-top

For SwiftUI create a new swift file called HostingController.swift

import Foundation
import UIKit
import SwiftUI

class HostingController: UIHostingController<ContentView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

Then change the following lines of code in the SceneDelegate.swift

window.rootViewController = UIHostingController(rootView: ContentView())
to

window.rootViewController = HostingController(rootView: ContentView())
