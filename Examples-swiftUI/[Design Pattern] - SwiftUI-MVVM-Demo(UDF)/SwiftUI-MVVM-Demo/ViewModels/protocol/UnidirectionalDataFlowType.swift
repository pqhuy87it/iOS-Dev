import Foundation

protocol UnidirectionalDataFlowType {
    associatedtype InputType
    func apply(_ input: InputType)
}
