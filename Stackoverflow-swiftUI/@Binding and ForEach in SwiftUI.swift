https://stackoverflow.com/questions/57340575/binding-and-foreach-in-swiftui/57340694#57340694

import SwiftUI

struct ContentView: View {
    @State private var boolArr = [false, false, true, true, false]

    var body: some View {
        List {
            ForEach(boolArr.indices) { idx in
                Toggle(isOn: self.$boolArr[idx]) {
                    Text("boolVar = \(self.boolArr[idx] ? "ON":"OFF")")
                }
            }
        }
    }
}
