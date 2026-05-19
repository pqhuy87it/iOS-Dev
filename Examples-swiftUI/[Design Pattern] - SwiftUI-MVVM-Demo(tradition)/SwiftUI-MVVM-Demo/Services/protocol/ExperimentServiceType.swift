import Foundation

protocol ExperimentServiceType {
    func experiment(for key: ExperimentKey) -> Bool
}
