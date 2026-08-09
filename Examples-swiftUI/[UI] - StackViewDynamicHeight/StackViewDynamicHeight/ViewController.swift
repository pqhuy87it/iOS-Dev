import UIKit

class ViewController: UIViewController {
    let scrollView = UIScrollView()
    lazy var contentStackView = UIStackView(arrangedSubviews: [getView(height: 500,
                                                                       color: .red,
                                                                       text: "asdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdf"),
                                                               getView(height: 600, color: .blue,
                                                                       text: "asdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdfasdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdf"),
                                                               getView(height: 70, color: .gray,
                                                                       text: "asdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdfasdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdfasdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdf"),
                                                               getView(height: 80, color: .yellow,
                                                                       text: "asdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdfasdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdfasdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdfasdfahskjdfhkajsdhfjksdhfjkasdhfjkhaskjdfhajksdhfkjasdhfjahsdkfjhasjdkfhkjsdhfkjsadhfkjashdfkjsadhfkjasdhfakjshdfkjasdhfjksdhfksjadhfjskfdksjhdf")])
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = .white

        contentStackView.axis = .horizontal
        contentStackView.alignment = .top // ← không stretch chiều cao subview
        contentStackView.distribution = .fill // ← tôn trọng widthAnchor 200
        contentStackView.spacing = 8
        setupConstraints()
    }

    func setupConstraints() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // contentLayoutGuide quyết định vùng scroll được
            contentStackView.topAnchor.constraint(equalTo: content.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            // chiều cao content >= frame: fill hết màn hình khi content thấp,
            // và vẫn scroll dọc được khi content cao (view 600pt)
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
        ])
    }

    func getView(height: Double, color: UIColor, text: String) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        view.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let label = UILabel()
        label.numberOfLines = 0
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.orange.cgColor

        return view
    }
}
