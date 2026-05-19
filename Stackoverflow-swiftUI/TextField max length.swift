https://stackoverflow.com/questions/56476007/swiftui-textfield-max-length

class TextBindingManager: ObservableObject {
    @Published var text = "" {
        didSet {
            if text.count > characterLimit && oldValue.count <= characterLimit {
                text = oldValue
            }
        }
    }
    let characterLimit: Int

    init(limit: Int = 5){
        characterLimit = limit
    }
}

struct ContentView: View {
    @ObservedObject var textBindingManager = TextBindingManager(limit: 5)
    
    var body: some View {
        TextField("Placeholder", text: $textBindingManager.text)
    }
}
