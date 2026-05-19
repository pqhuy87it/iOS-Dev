//
//  Restaurant.swift
//  WhatsForDinner
//
//  Created by Matt Burke on 1/17/21.
//

import Foundation

struct Restaurant: Identifiable, Equatable {
    var id: UUID;
    var name: String;

    static var samples: [Restaurant] {
        [
            Restaurant(id: UUID(uuidString: "4176a4bc-423a-43ac-9834-2cd1175aa0d6")!, name: "McDonald's"),
            Restaurant(id: UUID(uuidString: "fc348eb8-63a9-4ead-a51d-75310f16b8c1")!, name: "Wendy's"),
            Restaurant(id: UUID(uuidString: "e6b1f99c-8b18-4ed2-8156-36e0231b1797")!, name: "Culver's")
        ]
    }

    static var empty: Restaurant {
        Restaurant(id: UUID(), name: "")
    }
}
