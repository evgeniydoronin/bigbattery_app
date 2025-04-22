//
//  ZetaraData.swift
//  Zetara
//
//  Created by xxtx on 2023/1/15.
//

import Foundation

public struct Data {
    
    public struct BMS {
        enum Index: Int {
            
            case function = 1
            case totalVoltage = 0
            case current = 2
            case tempPCB = 36
            case tempMax = 40
            case soh = 46
            case soc = 48
            case status = 51
            case cellCount = 72
            case cellVoltage = 4
            case cellTemps = 66
        }

        enum Constant: Int {
            case normalCellCount = 16
            case bleDataOffset = 3
        }

        enum FunctionCode: Int {
            case normal = 0x03
            case split = 0x04
            case settingControl = 0x10
            
            static func isNormal(of bytes: [UInt8]) -> Bool {
                print("!!! isNormal() ВЫЗВАН !!!")
                print("!!! bytes.count: \(bytes.count) !!!")
                if bytes.count > 0 {
                    print("!!! Первый байт: \(bytes[0]) !!!")
                }
                if bytes.count > 1 {
                    print("!!! Второй байт: \(bytes[1]) !!!")
                }
                
                let functionValue = bytes.intValue(at: .function)
                print("!!! functionValue: \(functionValue) !!!")
                print("!!! FunctionCode.normal.rawValue: \(FunctionCode.normal.rawValue) !!!")
                print("!!! Результат: \(functionValue == FunctionCode.normal.rawValue) !!!")
                
                return functionValue == FunctionCode.normal.rawValue
            }
            
            static func isSplit(of bytes: [UInt8]) -> Bool {
                return bytes.intValue(at: .function) == FunctionCode.split.rawValue
            }
            
            static func isSettingControl(of bytes: [UInt8]) -> Bool {
                // function 应该是 第0个
                return bytes.intValue(at: 0) == FunctionCode.settingControl.rawValue
            }
        }
    
        public enum Status: CustomStringConvertible {
            case charging
            case disCharging
            case protecting
            case chargingLimit
            case standby
            
            public init(rawValue: Int) {
                switch rawValue {
                    case 1:
                        self = .charging
                    case 2:
                        self = .disCharging
                    case 4:
                        self = .protecting
                    case 8:
                        self = .disCharging
                    default:
                        self = .standby
                }
            }
            
            public var description: String {
                switch self {
                    case .charging: return "Charging"
                    case .disCharging: return "Discharging"
                    case .protecting: return "Protecting"
                    case .chargingLimit: return "Charging Limit"
                    case .standby: return "Standby"
                }
            }
        }
        
        public var voltage: Float = 0
        public var current: Float = 0
        public var cellVoltages: Array<Float> = []
        public var cellTemps: Array<Int8> = []
        public var tempPCB: Int8 = 0
        public var tempEnv: Int8 = 0
        public var soc: Int = 0
        public var soh: Int = 0
        public var status: Status = .standby
        
        public var cellCount: Int = 0
        
        init() {
            
        }
        
        static func isBMSData(_ bytes: [UInt8]) -> Bool {
            return !FunctionCode.isSettingControl(of: bytes)
        }
        
        init?(_ bytes: [UInt8]) {
            cellCount = bytes.cellCount()
            if cellCount < 0 {
                return nil
            } else if cellCount > 500 {
                cellCount = Constant.normalCellCount.rawValue
            }
            
            // v
            voltage = bytes.floatValue2Bytes(at: .totalVoltage, unit: 100)
            
            // a
            current = bytes.floatValue2Bytes(at: .current, unit: 10)
            
            if current > 3276.8 {
                current = Float(lroundf((current - 6553.6) * 10)) / 10.0
            }
            
            soc = bytes.intValue2Bytes(at: .soc)
            soh = bytes.intValue2Bytes(at: .soh)
            
            tempEnv = Int8(truncatingIfNeeded: bytes.int16Value2Bytes(at: .tempMax))
            tempPCB = Int8(truncatingIfNeeded: bytes.int16Value2Bytes(at: .tempPCB))
            status = Status(rawValue: Int(bytes[Data.BMS.Index.status.rawValue]))
            
            for index in 0 ..< min(Constant.normalCellCount.rawValue, cellCount) {
                cellVoltages.append(bytes.floatValue2Bytes(at: .cellVoltage, additionalOffset: index * 2, unit: 1000))
                
                // 说是只要两个
                if cellTemps.count < 4 {
                    cellTemps.append(Int8(truncatingIfNeeded: bytes.intValue(at: .cellTemps, additionalOffset: index)))
                }
                
            }
        }
    }
    
    class BMSDataHandler {
        var data: BMS?
        
        func append(_ bytes: [UInt8]) -> BMS? {
            print("!!! BMSDataHandler.append() ВЫЗВАН !!!")
            print("!!! Длина байтов: \(bytes.count) !!!")
            print("!!! Первые 10 байтов: \(Array(bytes.prefix(10))) !!!")
            
            if BMS.FunctionCode.isNormal(of: bytes) {
                print("!!! Первый байт нормальный !!!")
                let cellCount = bytes.cellCount(offset: BMS.Constant.bleDataOffset.rawValue)
                print("!!! Количество ячеек: \(cellCount) !!!")
                
                if cellCount < 0 {
                    print("!!! ОШИБКА: cellCount < 0 !!!")
                    reset()
                    return nil
                }
                
                let realBytes = Array(bytes[BMS.Constant.bleDataOffset.rawValue ..< bytes.count - 5])
                print("!!! Длина realBytes: \(realBytes.count) !!!")
                
                if let data = BMS(realBytes) {
                    print("!!! BMS объект создан успешно !!!")
                    print("!!! data.cellCount: \(data.cellCount), BMS.Constant.normalCellCount.rawValue: \(BMS.Constant.normalCellCount.rawValue) !!!")
                    
                    if data.cellCount <= BMS.Constant.normalCellCount.rawValue {
                        print("!!! Возвращаем data !!!")
                        reset()
                        return data
                    } else {
                        print("!!! data.cellCount > BMS.Constant.normalCellCount.rawValue, сохраняем data и возвращаем nil !!!")
                        self.data = data
                        return nil
                    }
                } else {
                    print("!!! ОШИБКА: Не удалось создать BMS объект из realBytes !!!")
                    reset()
                    return nil
                }
            } else if var _data = self.data {
                print("!!! Первый байт НЕ нормальный, но self.data существует !!!")
                let frameNo = Int(bytes[2])
                print("!!! frameNo: \(frameNo) !!!")
                
                let cellCountLeft = min(_data.cellCount - frameNo * BMS.Constant.normalCellCount.rawValue, BMS.Constant.normalCellCount.rawValue)
                print("!!! cellCountLeft: \(cellCountLeft) !!!")
                
                if cellCountLeft > 0 {
                    print("!!! cellCountLeft > 0, добавляем cellVoltages !!!")
                    let cellVoltages = bytes.voltagesFromOtherFrame(at: .cellVoltage, cellCount: cellCountLeft)
                    for index in frameNo * BMS.Constant.normalCellCount.rawValue ..< (frameNo * BMS.Constant.normalCellCount.rawValue + cellCountLeft) {
                        _data.cellVoltages.insert(cellVoltages[index - frameNo * BMS.Constant.normalCellCount.rawValue], at: index)
                    }
                }
                
                let totalFrame = (_data.cellCount + BMS.Constant.normalCellCount.rawValue - 1)/BMS.Constant.normalCellCount.rawValue
                print("!!! totalFrame: \(totalFrame) !!!")
                
                if frameNo == totalFrame - 1 {
                    print("!!! frameNo == totalFrame - 1, возвращаем _data !!!")
                    defer {
                        reset()
                    }
                    return _data
                }
                
                print("!!! frameNo != totalFrame - 1, возвращаем nil !!!")
                return nil
            } else {
                print("!!! Первый байт НЕ нормальный и self.data НЕ существует, возвращаем nil !!!")
                return nil
            }
        }
        
        func reset() {
            self.data = nil
        }
    }
}

extension Data.BMS.Index {
    static func < (lhs: Data.BMS.Index, rhs: Int) -> Bool {
        return lhs.rawValue < rhs
    }
    
    static func < (lhs: Int, rhs: Data.BMS.Index) -> Bool {
        return lhs < rhs.rawValue
    }
    
    static func == (lhs: Data.BMS.Index, rhs: Int) -> Bool {
        return lhs.rawValue == rhs
    }
    
    static func == (lhs: Int, rhs: Data.BMS.Index) -> Bool {
        return lhs == rhs.rawValue
    }
    
    static func > (lhs: Data.BMS.Index, rhs: Int) -> Bool {
        return lhs.rawValue > rhs
    }
    
    static func > (lhs: Int, rhs: Data.BMS.Index) -> Bool {
        return lhs > rhs.rawValue
    }
    
    static func <= (lhs: Data.BMS.Index, rhs: Int) -> Bool {
        return lhs.rawValue <= rhs
    }
    
    static func <= (lhs: Int, rhs: Data.BMS.Index) -> Bool {
        return lhs <= rhs.rawValue
    }
    
    static func >= (lhs: Data.BMS.Index, rhs: Int) -> Bool {
        return lhs.rawValue >= rhs
    }
    
    static func >= (lhs: Int, rhs: Data.BMS.Index) -> Bool {
        return lhs >= rhs.rawValue
    }
}

extension Array where Element == UInt8 {
    func intValue(at index: Int, additionalOffset: Int = 0) -> Int {
        print("!!! intValue() ВЫЗВАН с index: \(index), additionalOffset: \(additionalOffset) !!!")
        print("!!! self.count: \(self.count) !!!")
        print("!!! index + additionalOffset: \(index + additionalOffset) !!!")
        
        if self.count <= index + additionalOffset {
            print("!!! ОШИБКА: self.count <= index + additionalOffset, возвращаем -1 !!!")
            return -1
        }
        
        let result = Int(self[index + additionalOffset])
        print("!!! Результат intValue: \(result) !!!")
        return result
    }
    
    func intValue(at index: Data.BMS.Index, additionalOffset: Int = 0) -> Int {
        return intValue(at: index.rawValue, additionalOffset: additionalOffset)
    }
    
    func int16Value(at index: Int, additionalOffset: Int = 0) -> Int16 {
        Int16(truncatingIfNeeded: intValue(at: index, additionalOffset: additionalOffset))
    }
    
    func int16Value(at index: Data.BMS.Index, additionalOffset: Int = 0) -> Int16 {
        Int16(truncatingIfNeeded: intValue(at: index, additionalOffset: additionalOffset))
    }
    
    func intValue2Bytes(at index: Data.BMS.Index, additionalOffset: Int = 0) -> Int {
        let first = intValue(at: index, additionalOffset: additionalOffset) & 0xFF
        let second = intValue(at: index, additionalOffset: additionalOffset + 1) & 0xFF
        return (first * 0x100 + second)
    }
    
    func int16Value2Bytes(at index: Data.BMS.Index, additionalOffset: Int = 0) -> Int16 {
        let first = intValue(at: index, additionalOffset: additionalOffset) & 0xFF
        let second = intValue(at: index, additionalOffset: additionalOffset + 1) & 0xFF
        return Int16(truncatingIfNeeded: first * 0x100 + second)
    }
    
    func floatValue2Bytes(at index: Data.BMS.Index, additionalOffset: Int = 0, unit: Int = 1) -> Float {
        let first = intValue(at: index, additionalOffset: additionalOffset) & 0xFF
        let second = intValue(at: index, additionalOffset: additionalOffset + 1) & 0xFF
        return Float(first * 0x100 + second)/Float(unit)
    }
    
    func cellCount(offset: Int = 0) -> Int {
        print("!!! cellCount() ВЫЗВАН с offset: \(offset) !!!")
        print("!!! self.count: \(self.count) !!!")
        print("!!! Data.BMS.Index.cellCount.rawValue: \(Data.BMS.Index.cellCount.rawValue) !!!")
        print("!!! Data.BMS.Index.cellCount.rawValue + 1 + offset: \(Data.BMS.Index.cellCount.rawValue + 1 + offset) !!!")
        
        if self.count <= Data.BMS.Index.cellCount.rawValue + 1 + offset {
            print("!!! ОШИБКА: self.count <= Data.BMS.Index.cellCount.rawValue + 1 + offset, возвращаем -1 !!!")
            return -1
        }
        
        let result = intValue2Bytes(at: Data.BMS.Index.cellCount, additionalOffset: offset)
        print("!!! Результат cellCount: \(result) !!!")
        return result
    }
    
    func voltagesFromOtherFrame(at index: Data.BMS.Index, cellCount: Int) -> [Float] {
        var voltages: [Float] = []
        for i in 0 ..< cellCount {
            voltages.append(floatValue2Bytes(at: index, additionalOffset: i * 2, unit: 1000))
        }
        return voltages
    }
}
