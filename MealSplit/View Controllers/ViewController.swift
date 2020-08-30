//
//  ViewController.swift
//  MealSplit
//
//  Created by Allen Li on 11/20/19.
//  Copyright © 2019 Allen Li. All rights reserved.
//

import UIKit
import Vision
import VisionKit
import ContactsUI

class ResetManager {
  static let sharedResetManager = ResetManager()
  var reset = false
}

class ViewController: UIViewController, VNDocumentCameraViewControllerDelegate {
  // MARK: - Properties
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  @IBOutlet weak var personsCollectionView: UICollectionView!
  @IBOutlet weak var itemsTableView: UITableView!
  @IBOutlet weak var initialScanReceiptButton: UIButton!
  @IBOutlet weak var continueButton: UIButton!
  
  var textRecognitionRequest = VNRecognizeTextRequest()
  var persons = Persons()
  var items = Items()
  
  var totalFoodPrice = 0.0
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    personsCollectionView.delegate = self
    personsCollectionView.dataSource = self
    itemsTableView.delegate = self
    itemsTableView.dataSource = self
    
    if persons.personArray.isEmpty {
      persons.personArray.append(Person(image: UIImage(named: "contact")!, name: "You"))
    }
    
    continueButton.isEnabled = false
  
    createTextRecognitionRequest()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    if ResetManager.sharedResetManager.reset == true {
      resetAll()
    }
    ResetManager.sharedResetManager.reset = false
  }
  
  // MARK: - Text Recognition
  
  func createTextRecognitionRequest() {
    textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
      let textRecognitionObservations = self.textRecognitionRequest.results as! [VNRecognizedTextObservation]
      guard !textRecognitionObservations.isEmpty else { return }
      var detectedTexts = [""]
      var detectedTextLineIndex = 0
      let maxCandidates = 1
      var lineYCoordinate = Double(textRecognitionObservations[0].boundingBox.midY)
      
      for observation in textRecognitionObservations {
        guard let topCandidate = observation.topCandidates(maxCandidates).first else { continue }
        let boundingYCoordinate = Double(observation.boundingBox.midY)
        let maxYCoordinateDifference = 0.015
        if abs(boundingYCoordinate - lineYCoordinate) < maxYCoordinateDifference {
          detectedTexts[detectedTextLineIndex] += topCandidate.string
        } else {
          lineYCoordinate = boundingYCoordinate
          detectedTextLineIndex += 1
          detectedTexts.append(topCandidate.string)
        }
      }
      
      let nonFoodKeywords = ["total", "tax", "balance", "amount", "amt", "cash", "payment", "change", "amex"]
      
      for text in detectedTexts {
        let priceMatches = self.findPatternMatches(pattern: "[0-9]+\\.[0-9]{2}", text: text)
        if priceMatches.count > 0 {
          let nameResult = self.findPatternMatches(pattern: "[a-zA-Z ]+", text: text).first ?? "Unidentified Item"
          let priceResult = Double(priceMatches[0]) ?? 0.0
          if !nonFoodKeywords.contains(where: nameResult.lowercased().contains) {
            let trimmedNameResult = nameResult.trimmingCharacters(in: .whitespacesAndNewlines)
            self.items.foodItemArray.append(FoodItem(name: trimmedNameResult, price: priceResult))
          } else if nameResult.lowercased().contains("tax") {
            self.items.taxItem = priceResult
          } else if nameResult.lowercased().contains("tip") || nameResult.lowercased().contains("gratuity") {
            self.items.tipItem = priceResult
          }
        }
      }
      
      self.itemsTableView.reloadData()
      self.foodItemsChanged()
    }
    textRecognitionRequest.recognitionLevel = .accurate
    textRecognitionRequest.usesLanguageCorrection = true
  }
  
  func findPatternMatches(pattern: String, text: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: text, range: NSMakeRange(0, text.count))
    return matches.map {
      String(text[Range($0.range, in: text)!])
    }
  }
  
  func resetAll() {
    persons.personArray.removeSubrange(1..<persons.personArray.count)
    persons.personArray[0].moneyOwed = 0.0
    items.foodItemArray.removeAll()
    items.taxItem = 0.0
    items.tipItem = 0.0
    let tipItemTableViewCell = itemsTableView.cellForRow(at: IndexPath(row: 1, section: 1)) as! TipItemTableViewCell
    tipItemTableViewCell.tipSegmentedControl.selectedSegmentIndex = 0
    initialScanReceiptButton.isHidden = false
    personsCollectionView.reloadData()
    itemsTableView.reloadData()
  }
  
  func foodItemsChanged() {
    totalFoodPrice = 0.0
    for foodItem in items.foodItemArray {
      totalFoodPrice += foodItem.price
    }
    
    let tipItemTableViewCell = itemsTableView.cellForRow(at: IndexPath(row: 1, section: 1)) as! TipItemTableViewCell
    calculateNewTipValue(tipItemTableViewCell.tipSegmentedControl)
    
    if totalFoodPrice == 0 {
      continueButton.isEnabled = false
      initialScanReceiptButton.isHidden = false
    } else {
      continueButton.isEnabled = true
      initialScanReceiptButton.isHidden = true
    }
  }
  
  // MARK: - Actions
  
  @IBAction func receiptScannerPressed(_ sender: UIButton) {
    self.items.foodItemArray.removeAll()
    let documentCameraViewController = VNDocumentCameraViewController()
    documentCameraViewController.delegate = self
    present(documentCameraViewController, animated: true)
  }
  
  @IBAction func addPersonsPressed(_ sender: UIButton) {
    let contactPicker = CNContactPickerViewController()
    contactPicker.delegate = self
    present(contactPicker, animated: true, completion: nil)
  }
  
  @IBAction func addItemPressed(_ sender: UIButton) {
    items.foodItemArray.append(FoodItem())
    itemsTableView.reloadData()
  }
  
  // MARK: - Segue
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "AssignmentSegue" {
      let destination = segue.destination as! SecondViewController
      destination.persons = persons
      destination.items = items
    }
  }
  
  @IBAction func unwindToViewController(_ unwindSegue: UIStoryboardSegue) {}
  
}

// MARK: - CollectionView Config

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return persons.personArray.count + 1 // 1 cell for "Add" button
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if indexPath.row < persons.personArray.count {
      let personCell = personsCollectionView.dequeueReusableCell(withReuseIdentifier: "PersonCell", for: indexPath) as! PersonCollectionViewCell
      personCell.personImage?.image = persons.personArray[indexPath.row].image
      personCell.nameLabel?.text = persons.personArray[indexPath.row].name
      let tapped = UITapGestureRecognizer(target: self, action: #selector(self.personCellTapped(sender:)))
      personCell.addGestureRecognizer(tapped)
      personCell.tag = indexPath.row
      return personCell
    }
    let addPersonCell = personsCollectionView.dequeueReusableCell(withReuseIdentifier: "AddPersonCell", for: indexPath)
    return addPersonCell
  }
  
  // MARK: - CollectionView Actions
  
  @objc func personCellTapped(sender: UITapGestureRecognizer) {
    let tappedCellIndex = sender.view!.tag
    if tappedCellIndex > 0 {
      persons.personArray.remove(at: tappedCellIndex)
      personsCollectionView.reloadData()
    }
  }
  
}

// MARK: - TableView Config

extension ViewController: UITableViewDelegate, UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return items.foodItemArray.count + 1 // 1 Cell for "Add Items" Button
    }
    return 2
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.section == 0 {
      if indexPath.row < items.foodItemArray.count {
        return 82
      } else {
        return 48
      }
    } else {
      if indexPath.row == 0 {
        return 48
      } else if indexPath.row == 1 {
        return 86
      } else {
        return 48
      }
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      if indexPath.row < items.foodItemArray.count {
        let foodItemCell = itemsTableView.dequeueReusableCell(withIdentifier: "FoodItemCell", for: indexPath) as! FoodItemTableViewCell
        foodItemCell.itemTextField?.tag = indexPath.row
        foodItemCell.priceTextField?.tag = indexPath.row
        foodItemCell.deleteCellButton?.tag = indexPath.row
        foodItemCell.itemTextField?.text = items.foodItemArray[indexPath.row].name.capitalized
        foodItemCell.priceTextField?.text = NSString(format: "%.2f", items.foodItemArray[indexPath.row].price) as String
        foodItemCell.itemTextField.addTarget(self, action: #selector(foodItemTextFieldValueChanged(_:)), for: UIControl.Event.editingDidEnd)
        foodItemCell.priceTextField.addTarget(self, action: #selector(foodPriceTextFieldValueChanged(_:)), for: UIControl.Event.editingDidEnd)
        foodItemCell.deleteCellButton.addTarget(self, action: #selector(deleteCellPressed(_:)), for: UIControl.Event.touchUpInside)
        return foodItemCell
      }
      let addItemCell = itemsTableView.dequeueReusableCell(withIdentifier: "AddItemCell", for: indexPath)
      return addItemCell
    } else {
      if indexPath.row == 0 {
        let taxItemCell = itemsTableView.dequeueReusableCell(withIdentifier: "TaxItemCell", for: indexPath) as! TaxItemTableViewCell
        taxItemCell.priceTextField?.text = NSString(format: "%.2f", items.taxItem) as String
        taxItemCell.priceTextField.addTarget(self, action: #selector(taxPriceTextFieldValueChanged(_:)), for: UIControl.Event.editingDidEnd)
        return taxItemCell
      } else {
        let tipItemCell = itemsTableView.dequeueReusableCell(withIdentifier: "TipItemCell", for: indexPath) as! TipItemTableViewCell
        tipItemCell.priceTextField?.text = NSString(format: "%.2f", items.tipItem) as String
        tipItemCell.priceTextField.addTarget(self, action: #selector(tipPriceTextFieldValueChanged(_:)), for: UIControl.Event.editingDidEnd)
        tipItemCell.tipSegmentedControl.addTarget(self, action: #selector(calculateNewTipValue(_:)), for: UIControl.Event.valueChanged)
        return tipItemCell
      }
    }
  }
  
  // MARK: - TableView Actions
  
  @objc func foodItemTextFieldValueChanged(_ sender: UITextField) {
    if items.foodItemArray.count <= sender.tag { return } // Prevent crash when deleting cell while editing
    items.foodItemArray[sender.tag].name = sender.text!
  }
  
  @objc func foodPriceTextFieldValueChanged(_ sender: UITextField) {
    if items.foodItemArray.count <= sender.tag { return } // Prevent crash when deleting cell while editing
    let newPriceValue = Double(sender.text!) ?? 0.0
    sender.text = NSString(format: "%.2f", newPriceValue) as String
    items.foodItemArray[sender.tag].price = newPriceValue
    foodItemsChanged()
  }
  
  @objc func deleteCellPressed(_ sender: UIButton) {
    items.foodItemArray.remove(at: sender.tag)
    itemsTableView.reloadData()
    foodItemsChanged()
  }
  
  @objc func taxPriceTextFieldValueChanged(_ sender: UITextField) {
    let newTaxValue = Double(sender.text!) ?? 0.0
    sender.text = NSString(format: "%.2f", newTaxValue) as String
    items.taxItem = newTaxValue
  }
  
  @objc func tipPriceTextFieldValueChanged(_ sender: UITextField) {
    let newTipValue = Double(sender.text!) ?? 0.0
    sender.text = NSString(format: "%.2f", newTipValue) as String
    if items.tipItem != newTipValue {
      let tipItemTableViewCell = itemsTableView.cellForRow(at: IndexPath(row: 1, section: 1)) as! TipItemTableViewCell
      tipItemTableViewCell.tipSegmentedControl.selectedSegmentIndex = -1 // Deselect
    }
    items.tipItem = newTipValue
  }
  
  @objc func calculateNewTipValue(_ sender: UISegmentedControl) {
    let tipRatios = [0.15, 0.18, 0.20]
    let newTipRatio = tipRatios[sender.selectedSegmentIndex]
    let newTipValue = newTipRatio * totalFoodPrice
    let tipItemTableViewCell = itemsTableView.cellForRow(at: IndexPath(row: 1, section: 1)) as! TipItemTableViewCell
    tipItemTableViewCell.priceTextField.text = NSString(format: "%.2f", newTipValue) as String
    items.tipItem = newTipValue
  }
}

// MARK: - Contact Picker

extension ViewController: CNContactPickerDelegate {
  func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
    for contact in contacts {
      var image = UIImage(named: "contact")!
      if contact.imageDataAvailable {
        image = UIImage(data: contact.thumbnailImageData!)!
      }
      var name = contact.givenName.capitalized
      if name.count == 0 {
        name = contact.familyName.capitalized
      }
      persons.personArray.append(Person(image: image, name: name))
    }
    self.personsCollectionView.reloadData()
  }
}

// MARK: - Document Camera

extension ViewController {
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    for page in 0 ..< scan.pageCount {
      let image = scan.imageOfPage(at: page)
      recognizeTextInImage(image)
    }
    controller.dismiss(animated: true)
  }
  
  func recognizeTextInImage(_ image: UIImage) {
    guard let cgImage = image.cgImage else { return }
    let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
      try imageRequestHandler.perform([textRecognitionRequest])
    } catch {
      print("*** ERROR: \(error)")
    }
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    print(error)
    controller.dismiss(animated: true)
  }
}

