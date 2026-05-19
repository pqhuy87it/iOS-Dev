https://stackoverflow.com/questions/57518852/swiftui-picker-onchange-or-equivalent

iOS 13

struct MyPicker: View {
    @State private var favoriteColor = 0

    var body: some View {
        Picker(selection: $favoriteColor.onChange(colorChange), label: Text("Color")) {
            Text("Red").tag(0)
            Text("Green").tag(1)
            Text("Blue").tag(2)
        }
    }

    func colorChange(_ tag: Int) {
        print("Color tag: \(tag)")
    }
}

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        return Binding(
            get: { self.wrappedValue },
            set: { selection in
                self.wrappedValue = selection
                handler(selection)
        })
    }
}

iOS 14

Picker(selection: $favoriteColor, label: Text("Color")) {
    // ..
}
.onChange(of: favoriteColor) { tag in print("Color tag: \(tag)") }
