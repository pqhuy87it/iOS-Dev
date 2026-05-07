import Foundation
import Combine

protocol CombineAPIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, APIError>
    func requestRaw(_ endpoint: Endpoint) -> AnyPublisher<Data, APIError>
}

