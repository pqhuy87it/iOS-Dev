//
//  HeaderView.swift
//  TableviewPageViewController
//
//  Created by Pham, QuangHuy | CARDB on 2023/09/13.
//

import UIKit

protocol HeaderViewDelegate: AnyObject {
    func segmentControlChangeValue(_ value: Int)
}

class HeaderView: UITableViewHeaderFooterView {
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    weak var delegate: HeaderViewDelegate?

    @IBAction func valueChanged(_ segmentControl: UISegmentedControl) {
        self.delegate?.segmentControlChangeValue(segmentControl.selectedSegmentIndex)
    }
    
    
}
