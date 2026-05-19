import UIKit
import Foundation
import Combine

// 1. Phải đảm bảo bạn đã định nghĩa Error này trước khi sử dụng
enum ParseError: Error {
    case invalidNumber(String)
}

// Giữ lại tham chiếu của luồng
var subscriptions = Set<AnyCancellable>()

["1", "2", "abc", "4"].publisher
    // 2. Mẹo nhỏ: Thêm explicitly type (str: String) để giúp compiler hiểu rõ ràng hơn
    .tryMap { (str: String) -> Int in
        guard let num = Int(str) else {
            throw ParseError.invalidNumber(str) // Bây giờ compiler đã hiểu ParseError là gì
        }
        return num
    }
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("Đã hoàn thành!")
            case .failure(let error):
                print("Lỗi luồng: \(error)")
            }
        },
        receiveValue: { value in
            print("Nhận được số: \(value)")
        }
    )
    .store(in: &subscriptions)

