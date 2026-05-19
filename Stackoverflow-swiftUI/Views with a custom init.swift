https://stackoverflow.com/questions/56910854/swiftui-views-with-a-custom-init/56911273#56911273

struct CustomInput : View {
    @Binding var text: String
    var name: String

    init(_ name: String, _ text: Binding<String>) {
        self.name = name

        // Beta 3
        // self.$text = text

        // Beta 4
        self._text = text
    }

    var body: some View {
        TextField(name, text: $text)
    }
}
