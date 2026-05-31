import Foundation
import SwiftData

// Enum cho lý do chuyến đi cá nhân
enum PersonalTripReason: String, Codable {
    case vacation = "Nghỉ mát"
    case family = "Thăm gia đình"
    case other = "Khác"
}

// Lớp cha (Base Class)
@available(iOS 26, macOS 26, *)
@Model
class Trip {
    var destination: String
    var startDate: Date
    var endDate: Date
    
    init(destination: String, startDate: Date, endDate: Date) {
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
    }
}

// Lớp con: Chuyến đi cá nhân
@available(iOS 26, macOS 26, *)
@Model
class PersonalTrip: Trip {
    var reason: PersonalTripReason
    
    init(destination: String, startDate: Date, endDate: Date, reason: PersonalTripReason) {
        self.reason = reason
        super.init(destination: destination, startDate: startDate, endDate: endDate)
    }
}

// Lớp con: Chuyến đi công tác
@available(iOS 26, macOS 26, *)
@Model
class BusinessTrip: Trip {
    var perDiem: Double // Công tác phí mỗi ngày
    
    init(destination: String, startDate: Date, endDate: Date, perDiem: Double) {
        self.perDiem = perDiem
        super.init(destination: destination, startDate: startDate, endDate: endDate)
    }
}
