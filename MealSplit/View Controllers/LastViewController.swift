//
//  LastViewController.swift
//  MealSplit
//
//  Created by Allen Li on 12/5/19.
//  Copyright © 2019 Allen Li. All rights reserved.
//

import UIKit

class LastViewController: UIViewController {
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  var persons = Persons()
  var items = Items()
  @IBOutlet weak var moneyOwedTableView: UITableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    moneyOwedTableView.delegate = self
    moneyOwedTableView.dataSource = self
    calculateMoneyOwed()
  }
  
  func calculateMoneyOwed() {
    var totalFoodCost: Double = 0.0
    var sharedFoodCost: Double = 0.0
    for foodItem in items.foodItemArray {
      if foodItem.paidBy == 0 {
        sharedFoodCost += foodItem.price
      } else {
        let personResponsible = foodItem.paidBy - 1
        persons.personArray[personResponsible].moneyOwed += foodItem.price
      }
      totalFoodCost += foodItem.price
    }
    let individualSharedFoodCost = sharedFoodCost / Double(persons.personArray.count)
    for index in 0..<persons.personArray.count {
      persons.personArray[index].moneyOwed += individualSharedFoodCost
      let paymentRatio: Double = persons.personArray[index].moneyOwed / totalFoodCost
      let individualTaxCost = paymentRatio * items.otherItemDictionary["tax"]!
      let individualTipCost = paymentRatio * items.otherItemDictionary["tip"]!
      persons.personArray[index].moneyOwed += individualTaxCost + individualTipCost
    }
  }
  
  @IBAction func goBack(_ sender: UIButton) {
    for index in 0..<persons.personArray.count {
      persons.personArray[index].moneyOwed = 0.0
    }
  }
  
  @IBAction func restartPressed(_ sender: UIButton) {
    self.navigationController?.popToRootViewController(animated: true)
    ResetManager.sharedResetManager.reset = true
  }
  
}

extension LastViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return persons.personArray.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let personCell = moneyOwedTableView.dequeueReusableCell(withIdentifier: "MoneyOwedCell", for: indexPath) as! MoneyOwedTableViewCell
    personCell.personImage.image = persons.personArray[indexPath.row].image
    personCell.nameLabel.text = persons.personArray[indexPath.row].name
    let roundedMoneyOwed = persons.personArray[indexPath.row].moneyOwed.roundToTwoDecimals()
    personCell.moneyOwedLabel.text = NSString(format: "%.2f", roundedMoneyOwed) as String
    return personCell
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 94
  }
  
}
