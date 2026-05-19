https://stackoverflow.com/questions/56491881/move-textfield-up-when-the-keyboard-has-appeared-in-swiftui/56721268#56721268

struct ContentView: View {
    @ObservedObject private var kGuardian = KeyboardGuardian(textFieldCount: 1)
    @State private var name = Array<String>.init(repeating: "", count: 3)

    var body: some View {

        VStack {
            Group {
                Text("Some filler text").font(.largeTitle)
                Text("Some filler text").font(.largeTitle)
            }

            TextField("enter text #1", text: $name[0])
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("enter text #2", text: $name[1])
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("enter text #3", text: $name[2])
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .background(GeometryGetter(rect: $kGuardian.rects[0]))

        }.offset(y: kGuardian.slide).animation(.easeInOut(duration: 1.0))
    }

}

Second Example (show only the active field)

struct ContentView: View {
    @ObservedObject private var kGuardian = KeyboardGuardian(textFieldCount: 3)
    @State private var name = Array<String>.init(repeating: "", count: 3)

    var body: some View {

        VStack {
            Group {
                Text("Some filler text").font(.largeTitle)
                Text("Some filler text").font(.largeTitle)
            }

            TextField("text #1", text: $name[0], onEditingChanged: { if $0 { self.kGuardian.showField = 0 } })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .background(GeometryGetter(rect: $kGuardian.rects[0]))

            TextField("text #2", text: $name[1], onEditingChanged: { if $0 { self.kGuardian.showField = 1 } })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .background(GeometryGetter(rect: $kGuardian.rects[1]))

            TextField("text #3", text: $name[2], onEditingChanged: { if $0 { self.kGuardian.showField = 2 } })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .background(GeometryGetter(rect: $kGuardian.rects[2]))

            }.offset(y: kGuardian.slide).animation(.easeInOut(duration: 1.0))
    }.onAppear { self.kGuardian.addObserver() } 
.onDisappear { self.kGuardian.removeObserver() }

}
