import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var queue = UploadQueue.shared
    
    // State quản lý việc chọn nhiều ảnh
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationView {
            ScrollView {
                // Nút chọn ảnh
                PhotosPicker(selection: $selectedPhotos, matching: .images) {
                    Label("Chọn Ảnh", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .onChange(of: selectedPhotos) { _, newItems in
                    processSelectedPhotos(newItems)
                }
                
                // Lưới hiển thị ảnh
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(queue.items) { item in
                        ImageCell(item: item)
                    }
                }
                .padding()
            }
            .navigationTitle("Trạng Thái Upload")
        }
    }
    
    // Trích xuất data từ PhotosPicker và thêm vào hàng đợi
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) {
        for item in items {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    UploadQueue.shared.addItem(imageData: data)
                }
            }
        }
        // Xóa selection để có thể chọn lại chính ảnh đó lần sau
        selectedPhotos.removeAll()
    }
}

// UI Cell cho từng ảnh
struct ImageCell: View {
    let item: UploadItem
    
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                // Hiển thị ảnh từ thư mục Document
                if let uiImage = loadImage(fileName: item.localFileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 150)
                        .cornerRadius(12)
                }
                
                // HIỂN THỊ TÍCH XANH HOẶC LOADING DỰA VÀO TRẠNG THÁI
                if item.status == .success {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white))
                        .padding(8)
                } else if item.status == .uploading {
                    ProgressView()
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.8)))
                        .padding(8)
                }
            }
            
            Text(item.status.rawValue)
                .font(.caption)
                .foregroundColor(item.status == .success ? .green : .secondary)
        }
    }
    
    // Helper đọc ảnh từ local
    private func loadImage(fileName: String) -> UIImage? {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
}
