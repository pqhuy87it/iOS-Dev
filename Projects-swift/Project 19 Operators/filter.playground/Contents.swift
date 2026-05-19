import UIKit
import Combine

// 1. Phải đảm bảo bạn đã định nghĩa Error này trước khi sử dụng
enum ParseError: Error {
    case invalidNumber(String)
}

(1...100).publisher
    .filter { $0.isMultiple(of: 3) }    // 3, 6, 9, 12, ..., 99
    .filter { $0.isMultiple(of: 5) }    // 15, 30, 45, 60, 75, 90
    .sink { print($0) }
// 15, 30, 45, 60, 75, 90

// Tương đương:
(1...100).publisher
    .filter { $0.isMultiple(of: 3) && $0.isMultiple(of: 5) }
// Gộp điều kiện gọn hơn, performance tốt hơn (1 closure thay vì 2)

["10", "abc", "30", "40"].publisher
    .tryFilter { str -> Bool in
        guard let num = Int(str) else {
            throw ParseError.invalidNumber(str)
        }
        return num > 20
    }
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("Completion")
            case .failure(let error):
                print("Lỗi luồng: \(error)")
            }
        },
        receiveValue: { print("Value: \($0)") }
    )
// "10" → Int("10") = 10, 10 > 20 = false → bỏ
// "abc" → Int("abc") = nil → THROW → pipeline fail
// Output:
// Completion: failure(ParseError.invalidNumber("abc"))
