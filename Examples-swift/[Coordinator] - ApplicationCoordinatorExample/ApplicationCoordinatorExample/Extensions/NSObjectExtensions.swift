import Foundation
import UIKit

extension NSObject {
  
  class var nameOfClass: String {
    return NSStringFromClass(self).components(separatedBy: ".").last!
  }
}
