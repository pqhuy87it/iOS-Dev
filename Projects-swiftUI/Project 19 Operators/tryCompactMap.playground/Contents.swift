import Combine

// 1. Định nghĩa lỗi
enum ValidationError: Error {
    case negativeID(Int)
}

// Giữ lại tham chiếu của luồng
var subscriptions = Set<AnyCancellable>()

// Dữ liệu đầu vào: có số hợp lệ, có chữ (không hợp lệ), có số âm (lỗi nghiêm trọng)
let rawData = ["10", "abc", "20", "-5", "30"]

rawData.publisher
    // Sử dụng tryCompactMap: phải trả về kiểu Optional (Int?)
    .tryCompactMap { (str: String) -> Int? in
        
        // Cố gắng chuyển String thành Int
        guard let number = Int(str) else {
            print("⚠️ Bỏ qua dữ liệu nhiễu: '\(str)'")
            return nil // Trả về nil -> compactMap sẽ loại bỏ giá trị này, luồng VẪN chạy tiếp
        }
        
        // Kiểm tra logic: Nếu là số âm, ném ra lỗi
        if number < 0 {
            print("🚨 Phát hiện số âm: \(number) -> Báo lỗi!")
            throw ValidationError.negativeID(number) // Ném lỗi -> luồng BỊ HỦY ngay lập tức
        }
        
        // Nếu qua hết các bước, trả về số hợp lệ
        return number
    }
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("✅ Đã xử lý xong toàn bộ luồng!")
            case .failure(let error):
                print("❌ Luồng bị dừng đột ngột do lỗi: \(error)")
            }
        },
        receiveValue: { validID in
            print("🟢 Xử lý thành công ID: \(validID)")
        }
    )
    .store(in: &subscriptions)
