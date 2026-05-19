https://stackoverflow.com/questions/57875550/how-to-detect-live-changes-on-textfield-in-swiftui/57875903#57875903

struct ContentView: View {
    @State var location: String = ""

    var body: some View {
        let binding = Binding<String>(get: {
            self.location
        }, set: {
            self.location = $0
            // do whatever you want here
        })

        return VStack {
            Text("Current location: \(location)")
            TextField("Search Location", text: binding)
        }

    }
}

