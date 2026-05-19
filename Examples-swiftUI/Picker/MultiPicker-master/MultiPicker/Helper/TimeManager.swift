//
//  TimeManager.swift
//  MultiPicker
//
//  Created by Heiner Gerdes on 17.05.20.
//  Copyright © 2020 Heiner Gerdes. All rights reserved.
//

import Foundation

class TimeManager: Identifiable{
    static let shared = TimeManager()
    
    // ===============================================================
    /// Converts hours as decimal value into hour and minute components as Int values(hour: hh, minute: mm) (e.g -2.5 -> (-2, -30))
    /// - Parameter hours: Hours as decimal value h or -h
    func hours2Components(hours: Double) -> (hour: Int, minute: Int) {
        let hoursRounded        : Double    = round(hours * 100) / 100
        let hoursString         : String    = String(format: "%.2f",hoursRounded)
        var hoursStringParts    : [String]  = (hoursString.components(separatedBy: "."))
        if hoursStringParts[0].first == "-"{
            hoursStringParts[1] = "-" + hoursStringParts[1]
        }
        let minutesDouble       : Double    = (Double(hoursStringParts[1])!) * 0.6
        let hoursPart           : Int       = Int(hoursStringParts[0])!
        let minutesPart         : Int       = Int(round(minutesDouble))
        return (hoursPart, minutesPart)
    }
    
    // ===============================================================
    /// Converts hour and minute components as Int values [hh, mm] into hours as decimal value (e.g [2, 30] -> 2.5)
    /// - Parameter components: Hours and minutes as Int values [hh, mm] or [-hh, -mm]
    func components2Hours(components: [Int]) -> Double{
        let componentsString        : String    = "\(String(format: "%02d", components[0])).\(String(format: "%02d",components[1]))"
        let componentsStringParts   : [String]  = (componentsString.components(separatedBy: "."))
        let hoursPart               : Double    = Double(componentsStringParts[0])!
        let minutesPart             : Double    = (Double(componentsStringParts[1])!) / 60
        let hours                   : Double    = hoursPart + minutesPart
        return hours
    }
}
