//
//  ViewController.swift
//  MainActorTest
//
//  Created by huy on 2026/04/15.
//

import UIKit

class ViewController: UIViewController {
    var testing = "testing"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let myActor = MyActor { print(self.testing) } // fine
        myActor.noniso()
    }
    
    
}

actor MyActor {
    var checker: @MainActor () -> Void = {}
    
    init(checker: @escaping @MainActor () -> Void) {
        self.checker = checker
    }
    
    nonisolated func noniso() {
        Task {
            let checker = await self.checker
            await checker()
        }
    }
}
