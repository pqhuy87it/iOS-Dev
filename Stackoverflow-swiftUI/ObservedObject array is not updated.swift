https://stackoverflow.com/questions/57459727/why-an-observedobject-array-is-not-updated-in-my-swiftui-application/57459844#57459844

You can use a struct instead of a class. Because of a struct's value semantics, a change to a person's name is seen as a change to Person struct itself, and this change is also a change to the people array so @Published will send the notification and the View body will be recomputed.

import Foundation
import SwiftUI
import Combine

struct Person: Identifiable{
    var id: Int
    var name: String

    init(id: Int, name: String){
        self.id = id
        self.name = name
    }

}

class Model: ObservableObject{
    @Published var people: [Person]

    init(){
        self.people = [
            Person(id: 1, name:"Javier"),
            Person(id: 2, name:"Juan"),
            Person(id: 3, name:"Pedro"),
            Person(id: 4, name:"Luis")]
    }

}

struct ContentView: View {
    @StateObject var model = Model()

    var body: some View {
        VStack{
            ForEach(model.people){ person in
                Text("\(person.name)")
            }
            Button(action: {
                self.mypeople.people[0].name="Jaime"
            }) {
                Text("Add/Change name")
            }
        }
    }
}

Alternatively (and not recommended), Person is a class, so it is a reference type. 
When it changes, the People array remains unchanged and so nothing is emitted by the subject. 
However, you can manually call it, to let it know:

Button(action: {
    self.mypeople.objectWillChange.send()
    self.mypeople.people[0].name="Jaime"    
}) {
    Text("Add/Change name")
}
