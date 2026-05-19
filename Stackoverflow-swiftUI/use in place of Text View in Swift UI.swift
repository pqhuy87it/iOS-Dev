https://stackoverflow.com/questions/58354669/what-can-i-use-in-place-of-text-view-in-swift-ui

import SwiftUI
import Combine
struct ContentView: View {
    @ObservedObject private var restrictInput = RestrictInput(5)
    var body: some View {
        Form {
            TextField("input text", text: $restrictInput.text)
        }
    }
}

// https://stackoverflow.com/questions/57922766/how-to-use-combine-on-a-swiftui-view
class RestrictInput: ObservableObject {
    @Published var text = ""
    private var canc: AnyCancellable!
    init (_ maxLength: Int) {
        canc = $text
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .map { String($0.prefix(maxLength)) }
            .assign(to: \.text, on: self)
    }
    deinit {
        canc.cancel()
    }
}
