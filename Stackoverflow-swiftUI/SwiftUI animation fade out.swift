https://stackoverflow.com/questions/56680017/this-swiftui-animation-should-only-fade-out-why-does-it-move-to-the-right/56684369#56684369

import SwiftUI

struct ContentView : View {
    @State private var showText = true

    var body: some View {
        VStack {
            Spacer()

            if showText {
                Text("I should always be centered!").font(.largeTitle).transition(.opacity).border(Color.blue)
            }

            Spacer()

            Button(action: {
                withAnimation(.basic(duration: 1.5)) { self.showText.toggle() }
            }, label: {
                Text("CHANGE").font(.title).border(Color.blue)
            })

            Spacer()

            // This ensures the parent is kept wide to avoid the shift
            HStack { Spacer() }

        }.border(Color.green)
    }
}

![](https://i.stack.imgur.com/qK5hA.gif)
