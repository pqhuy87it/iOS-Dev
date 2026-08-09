//
//  HeaderView.swift
//  TableviewPageViewController
//
//  Created by Pham, QuangHuy | CARDB on 2023/09/13.
//

import UIKit

protocol HeaderViewDelegate: AnyObject {
    func headerView(_ view: UIView, didChangeView value: Int)
}

class HeaderView: UITableViewHeaderFooterView {
    
    weak var delegate: HeaderViewDelegate?
    
    @IBAction func didTapChangeViewBtn(_ button: UIButton) {
        self.delegate?.headerView(self, didChangeView: button.tag)
    }
    
}
