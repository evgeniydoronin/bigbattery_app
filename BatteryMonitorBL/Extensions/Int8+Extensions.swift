//
//  Int8+Extensions.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/15.
//

import Foundation

extension Int8 {
    /// Преобразование из Цельсия в Фаренгейт
    /// - Returns: Температура в градусах Фаренгейта
    func celsiusToFahrenheit() -> Int8 {
        return Int8(Int(self) * 9/5 + 32)
    }
}
