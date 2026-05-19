https://stackoverflow.com/questions/56961550/swiftui-placing-two-pickers-side-by-side-in-hstack-does-not-resize-pickers/56965246#56965246

struct ContentView: View {
    @State var selection1: Int = 0
    @State var selection2: Int = 0

    @State var integers: [Int] = [0, 1, 2, 3, 4, 5]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Picker(selection: self.$selection1, label: Text("Numbers")) {
                    ForEach(self.integers) { integer in
                        Text("\(integer)")
                    }
                }
                .frame(maxWidth: geometry.size.width / 2)
                .clipped()
                .border(Color.red)

                Picker(selection: self.$selection2, label: Text("Numbers")) {
                    ForEach(self.integers) { integer in
                        Text("\(integer)")
                    }
                }
                .frame(maxWidth: geometry.size.width / 2)
                .clipped()
                .border(Color.blue)
            }
        }
    }
}
