import SwiftUI
import Combine

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("ExampleView1") {
                        ExampleView1()
                    }
                    
                    NavigationLink("ExampleView2") {
                        ExampleView2()
                    }
                } header: {
                    Text("Basic")
                }
                
                Section {
                    NavigationLink("ExampleView3") {
                        ExampleView3()
                    }
                    
                    NavigationLink("ExampleView4") {
                        ExampleView4()
                    }
                } header: {
                    Text("Advanced")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
