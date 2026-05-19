import Foundation

public enum WorkType {
    case requestPlain
    case requestData(data: Data)
    case requestParameters(parameters: [String: Any])
    case requestWithEncodable(encodable: any Encodable, encoding: JSONEncoder = JSONEncoder())
}
