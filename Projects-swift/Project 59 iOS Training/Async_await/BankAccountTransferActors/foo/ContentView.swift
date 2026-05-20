//
//  ContentView.swift
//  foo
//
//  Created by Mohammad Azam on 7/23/21.
//

import SwiftUI

enum BankError: Error {
    case insufficientFunds(Double)
}

actor BankAccount {
    
    let accountNumber: Int
    var balance: Double
    
    init(accountNumber: Int, balance: Double) {
        self.accountNumber = accountNumber
        self.balance = balance
    }
    
    func deposit(_ amount: Double) {
        balance += amount
    }
    
    func transfer(amount: Double, to other: BankAccount) async throws {
        if amount > balance {
            throw BankError.insufficientFunds(amount)
        }
        
        balance -= amount
        await other.deposit(amount)
        
        print(other.accountNumber)
        print("Current Account: \(balance), Other Account: \(await other.balance)")
    }
}


struct ContentView: View {
    
    var body: some View {
        Button {
            
            let bankAccount = BankAccount(accountNumber: 123, balance: 500)
            let otherAccount = BankAccount(accountNumber: 456, balance: 100)
            
            DispatchQueue.concurrentPerform(iterations: 100) { _ in
                Task {
                    try? await bankAccount.transfer(amount: 300, to: otherAccount)
                }
            }
            
        } label: {
            Text("Transfer")
        }

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
