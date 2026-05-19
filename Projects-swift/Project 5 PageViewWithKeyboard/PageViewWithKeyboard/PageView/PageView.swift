
import SwiftUI

struct PageView<Page: View>: View {
    var pages: [Page]
	@Binding var currentPage: Int

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
            PageViewController(pages: pages, currentPage: $currentPage)
		}
	}
}
