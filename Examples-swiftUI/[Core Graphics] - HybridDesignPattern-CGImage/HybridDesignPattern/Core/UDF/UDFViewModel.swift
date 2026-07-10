import Foundation
import Combine

@MainActor
protocol UDFViewModel: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func send(_ action: Action)
}
