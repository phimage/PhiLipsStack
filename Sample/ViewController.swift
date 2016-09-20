//
//  ViewController.swift
//  Sample
//
//  Created by phimage on 20/05/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


extension ViewController: UITableViewDelegate, UITableViewDataSource {
 


    var data: [Entity] {
        return Entity.all() ?? [Entity]()
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Entity.count() /* { error in
            print("Error when counting entity: \(error), \(error.userInfo)")
        }*/
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: "attribute")
        cell.textLabel?.text = data[indexPath.row].attribute
        return cell
    }
}
