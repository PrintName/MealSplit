//
//  ViewController.swift
//  MealSplit
//
//  Created by Allen Li on 11/20/19.
//  Copyright © 2019 Allen Li. All rights reserved.
//

import Foundation
import UIKit
import Vision
import VisionKit
import ContactsUI

class ResetManager {
   static let sharedResetManager = ResetManager()
   var reset = false
}

class ViewController: UIViewController, VNDocumentCameraViewControllerDelegate {

    override var preferredStatusBarStyle: UIStatusBarStyle {
          return .lightContent
    }
    
    @IBOutlet weak var personsCollectionView: UICollectionView!
    @IBOutlet weak var receiptResultTableView: UITableView!
    @IBOutlet weak var initialScanReceiptButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    var textRecognitionRequest = VNRecognizeTextRequest()
    var persons = Persons()
    var items = Items()
    var totalFoodPrice = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        personsCollectionView.delegate = self
        personsCollectionView.dataSource = self
        receiptResultTableView.delegate = self
        receiptResultTableView.dataSource = self
                
        if persons.personArray.isEmpty {
            persons.personArray.append(PersonData(image: UIImage(named: "contact")!, name: "You"))
        }
        
        continueButton.isEnabled = false
            
        textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
            let textRecognitionObservations = self.textRecognitionRequest.results as! [VNRecognizedTextObservation]
            guard !textRecognitionObservations.isEmpty else { return }
            var detectedTexts = [""]
            var detectedTextIndex = 0
            let maxCandidates = 1
            var lineYCoordinate = Double(textRecognitionObservations[0].boundingBox.midY)
            for observation in textRecognitionObservations {
                guard let topCandidate = observation.topCandidates(maxCandidates).first else { continue }
                let boundingYCoordinate = Double(observation.boundingBox.midY)
                let maxYCoordinateDifference = 0.015
                if abs(boundingYCoordinate - lineYCoordinate) < maxYCoordinateDifference {
                    detectedTexts[detectedTextIndex] += topCandidate.string
                } else {
                    lineYCoordinate = boundingYCoordinate
                    detectedTextIndex += 1
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
                        self.items.foodItemArray.append(FoodItemData(name: trimmedNameResult, price: priceResult))
                    } else if nameResult.lowercased().contains("tax") {
                        self.items.otherItemDictionary["tax"] = priceResult
                    } else if nameResult.lowercased().contains("tip") || nameResult.lowercased().contains("gratuity") {
                        self.items.otherItemDictionary["tip"] = priceResult
                    }
                }
            }
            self.receiptResultTableView.reloadData()
            self.foodItemsChanged()
        }
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if ResetManager.sharedResetManager.reset == true {
            persons.personArray.removeSubrange(1..<persons.personArray.count)
            items.foodItemArray.removeAll()
            items.otherItemDictionary["tax"] = 0.0
            items.otherItemDictionary["tip"] = 0.0
            initialScanReceiptButton.isHidden = false
        }
        ResetManager.sharedResetManager.reset = false
    }
    
    func findPatternMatches(pattern: String, text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSMakeRange(0, text.count))
        return matches.map {
            String(text[Range($0.range, in: text)!])
        }
    }
    
    func foodItemsChanged() {
        totalFoodPrice = 0.0
        for foodItem in items.foodItemArray {
            totalFoodPrice += foodItem.price
        }
        //TODO: change tip % buttons
        if totalFoodPrice == 0 {
            continueButton.isEnabled = false
            initialScanReceiptButton.isHidden = false
        } else {
            continueButton.isEnabled = true
            initialScanReceiptButton.isHidden = true
        }
    }
        
    @IBAction func receiptScannerPressed(_ sender: UIButton) {
        self.items.foodItemArray.removeAll()
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = self
        present(documentCameraViewController, animated: true)
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
        
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        for page in 0 ..< scan.pageCount {
            let image = scan.imageOfPage(at: page)
            recognizeTextInImage(image)
        }
        controller.dismiss(animated: true)
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print(error)
        controller.dismiss(animated: true)
    }
    
    @IBAction func addPersonsPressed(_ sender: UIButton) {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        present(contactPicker, animated: true, completion: nil)
    }
    
    @IBAction func addItemPressed(_ sender: UIButton) {
        items.foodItemArray.append(FoodItemData())
        receiptResultTableView.reloadData()
    }
        
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AssignmentSegue" {
            let destination = segue.destination as! SecondViewController
            destination.persons = persons
            destination.items = items
        }
    }
    
    @IBAction func unwindToViewController(_ unwindSegue: UIStoryboardSegue) {}
    
}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return persons.personArray.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row < persons.personArray.count {
            let personCell = personsCollectionView.dequeueReusableCell(withReuseIdentifier: "PersonCell", for: indexPath) as! PersonCollectionViewCell
            personCell.personImage?.image = persons.personArray[indexPath.row].image
            personCell.nameLabel?.text = persons.personArray[indexPath.row].name
            return personCell
        }
        let addPersonCell = personsCollectionView.dequeueReusableCell(withReuseIdentifier: "AddPersonCell", for: indexPath)
        return addPersonCell
    }
        
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return items.foodItemArray.count + 1
        }
        return 2
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row < items.foodItemArray.count {
                let foodItemCell = receiptResultTableView.dequeueReusableCell(withIdentifier: "FoodItemCell", for: indexPath) as! FoodItemTableViewCell
                foodItemCell.itemTextField.tag = indexPath.row
                foodItemCell.priceTextField.tag = indexPath.row
                foodItemCell.deleteCellButton.tag = indexPath.row
                foodItemCell.itemTextField?.text = items.foodItemArray[indexPath.row].name.capitalized
                foodItemCell.priceTextField?.text = NSString(format: "%.2f", items.foodItemArray[indexPath.row].price) as String
                foodItemCell.itemTextField.addTarget(self, action: #selector(foodItemTextFieldValueChanged(_:)), for: UIControl.Event.editingDidEnd)
                foodItemCell.priceTextField.addTarget(self, action: #selector(foodPriceTextFieldValueChanged(_:)), for: UIControl.Event.editingDidEnd)
                foodItemCell.deleteCellButton.addTarget(self, action: #selector(deleteCellPressed(_:)), for: UIControl.Event.touchUpInside)
                return foodItemCell
            }
            let addItemCell = receiptResultTableView.dequeueReusableCell(withIdentifier: "AddItemCell", for: indexPath)
            return addItemCell
        }
        //TODO: Change to two cells, tax and tip with buttons
        let otherItemCell = receiptResultTableView.dequeueReusableCell(withIdentifier: "OtherItemCell", for: indexPath) as! OtherItemTableViewCell
        otherItemCell.priceTextField.tag = indexPath.row
        let otherItemArray = ["tax", "tip"]
        let currentOtherItem = otherItemArray[indexPath.row]
        otherItemCell.otherTextLabel?.text = currentOtherItem.capitalized
        otherItemCell.priceTextField?.text = NSString(format: "%.2f", items.otherItemDictionary[currentOtherItem]!) as String
        otherItemCell.priceTextField.addTarget(self, action: #selector(otherPriceTextFieldValueChanged(_:)), for: UIControl.Event.editingDidEnd)
        return otherItemCell
    }
    
    @objc func foodItemTextFieldValueChanged(_ sender: UITextField) {
        items.foodItemArray[sender.tag].name = sender.text!
    }
    
    @objc func foodPriceTextFieldValueChanged(_ sender: UITextField) {
        let newPriceValue = Double(sender.text!) ?? 0.0
        sender.text = NSString(format: "%.2f", newPriceValue) as String
        items.foodItemArray[sender.tag].price = newPriceValue
        foodItemsChanged()
    }
    
    @objc func deleteCellPressed(_ sender: UIButton) {
        items.foodItemArray.remove(at: sender.tag)
        receiptResultTableView.reloadData()
        foodItemsChanged()
    }
    
    @objc func otherPriceTextFieldValueChanged(_ sender: UITextField) {
        let newPriceValue = Double(sender.text!) ?? 0.0
        sender.text = NSString(format: "%.2f", newPriceValue) as String
        if sender.tag == 0 {
            items.otherItemDictionary["tax"] = newPriceValue
        } else {
            items.otherItemDictionary["tip"] = newPriceValue
        }
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row < items.foodItemArray.count {
            return 82
        }
        return 48
    }

}

@IBDesignable extension UIView {

    @IBInspectable var borderWidth: CGFloat {
       set {
          layer.borderWidth = newValue
       }
       get {
          return layer.borderWidth
       }
    }

    @IBInspectable var cornerRadius: CGFloat {
       set {
          layer.cornerRadius = newValue
       }
       get {
          return layer.cornerRadius
       }
    }

    @IBInspectable var borderColor: UIColor? {
       set {
          guard let uiColor = newValue else { return }
          layer.borderColor = uiColor.cgColor
       }
       get {
          guard let color = layer.borderColor else { return nil }
          return UIColor(cgColor: color)
       }
    }
    
}

extension ViewController: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
        for contact in contacts {
            var image = UIImage(named: "contact")!
            if contact.imageDataAvailable {
                image = UIImage(data: contact.thumbnailImageData!)!
            }
            let name = contact.givenName
            persons.personArray.append(PersonData(image: image, name: name))
        }
        self.personsCollectionView.reloadData()
    }
}
