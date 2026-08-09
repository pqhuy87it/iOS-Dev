//
//  ViewController.swift
//  TestDynamicViewSize
//
//  Created by Pham, QuangHuy | CARDB on 2023/06/06.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var lbText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
//        self.lbText.numberOfLines = 2
        self.lbText.text = "LabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabelLabel"
        
        if self.lbText.isTruncated {
            // your label will truncate
            print("your label will truncate")
        }
        
        print(self.lbText.maxNumberOfLines)
        print(self.lbText.numberOfVisibleLines)
    }
}

extension UILabel {
    var maxNumberOfLines: Int {
        layoutIfNeeded() // important
        let maxSize = CGSize(width: frame.size.width, height: CGFloat(MAXFLOAT))
        let text = (self.text ?? "") as NSString
        let textHeight = text.boundingRect(with: maxSize, options: .usesLineFragmentOrigin, attributes: [.font: font!], context: nil).height
        let lineHeight = font.lineHeight
        return Int(ceil(textHeight / lineHeight))
    }
    
    var numberOfVisibleLines: Int {
        layoutIfNeeded() // important
            let maxSize = CGSize(width: frame.size.width, height: CGFloat(MAXFLOAT))
            let textHeight = sizeThatFits(maxSize).height
            let lineHeight = font.lineHeight
            return Int(ceil(textHeight / lineHeight))
        }
    
    var isTruncated: Bool {
        layoutIfNeeded() // important

        let labelSize: CGSize = self.text!.size(withAttributes: [.font: font!])
        let contentSize = self.intrinsicContentSize.width * CGFloat(self.numberOfLines)
        if labelSize.width > contentSize {
            // your label will truncate
            return true
        }
        
        return false
    }
    
}
