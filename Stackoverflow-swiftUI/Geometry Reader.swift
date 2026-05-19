https://stackoverflow.com/questions/56729619/what-is-geometry-reader-in-swiftui

GeometryReader is a view that gives you access to the size and position of it's parent.

struct MyView: View {
    var body: some View {
        GeometryReader { geometry in
           // Here goes your view content,
           // and you can use the geometry variable
           // which contains geometry.size of the parent
           // You also have function to get the bounds
           // of the parent: geometry.frame(in: .global)
        }
    }
}

struct GeometryGetter: View {
    @Binding var rect: CGRect
    
    var body: some View {
        return GeometryReader { geometry in
            self.makeView(geometry: geometry)
        }
    }
    
    func makeView(geometry: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            self.rect = geometry.frame(in: .global)
        }

        return Rectangle().fill(Color.clear)
    }
}

struct MyView: View {
    @State private var rect: CGRect = CGRect()

    var body: some View {
        Text("some text").background(GeometryGetter($rect))

        // You can then use rect in other places of your view:
        Rectangle().frame(width: 100, height: rect.height)
    }
}
