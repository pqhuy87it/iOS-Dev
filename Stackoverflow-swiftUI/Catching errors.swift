https://stackoverflow.com/questions/63621431/catching-errors-in-swiftui

@State private var isError = false
...
Button(action: {
    do {
        try self.taskViewModel.createInstance(name: self.name)
    } catch DatabaseError.CanNotBeScheduled {
        // do something else specific here
        self.isError = true
    } catch {
        self.isError = true
    }
}) {
    Text("Save")
}
 .alert(isPresented: $isError) {
    Alert(title: Text("Can't be scheduled"),
          message: Text("Try changing the name"),
          dismissButton: .default(Text("OK")))
}
