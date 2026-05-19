https://stackoverflow.com/questions/57244713/get-index-in-foreach-in-swiftui/57244880#57244880

Using Range and Count

struct ContentView: View {
    @State private var array = [1, 1, 2]

    func doSomething(index: Int) {
        self.array = [1, 2, 3]
    }
    
    var body: some View {
        ForEach(0..<array.count) { i in
          Text("\(self.array[i])")
            .onTapGesture { self.doSomething(index: i) }
        }
    }
}

Using Array's Indices

The indices property is a range of numbers.

struct ContentView: View {
    @State private var array = [1, 1, 2]

    func doSomething(index: Int) {
        self.array = [1, 2, 3]
    }
    
    var body: some View {
        ForEach(array.indices) { i in
          Text("\(self.array[i])")
            .onTapGesture { self.doSomething(index: i) }
        }
    }
}
