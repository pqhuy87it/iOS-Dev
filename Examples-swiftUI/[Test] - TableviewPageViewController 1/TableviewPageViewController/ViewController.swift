//
//  ViewController.swift
//  TableviewPageViewController
//
//  Created by Pham, QuangHuy | CARDB on 2023/09/13.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var sections = sectionsData
    var isChanged = false
    var selectedIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        tableView.register(UINib(nibName: "HeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "HeaderView")
    }

    func createHeaderViewFor(_ tableView: UITableView) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView") as? HeaderView else {
            return nil
        }
        
        headerView.segmentedControl.selectedSegmentIndex = self.selectedIndex
        headerView.delegate = self
        
        return headerView
    }
}

extension ViewController: HeaderViewDelegate {
    func segmentControlChangeValue(_ value: Int) {
        selectedIndex = value
        isChanged = value == 1
        let sectionIndex = IndexSet(integer: 1)
        self.tableView.reloadSections(sectionIndex, with: .automatic)
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return nil
        } else {
            return self.createHeaderViewFor(tableView)
        }
    }
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return sections[0].items.count
        } else if isChanged {
            return sections[2].items.count
        } else {
            return sections[1].items.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: CustomTableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell") as? CustomTableViewCell ??
        CustomTableViewCell(style: .default, reuseIdentifier: "cell")
        
        var item: Item!
        
        if indexPath.section == 0 {
            item = sections[0].items[indexPath.row]
        } else if isChanged {
            item = sections[2].items[indexPath.row]
        } else {
            item = sections[indexPath.section].items[indexPath.row]
        }
        
        cell.nameLabel.text = item.name
        cell.detailLabel.text = item.detail
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0.1
        } else {
            return 50.0
        }
    }
}

