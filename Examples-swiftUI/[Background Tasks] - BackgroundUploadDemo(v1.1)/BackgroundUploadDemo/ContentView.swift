import SwiftUI
import PhotosUI // Bắt buộc import để dùng PhotosPicker

struct ContentView: View {
    @StateObject private var uploadManager = BackgroundUploadManager.shared
    
    // State quản lý việc chọn ảnh
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Background Upload Test")
                .font(.title2).bold()
            
            // --- KHU VỰC HIỂN THỊ ẢNH ---
            Group {
                if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Chưa chọn ảnh")
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
            
            // --- NÚT CHỌN ẢNH TỪ THƯ VIỆN ---
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Chọn ảnh từ Thư viện")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: 250)
                .background(Color.orange)
                .cornerRadius(10)
            }
            // Lắng nghe sự thay đổi khi người dùng chọn xong ảnh
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    // Trích xuất dữ liệu ảnh (Data) từ PhotosPickerItem
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        DispatchQueue.main.async {
                            self.selectedImageData = data
                        }
                    }
                }
            }
            
            // --- KHU VỰC UPLOAD ---
            VStack(spacing: 10) {
                ProgressView(value: uploadManager.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 40)
                
                Text(uploadManager.statusMessage)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                if let data = selectedImageData {
                    uploadManager.startUpload(with: data) // Gọi hàm với dữ liệu ảnh
                }
            }) {
                Text("Bắt đầu Upload")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 250)
                    .background(uploadManager.isUploading || selectedImageData == nil ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            // Vô hiệu hóa nút nếu đang upload HOẶC chưa chọn ảnh
            .disabled(uploadManager.isUploading || selectedImageData == nil)
            
            Spacer()
        }
        .padding(.top, 50)
    }
}

#Preview {
    ContentView()
}
