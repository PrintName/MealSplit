//
//  DoubleExtension.swift
//  MealSplit
//
//  Created by Allen Li on 8/29/20.
//  Copyright © 2020 Allen Li. All rights reserved.
//

import Foundation

extension Double {
  func roundToTwoDecimals() -> Double {
    let divisor = 100.0
    let result = (self * divisor).rounded() / divisor
    return result
  }
}
