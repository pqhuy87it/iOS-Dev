import UIKit
import Foundation
import Combine

["1", "2", "abc", "4"]
    .publisher
    .compactMap { Int($0) }       // Int("abc") = nil → bị loại
    .sink { print($0) }
