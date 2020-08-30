//
//  SecondViewController.swift
//  MealSplit
//
//  Created by Allen Li on 12/2/19.
//  Copyright © 2019 Allen Li. All rights reserved.
//

import UIKit

class SecondViewController: UIViewController {
  // MARK: - Properties
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  @IBOutlet weak var assignmentTableView: UITableView!
  
  var persons = Persons()
  var items = Items()
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    assignmentTableView.delegate = self
    assignmentTableView.dataSource = self
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(true)
    assignmentTableView.reloadData()
    print()
    print(items.foodItemArray)
    print(items.taxItem)
    print(items.tipItem)
  }
  
  // MARK: - Actions
  
  @IBAction func goBack(_ sender: UIButton) {
    for index in 0..<items.foodItemArray.count {
      items.foodItemArray[index].paidBy = 0
    }
  }
  
  // MARK: - Segue
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "MoneyOwedSegue" {
      let destination = segue.destination as! LastViewController
      destination.items = items
      destination.persons = persons
    }
  }
  
  @IBAction func unwindToViewController(_ unwindSegue: UIStoryboardSegue) {}
  
}

// MARK: - TableView Config

extension SecondViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.foodItemArray.count
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 80
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let assignmentCell = assignmentTableView.dequeueReusableCell(withIdentifier: "AssignmentCell", for: indexPath) as! AssignmentTableViewCell
    assignmentCell.itemLabel?.text = items.foodItemArray[indexPath.row].name.capitalized
    let roundedPrice = items.foodItemArray[indexPath.row].price.roundToTwoDecimals()
    assignmentCell.priceLabel?.text = NSString(format: "%.2f", roundedPrice) as String
    if assignmentCell.assignmentSegmentedControl.numberOfSegments - 1 < persons.personArray.count {
      for person in persons.personArray.dropFirst() {
        assignmentCell.assignmentSegmentedControl.insertSegment(withTitle: person.name, at: assignmentCell.assignmentSegmentedControl.numberOfSegments, animated: false)
      }
    }
    assignmentCell.assignmentSegmentedControl.tag = indexPath.row
    assignmentCell.assignmentSegmentedControl.addTarget(self, action: #selector(assignmentSegmentValueChanged(_:)), for: .valueChanged)
    return assignmentCell
  }
  
  // MARK: - TableView Actions
  
  @objc func assignmentSegmentValueChanged(_ sender: UISegmentedControl) {
    items.foodItemArray[sender.tag].paidBy = sender.selectedSegmentIndex
    print("\(items.foodItemArray[sender.tag].name) = \(items.foodItemArray[sender.tag].paidBy)")
  }
}

