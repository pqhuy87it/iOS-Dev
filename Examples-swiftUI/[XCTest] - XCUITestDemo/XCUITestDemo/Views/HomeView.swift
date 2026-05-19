import SwiftUI

struct HomeView: View {
    let username: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome 👋")
                .font(.largeTitle)
                .accessibilityIdentifier("home.welcome.label")
            
            Text("Hello, \(username)")
                .font(.title2)
                .accessibilityIdentifier("home.username.label")
        }
        .navigationTitle("Home")
        .navigationBarBackButtonHidden(true)
    }
}
