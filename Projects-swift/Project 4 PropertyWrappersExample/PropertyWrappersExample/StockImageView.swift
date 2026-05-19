
import SwiftUI

struct StockImageView: View {
	@State private var isOpenCamera = false

	@ObservedObject var stockModel: StockModel

    var body: some View {
		VStack {
			Text(stockModel.name)

			if let image = self.stockModel.stockImage.image {
				ZStack {
					Image(uiImage: image)
						.resizable()
						.padding()

					Button(action: {
						self.stockModel.stockImage.image = nil
					}) {
						Image(systemName: "xmark")
							.resizable()
							.frame(width: 40, height: 40)
							.foregroundColor(/*@START_MENU_TOKEN@*/ .blue/*@END_MENU_TOKEN@*/)
					}
					.offset(x: 20, y: 50)
				}
			} else {
				NavigationLink(destination: CameraView(stockImageModel: $stockModel.stockImage), isActive: $isOpenCamera) {
					Image(systemName: "plus.circle")
						.resizable()
						.frame(width: 50, height: 50)
						.foregroundColor(/*@START_MENU_TOKEN@*/ .blue/*@END_MENU_TOKEN@*/)
				}
			}
		}
    }
}

struct StockImageView_Previews: PreviewProvider {
    static var previews: some View {
		StockImageView(stockModel: StockModel(name: ""))
    }
}
