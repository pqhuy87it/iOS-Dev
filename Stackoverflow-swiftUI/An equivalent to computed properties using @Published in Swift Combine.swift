https://stackoverflow.com/questions/58203531/an-equivalent-to-computed-properties-using-published-in-swift-combine

26

You don't need to do anything for computed properties that are based on @Published properties. You can just use it like this:

class UserManager: ObservableObject {
  @Published
  var currentUser: User?

  var userIsLoggedIn: Bool {
    currentUser != nil
  }
}

What happens in the @Published property wrapper of currentUser is that it will call objectWillChange.send() of the ObservedObject on changes. SwiftUI views don't care about which properties of @ObservedObjects have changed, it will just recalculate the view and redraw if necessary.

Working example:

class UserManager: ObservableObject {
  @Published
  var currentUser: String?

  var userIsLoggedIn: Bool {
    currentUser != nil
  }

  func logOut() {
    currentUser = nil
  }

  func logIn() {
    currentUser = "Demo"
  }
}
And a SwiftUI demo view:

struct ContentView: View {

  @ObservedObject
  var userManager = UserManager()

  var body: some View {
    VStack( spacing: 50) {
      if userManager.userIsLoggedIn {
        Text( "Logged in")
        Button(action: userManager.logOut) {
          Text("Log out")
        }
      } else {
        Text( "Logged out")
        Button(action: userManager.logIn) {
          Text("Log in")
        }
      }
    }
  }
}
