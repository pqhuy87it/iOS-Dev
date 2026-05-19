
import SwiftUI

struct ContentView: View {

	@State var index = 0

	var tabModels = [ TabModel(name: "Tab 1"),  TabModel(name: "Tab 2")]

    var body: some View {
		NavigationView {
			TabView(selection: $index) {
				TabViewContent(tabModel: self.tabModels[0])
					.tabItem {
						Label("Menu", systemImage: "list.dash")
					}

				TabViewContent(tabModel: self.tabModels[1])
					.tabItem {
						Label("Order", systemImage: "square.and.pencil")
					}
			}
			.navigationBarTitle("Property Wrapper", displayMode: .inline)
		}
		.navigationViewStyle(StackNavigationViewStyle())
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
