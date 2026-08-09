//
//  PanelConfiguration.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit

public enum FloatingMode: Int {
    case compact
    case halfScreen
    case fullScreen
}

struct FloatingConfiguration {
    public var mode: FloatingMode
    public var supportedModes: Set<FloatingMode>
}

/// Allows to configure the appearance of the floating panel
public extension FloatingViewControler {

    enum Constants {
        public enum Animation {
            public static let duration: TimeInterval = 0.42
        }
    }
}

extension FloatingConfiguration {

    static var `default`: FloatingConfiguration {
        
        return FloatingConfiguration(mode: .fullScreen,
                                     supportedModes: [.halfScreen, .fullScreen])
    }
}

extension FloatingConfiguration {

    /// Makes sure that all specified values of the Panel are correct
    func validated() -> FloatingConfiguration {
        var validated = self

        if validated.supportedModes.isEmpty {
            // can't have an empty `supportedModes` array
            validated.supportedModes.insert(validated.mode)
        } else {
            // mode must be included in `supportedModes`
            if validated.supportedModes.contains(validated.mode) == false {
                let fallbackModes: [FloatingMode: FloatingMode] = [
                    .halfScreen: .fullScreen,
                    .fullScreen: .halfScreen
                ]

                if let fallbackMode = fallbackModes[validated.mode], validated.supportedModes.contains(fallbackMode) {
                    validated.mode = fallbackMode
                } else {
                    validated.mode = validated.supportedModes.first!
                }
            }
        }

        return validated
    }
}

