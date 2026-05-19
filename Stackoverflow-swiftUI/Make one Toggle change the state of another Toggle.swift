https://stackoverflow.com/questions/57699548/using-swiftui-how-do-i-make-one-toggle-change-the-state-of-another-toggle/57702713#57702713

struct Junk: View {

    @State private var isOn1:Bool = true
    @State private var isOn2:Bool = false
    @State private var isOn3:Bool = false

    var body: some View
    {
        let on1 = Binding<Bool>(get: { self.isOn1 }, set: { self.isOn1 = $0; self.isOn2 = false; self.isOn3 = false })
        let on2 = Binding<Bool>(get: { self.isOn2 }, set: { self.isOn1 = false; self.isOn2 = $0; self.isOn3 = false })
        let on3 = Binding<Bool>(get: { self.isOn3 }, set: { self.isOn1 = false; self.isOn2 = false; self.isOn3 = $0 })        

        return VStack
            {
                Toggle("T1", isOn: on1)
                Toggle("T2", isOn: on2)
                Toggle("T3", isOn: on3)
        }
    }
}
