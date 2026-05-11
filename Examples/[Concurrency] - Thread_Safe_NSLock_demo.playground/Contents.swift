import Foundation

// 1. Class của bạn (được format lại cho dễ nhìn và thêm thuộc tính count để dễ test)
final class ThreadSafeArray<T> : @unchecked Sendable {
    private var array = [T]()
    private let lock = NSLock()
    
    func append(_ element: T) {
        lock.lock() // Khóa cửa lại
        array.append(element)
        lock.unlock() // Mở cửa cho thread khác vào
    }
    
    func remove(at index: Int) -> T? {
        lock.lock()
        defer { lock.unlock() } // Đảm bảo luôn mở khóa khi return
        return index < array.count ? array.remove(at: index) : nil
    }
    
    func get(at index: Int) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return index < array.count ? array[index] : nil
    }
    
    // Thêm thuộc tính này để in kết quả kiểm tra
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }
}

// 2. Kịch bản Test Thực Hành
func runThreadSafeTest() {
    print("🚀 Bắt đầu test ThreadSafeArray...")
    
    let safeArray = ThreadSafeArray<Int>()
    
    // Dùng DispatchGroup để biết khi nào tất cả các luồng đã làm xong việc
    let group = DispatchGroup()
    
    // Tạo một hàng đợi chạy song song (Concurrent Queue)
    let concurrentQueue = DispatchQueue(label: "com.test.concurrent", attributes: .concurrent)
    
    let numberOfThreads = 10
    let elementsPerThread = 100
    
    // Bước 1: Mô phỏng 10 luồng cùng lúc Append dữ liệu
    for threadID in 0..<numberOfThreads {
        group.enter() // Báo cáo có 1 luồng bắt đầu
        
        concurrentQueue.async {
            // Mỗi luồng sẽ nhét 100 con số vào mảng
            for i in 0..<elementsPerThread {
                let value = (threadID * 1000) + i
                safeArray.append(value)
            }
            group.leave() // Báo cáo luồng này đã xong
        }
    }
    
    // Đợi tất cả 10 luồng chạy xong
    group.wait()
    print("✅ Đã append xong! Tổng số phần tử trong mảng: \(safeArray.count) (Kỳ vọng: 1000)")
    
    // Bước 2: Test hàm get() và remove() song song
    print("\n🚀 Bắt đầu test Get và Remove song song...")
    for _ in 0..<5 {
        group.enter()
        concurrentQueue.async {
            // Lấy thử phần tử đầu tiên (index 0)
            if let firstItem = safeArray.get(at: 0) {
                print("👀 Đã đọc được phần tử: \(firstItem)")
            }
            
            // Xóa thử phần tử đầu tiên
            if let removedItem = safeArray.remove(at: 0) {
                print("🗑️ Đã xóa phần tử: \(removedItem)")
            }
            group.leave()
        }
    }
    
    group.wait()
    print("✅ Hoàn tất bài test! Số phần tử còn lại trong mảng: \(safeArray.count)")
}

// 3. Thực thi hàm test
runThreadSafeTest()
