https://stackoverflow.com/questions/56517400/swiftui-dismiss-modal

Using @State property wrapper (recommended)

struct ContentView: View {
    @State private var showModal = false
    
    var body: some View {
       Button("Show Modal") {
          self.showModal.toggle()
       }.sheet(isPresented: $showModal) {
            ModalView(showModal: self.$showModal)
        }
    }
}

struct ModalView: View {
    @Binding var showModal: Bool
    
    var body: some View {
        Text("Modal view")
        Button("Dismiss") {
            self.showModal.toggle()
        }
    }
}

Using presentationMode

You can use presentationMode environment variable in your modal view and calling self.presentaionMode.wrappedValue.dismiss() to dismiss the modal:

struct ContentView: View {

  @State private var showModal = false

  // If you are getting the "can only present once" issue, add this here.
  // Fixes the problem, but not sure why; feel free to edit/explain below.
  @Environment(\.presentationMode) var presentationMode


  var body: some View {
    Button(action: {
        self.showModal = true
    }) {
        Text("Show modal")
    }.sheet(isPresented: self.$showModal) {
        ModalView()
    }
  }
}


struct ModalView: View {

  @Environment(\.presentationMode) private var presentationMode

  var body: some View {
    Group {
      Text("Modal view")
      Button(action: {
         self.presentationMode.wrappedValue.dismiss()
      }) {
        Text("Dismiss")
      }
    }
  }
}
