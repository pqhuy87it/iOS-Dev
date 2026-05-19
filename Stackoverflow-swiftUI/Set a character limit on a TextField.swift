https://stackoverflow.com/questions/59825418/is-it-possible-to-set-a-character-limit-on-a-textfield-using-swiftui

@State var text = ""

  var body: some View {
    TextField("text", text: $text)
      .onReceive(text.publisher.collect()) {
        self.text = String($0.prefix(5))
    }
  }
