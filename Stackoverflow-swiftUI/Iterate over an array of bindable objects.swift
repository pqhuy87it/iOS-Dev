https://stackoverflow.com/questions/57161893/swiftui-how-to-iterate-over-an-array-of-bindable-objects

import SwiftUI
import Combine

class Project: ObservableObject, Identifiable {
    var id: String = UUID().uuidString
    @Published var title: String = ""

    init (title: String) {
        self.title = title
    }
}

class AppState: ObservableObject {
    @Published var projects: [Project] = []
    init(_ projects: [Project]) {
        self.projects = projects
    }
}

struct ProjectView: View {
  @ObservedObject var project: Project
  @State var projectName: String = ""

  var body: some View {
    VStack {
      Text(project.title)
      TextField("Change project name",
        text: $projectName,
        onCommit: {
          self.project.title = self.projectName
          self.projectName = ""
      })
      .padding()
    }
  }
}

struct ContentView: View {
    @ObservedObject var state: AppState = AppState([Project(title: "1"), Project(title: "2")])
    @State private var refreshed = false

    var body: some View {
        NavigationView {
            List {
                ForEach(state.projects) { project in
                  NavigationLink(destination: ProjectView(project: project)) {
                    // !!!  existance of .refreshed state property somewhere in ViewBuilder
                    //      is important to inavidate view, so below is just a demo
                    Text("Named: \(self.refreshed ? project.title : project.title)")
                  }
                  .onReceive(project.$title) { _ in
                        self.refreshed.toggle()
                    }
                }
            }
            .navigationBarTitle("Projects")
            .navigationBarItems(trailing: Button(action: {
                self.state.projects.append(Project(title: "Unknown"))
            }) {
                Text("New")
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
