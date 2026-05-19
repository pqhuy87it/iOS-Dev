https://stackoverflow.com/questions/64223276/how-to-set-textfield-character-limit-swiftui

import SwiftUI

struct ContentView: View {
    @ObservedObject var textBindingManager = TextBindingManager(limit: 5)
    var body: some View {
        TextField("Placeholder", text: $textBindingManager.phoneNumber)
            .padding()
            .onChange(of: textBindingManager.phoneNumber, perform: editingChanged)
    }
    func editingChanged(_ value: String) {
        textBindingManager.phoneNumber = String(value.prefix(textBindingManager.characterLimit))
    }
}

class TextBindingManager: ObservableObject {
    let characterLimit: Int
    @Published var phoneNumber = ""
    init(limit: Int = 10){
        characterLimit = limit
    }
}
