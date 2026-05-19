import UIKit

protocol ImagesInteractorProtocol {
    func load(image: LoadableSubject<UIImage>, url: URL?)
}
