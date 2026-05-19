
import SwiftUI

struct ContentView: View {
	@ObservedObject private var avFoundationVM = CameraCaptureModel()

	var body: some View {
		GeometryReader { proxy  in
			ZStack {
				if avFoundationVM.image == nil {
					ZStack() {
						CALayerView(caLayer: avFoundationVM.previewLayer)
						VStack() {
							Rectangle()
								.foregroundColor(.clear)
								.frame(width: 500,height: 500)
								.background(Rectangle().stroke(Color.red,lineWidth: 2))
						}
					}.onAppear {
						self.avFoundationVM.startSession()
					}.onDisappear {
						self.avFoundationVM.endSession()
					}.frame(width:proxy.size.width,height: proxy.size.height)

					VStack {
						Spacer()

						Button(action: {
							self.avFoundationVM.takePhoto(proxy.size, cropSize: CGSize(width: 500, height: 500))
						}) {
							Image(systemName: "camera.circle.fill")
								.renderingMode(.original)
								.resizable()
								.frame(width: 80, height: 80, alignment: .center)
						}
						.padding(.bottom, 20)
					}
				} else {
					ZStack(alignment: .topLeading) {
						VStack {
							Spacer()
							
							Image(uiImage: avFoundationVM.image!)
								.resizable()
								.scaledToFill()
								.aspectRatio(contentMode: .fit)
						}
						Button(action: {
							self.avFoundationVM.image = nil
						}) {
							Image(systemName: "xmark.circle.fill")
								.renderingMode(.original)
								.resizable()
								.scaleEffect()
								.frame(width: 30, height: 30, alignment: .center)
								.foregroundColor(.white)
								.background(Color.gray)
						}
						.frame(width: 80, height: 80, alignment: .center)
					}
				}
			}
		}
	}
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
