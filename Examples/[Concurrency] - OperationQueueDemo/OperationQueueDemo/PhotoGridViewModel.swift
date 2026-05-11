import SwiftUI
import Foundation
import Combine

// 2. ViewModel xử lý logic tải ảnh với OperationQueue
class PhotoGridViewModel: ObservableObject {
    @Published var photos: [PhotoItem] = []
    
    // Khởi tạo OperationQueue
    private let queue = OperationQueue()

    init() {
        // CẤU HÌNH QUAN TRỌNG NHẤT: Chỉ cho phép 3 task chạy đồng thời
        queue.maxConcurrentOperationCount = 3
        
        // Tạo ra 20 items (Sử dụng API lấy ảnh mẫu ngẫu nhiên từ picsum.photos)
        var initialPhotos: [PhotoItem] = []
        for i in 1...20 {
            if let url = URL(string: "https://picsum.photos/id/\(i + 20)/300/300") {
                initialPhotos.append(PhotoItem(url: url))
            }
        }
        self.photos = initialPhotos
    }

    func startLoadingAllImages() {
        // Duyệt qua tất cả 20 ảnh và đẩy vào hàng đợi
        for index in photos.indices {
            queue.addOperation {
                // (Tuỳ chọn) Giả lập mạng chậm 1 giây để bạn thấy rõ hiệu ứng hàng đợi 3 task
                Thread.sleep(forTimeInterval: 1.0)
                
                // Tải dữ liệu ảnh đồng bộ.
                // Lưu ý: Lệnh này block thread, nhưng vì nó đang chạy trong OperationQueue
                // (background thread) nên UI không bị đơ. Nó giúp OperationQueue biết chính xác
                // khi nào task này xong để đẩy tiếp task thứ 4, thứ 5 vào chạy.
                if let data = try? Data(contentsOf: self.photos[index].url),
                   let downloadedImage = UIImage(data: data) {
                    
                    // Cập nhật giao diện LUÔN LUÔN phải diễn ra trên Main Thread
                    DispatchQueue.main.async {
                        self.photos[index].image = downloadedImage
                        self.photos[index].isWaitingOrLoading = false
                    }
                } else {
                    // Nếu tải lỗi
                    DispatchQueue.main.async {
                        self.photos[index].isWaitingOrLoading = false
                    }
                }
            }
        }
    }
}
