https://stackoverflow.com/questions/56492965/swiftui-is-there-a-popviewcontroller-equivalent-in-swiftui

import SwiftUI

struct ContentView: View {


    var body: some View {

        NavigationView {
            ZStack {
                Color.gray.opacity(0.2)

                NavigationLink(destination: NextView(), label: {Text("Go to Next View").font(.largeTitle)})
            }.navigationBarTitle(Text("This is Navigation"), displayMode: .large)
                .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct NextView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
        }.navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }, label: { Image(systemName: "arrow.left") }))
            .navigationBarTitle("", displayMode: .inline)
    }
}


struct NameRow: View {
    var name: String
    var body: some View {
        HStack {
            Image(systemName: "circle.fill").foregroundColor(Color.green)
            Text(name)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
