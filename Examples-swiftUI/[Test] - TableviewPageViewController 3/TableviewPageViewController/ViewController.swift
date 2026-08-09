//
//  ViewController.swift
//  TableviewPageViewController
//
//  Created by Pham, QuangHuy | CARDB on 2023/09/13.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tableView1: UITableView!
    @IBOutlet weak var tableView2: UITableView!
    
    var sections = sectionsData
    var isChanged = false
    var selectedIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        tableView1.register(UINib(nibName: "HeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "HeaderView")
        tableView2.register(UINib(nibName: "HeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "HeaderView")
    }

    func createHeaderViewFor(_ tableView: UITableView) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView") as? HeaderView else {
            return nil
        }
        
        headerView.tag = tableView.tag
        headerView.delegate = self
        
        return headerView
    }
}

extension ViewController: HeaderViewDelegate {
    func headerView(_ view: UIView, didChangeView value: Int) {
        if value == 1 {
            self.tableView1.isHidden = false
            self.tableView2.isHidden = true
        } else {
            self.tableView1.isHidden = true
            self.tableView2.isHidden = false
        }
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
        } else if tableView.tag == 1 {
            return sections[1].items.count
        } else {
            return sections[2].items.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: CustomTableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell") as? CustomTableViewCell ??
        CustomTableViewCell(style: .default, reuseIdentifier: "cell")
        
        var item: Item!
        
        if indexPath.section == 0 {
            item = sections[0].items[indexPath.row]
        } else if tableView.tag == 1 {
            item = sections[1].items[indexPath.row]
        } else {
            item = sections[2].items[indexPath.row]
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
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.tag == 1 {
            tableView2.contentOffset.y = tableView1.contentOffset.y
        } else {
            tableView1.contentOffset.y = tableView2.contentOffset.y
        }
    }
}

