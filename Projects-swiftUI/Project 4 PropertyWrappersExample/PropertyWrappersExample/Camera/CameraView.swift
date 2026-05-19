

import SwiftUI

struct CameraView: View {
	@Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

	@ObservedObject private var captureCameraModel = CaptureCameraModel()

	@State var isUseGuideView: Bool = true
	@State private var selectedGuideSize = 0
	@State var isExpanded = false
	@State var cropSize: CGSize = CGSize(width: screenWidth / 3,
										 height: screenHeight / 3)

	@Binding var stockImageModel: StockImageModel

	static let screenWidth = UIScreen.main.bounds.width
	static let screenHeight = UIScreen.main.bounds.height

	var guidViewSizes: [GuideViewSizeModel] = [GuideViewSizeModel(name: "1:3",
																  size: CGSize(width: screenWidth / 3, height: screenHeight / 3)),
											   GuideViewSizeModel(name: "1:2",
																  size: CGSize(width: screenWidth / 2, height: screenHeight / 2)),
											   GuideViewSizeModel(name: "1:4",
																  size: CGSize(width: screenWidth / 4, height: screenHeight / 4)),
											   GuideViewSizeModel(name: "1:5",
																  size: CGSize(width: screenWidth / 5, height: screenHeight / 5))
	]

	var body: some View {
		VStack {
			VStack(spacing: 10) {
				HStack {
					Spacer()

					HStack {
						Text("Guide view size")
							.padding(.leading, 10)

						HStack {
							Text(self.guidViewSizes[self.selectedGuideSize].name)
								.padding()
								.foregroundColor(Color.blue)
								.onTapGesture {
									self.isExpanded.toggle()
								}
						}
						.border(Color.gray, width: 1.0)
					}
					.visibility(visible: $isUseGuideView)

					Text("Use guide view")

					Toggle("", isOn: $isUseGuideView)
						.padding(.trailing, 30)
						.frame(width: 70)
				}
				.padding(.top, 10)

				ZStack(alignment: .top) {
					VStack(spacing: 10) {
						ZStack {
							GeometryReader { proxy  in
								if self.captureCameraModel.capturedImage == nil {
									ZStack {
										CaptureCameraPreview(previewLayer: self.captureCameraModel.previewLayer)

										Rectangle()
											.strokeBorder(Color.black, lineWidth: 4.0)
									}
									.onAppear() {
										self.captureCameraModel.startSession()
										self.captureCameraModel.setupAutoCaptureSize(proxy.size, cropSize: cropSize)
									}
									.onDisappear() {
										self.captureCameraModel.endSession()
									}
									.frame(width:proxy.size.width,height: proxy.size.height)

									VStack {
										Spacer()

										HStack {
											Spacer()

											GuideView(lineWidth: 4.0, scale: 8)
												.frame(width: cropSize.width,
													   height: cropSize.height,
													   alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)

											Spacer()
										}

										Spacer()
									}
									.visibility(visible: $isUseGuideView)
								} else {
									Image(uiImage: captureCameraModel.capturedImage!)
										.resizable()
										.frame(maxWidth: .infinity, maxHeight: .infinity)
										.onAppear() {
											if let capturedImage = self.captureCameraModel.capturedImage {
												self.stockImageModel.image = capturedImage
												self.captureCameraModel.reset()
												self.presentationMode.wrappedValue.dismiss()
											}
										}
								}
							}
						}
						.padding()

						Button(action: {
							if self.isUseGuideView {
								self.captureCameraModel.takePhotoCrop()
							} else {
								self.captureCameraModel.takePhoto()
							}
						}) {
							Image(systemName: "camera.circle.fill")
								.renderingMode(.original)
								.resizable()
								.frame(width: 80, height: 80, alignment: .center)
						}
						.padding(.bottom, 20)
					}

					ZStack {
						if isExpanded {
							Picker(selection: $selectedGuideSize, label: EmptyView()) {
								ForEach(0 ..< self.guidViewSizes.count) {
									GuideViewRow(guideSize: self.guidViewSizes[$0].name)
								}
							}
							.onTapGesture {
								self.tapGesture()
							}
							.background(Color.white)
						}
					}
					.offset(x: 0, y: 0)
				}
			}
		}
		.onDisappear() {
			self.captureCameraModel.reset()
		}
		.onRotate { newOrientation in
			self.captureCameraModel.updateDeviceOrientation(newOrientation)
		}
	}

	private func tapGesture() {
		self.isExpanded.toggle()
		self.cropSize = self.guidViewSizes[self.selectedGuideSize].size
	}
}

struct VisibilityStyle: ViewModifier {
	@Binding var visible: Bool

	func body(content: Content) -> some View {
		Group {
			if visible {
				content
			} else {
				content.hidden()
			}
		}
	}
}

extension View {
	func visibility(visible: Binding<Bool>) -> some View {
		modifier(VisibilityStyle(visible: visible))
	}
}
