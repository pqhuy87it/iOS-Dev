https://stackoverflow.com/questions/57922766/how-to-use-combine-on-a-swiftui-view

class TestViewModel : ObservableObject {
    @Published var myproperty = MyPropertyStruct(text: "initialText")
    private var saveCanc: AnyCancellable!
    private var updateCanc: AnyCancellable!

    init() {
        saveCanc = $myproperty.debounce(for: 0.5, scheduler: DispatchQueue.main)
            .map { [unowned self] in self.cleanText(text: $0.text) }
            .sink { [unowned self] newText in
            self.saveTextToFile(text: self.cleanText(text: newText))
        }

        updateCanc = $myproperty.sink { [unowned self] newText in
            let strToSave = self.cleanText(text: newText.text)
            if strToSave != newText.text {
                //a cleaning has actually happened, so we must change our text to reflect the cleaning
                DispatchQueue.main.async {
                    self.myproperty.text = strToSave
                }
            }
        }
    }

    deinit {
        saveCanc.cancel()
        updateCanc.cancel()
    }

    private func cleanText(text: String) -> String {
        //remove all the spaces
        let resultStr = String(text.unicodeScalars.filter {
            $0 != " "
        })

        //take up to 5 characters
        return String(resultStr.prefix(5))
    }

    private func saveTextToFile(text: String) {
        print("text saved: \(text)")
    }
}
