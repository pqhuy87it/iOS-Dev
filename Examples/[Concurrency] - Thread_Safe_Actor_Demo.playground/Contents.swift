import Foundation

// 1. Chỉ cần thay chữ 'class' bằng 'actor'
// Không cần NSLock, không cần defer, không cần @unchecked Sendable!
actor ModernSafeArray<T> {
    private var array = [T]()
    
    // Các hàm bên trong actor tự động được bảo vệ an toàn
    func append(_ element: T) {
        array.append(element)
    }
    
    func remove(at index: Int) -> T? {
        return index < array.count ? array.remove(at: index) : nil
    }
    
    func get(at index: Int) -> T? {
        return index < array.count ? array[index] : nil
    }
    
    var count: Int {
        return array.count
    }
}

// 2. Kịch bản Test Thực Hành với Actor
func runActorTest() {
    print("🚀 Bắt đầu test ModernSafeArray (Actor)...")
    
    let safeArray = ModernSafeArray<Int>()
    
    // Tạo Task Group để chạy nhiều luồng song song
    Task {
        await withTaskGroup(of: Void.self) { group in
            let numberOfTasks = 10
            let elementsPerTask = 100
            
            // Bước 1: 10 luồng cùng lúc Append dữ liệu
            for threadID in 0..<numberOfTasks {
                group.addTask {
                    for i in 0..<elementsPerTask {
                        let value = (threadID * 1000) + i
                        // Phải dùng 'await' khi gọi hàm của actor từ bên ngoài
                        await safeArray.append(value)
                    }
                }
            }
        } // Task Group tự động đợi tất cả chạy xong ở đây
        
        // In kết quả
        let finalCount = await safeArray.count
        print("✅ Đã append xong! Tổng số phần tử: \(finalCount) (Kỳ vọng: 1000)")
        
        // Bước 2: Test Get và Remove song song
        print("\n🚀 Bắt đầu test Get và Remove song song...")
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    // Đọc và xóa song song
                    if let firstItem = await safeArray.get(at: 0) {
                        print("👀 Đã đọc được phần tử: \(firstItem)")
                    }
                    if let removedItem = await safeArray.remove(at: 0) {
                        print("🗑️ Đã xóa phần tử: \(removedItem)")
                    }
                }
            }
        }
        
        let remainingCount = await safeArray.count
        print("✅ Hoàn tất bài test! Số phần tử còn lại: \(remainingCount)")
    }
}

// 3. Thực thi
runActorTest()
RunLoop.main.run()
