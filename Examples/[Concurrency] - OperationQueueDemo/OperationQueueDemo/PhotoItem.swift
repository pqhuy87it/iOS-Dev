import UIKit
import Foundation

// 1. Data Model đại diện cho mỗi bức ảnh
struct PhotoItem: Identifiable {
    let id = UUID()
    let url: URL
    var image: UIImage? = nil
    var isWaitingOrLoading: Bool = true
}
