https://www.hackingwithswift.com/forums/100-days-of-swiftui/how-do-i-restrict-textview-input-to-a-certain-number-of-characters/763

class TextBindingManager: ObservableObject {
    @Published var text = "" {
        didSet {
            if text.count > characterLimit && oldValue.count <= characterLimit {
                text = oldValue
            }
        }
    }
    let characterLimit: Int

    init(limit: Int = 1){
        characterLimit = limit
    }
}

struct CharacterInputCell: View {
    @ObservedObject var textBindingManager = TextBindingManager(limit: 1)

    var body: some View {
        TextField("", text: $textBindingManager.text, onEditingChanged: onEditingChanged(_:), onCommit: onCommit)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding([.trailing, .leading], 10)
        .padding([.vertical], 15)
        .lineLimit(1)
        .multilineTextAlignment(.center)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.red.opacity(0.5), lineWidth: 2)
        )
    }

    func onCommit() {
        print("commit")
    }

    func onEditingChanged(_ changed: Bool) {
        print(changed)
    }
}

-------------------------

import SwiftUI
import Combine

struct PassCodeInputCell: View {

    @Binding var value: String

    var body: some View {
        TextField("", text: self.$value)
        .frame(height: 20)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding([.trailing, .leading], 10)
        .padding([.vertical], 15)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.red.opacity(0.5), lineWidth: 2)
        )
        .onReceive(Just(self.value)) { inputValue in
            // With a little help from https://bit.ly/2W1Ljzp
            if inputValue.count > 1 {
                self.value.removeLast()
            }
        }
    }
}

struct PassCodeInputCell_Previews: PreviewProvider {
    static var previews: some View {
        PassCodeInputCell(value: .constant("T"))
    }
}
