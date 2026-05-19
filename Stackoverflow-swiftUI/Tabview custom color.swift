https://stackoverflow.com/questions/58353718/swiftui-tabview-tabitem-with-custom-font-does-not-work

init() {
 UITabBarItem.appearance().setTitleTextAttributes([NSAttributedString.Key.font: UIFont.init(name: "Avenir-Heavy", size: 15)! ], for: .normal)
}
