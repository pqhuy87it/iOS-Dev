https://stackoverflow.com/questions/57441654/swiftui-repaint-view-components-on-device-rotation

@dfd provided two good options, I am adding a third one, which is the one I use.

In my case I subclass UIHostingController, and in function viewWillTransition, I post a custom notification.

Then, in my environment model I listen for such notification which can be then used in any view.

struct ContentView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Group {
            if model.landscape {
                Text("LANDSCAPE")
            } else {
                Text("PORTRAIT")
            }
        }
    }
}
In SceneDelegate.swift:

window.rootViewController = MyUIHostingController(rootView: ContentView().environmentObject(Model(isLandscape: windowScene.interfaceOrientation.isLandscape)))

My UIHostingController subclass:

extension Notification.Name {
    static let my_onViewWillTransition = Notification.Name("MainUIHostingController_viewWillTransition")
}

class MyUIHostingController<Content> : UIHostingController<Content> where Content : View {

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        NotificationCenter.default.post(name: .my_onViewWillTransition, object: nil, userInfo: ["size": size])
        super.viewWillTransition(to: size, with: coordinator)
    }

}
And my model:

class Model: ObservableObject {
    @Published var landscape: Bool = false

    init(isLandscape: Bool) {
        self.landscape = isLandscape // Initial value
        NotificationCenter.default.addObserver(self, selector: #selector(onViewWillTransition(notification:)), name: .my_onViewWillTransition, object: nil)
    }

    @objc func onViewWillTransition(notification: Notification) {
        guard let size = notification.userInfo?["size"] as? CGSize else { return }

        landscape = size.width > size.height
    }
}
