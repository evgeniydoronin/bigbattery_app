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
                let functionValue = bytes.intValue(at: .function)
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
            if BMS.FunctionCode.isNormal(of: bytes) {
                let cellCount = bytes.cellCount(offset: BMS.Constant.bleDataOffset.rawValue)
                
                if cellCount < 0 {
                    reset()
                    return nil
                }
                
                let realBytes = Array(bytes[BMS.Constant.bleDataOffset.rawValue ..< bytes.count - 5])
                
                if let data = BMS(realBytes) {
                    if data.cellCount <= BMS.Constant.normalCellCount.rawValue {
                        reset()
                        return data
                    } else {
                        self.data = data
                        return nil
                    }
                } else {
                    reset()
                    return nil
                }
            } else if var _data = self.data {
                let frameNo = Int(bytes[2])
                let cellCountLeft = min(_data.cellCount - frameNo * BMS.Constant.normalCellCount.rawValue, BMS.Constant.normalCellCount.rawValue)
                
                if cellCountLeft > 0 {
                    let cellVoltages = bytes.voltagesFromOtherFrame(at: .cellVoltage, cellCount: cellCountLeft)
                    for index in frameNo * BMS.Constant.normalCellCount.rawValue ..< (frameNo * BMS.Constant.normalCellCount.rawValue + cellCountLeft) {
                        _data.cellVoltages.insert(cellVoltages[index - frameNo * BMS.Constant.normalCellCount.rawValue], at: index)
                    }
                }
                
                let totalFrame = (_data.cellCount + BMS.Constant.normalCellCount.rawValue - 1)/BMS.Constant.normalCellCount.rawValue
                
                if frameNo == totalFrame - 1 {
                    defer {
                        reset()
                    }
                    return _data
                }
                
                return nil
            } else {
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
        if self.count <= index + additionalOffset {
            return -1
        }
        return Int(self[index + additionalOffset])
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
        if self.count <= Data.BMS.Index.cellCount.rawValue + 1 + offset {
            return -1
        }
        return intValue2Bytes(at: Data.BMS.Index.cellCount, additionalOffset: offset)
    }
    
    func voltagesFromOtherFrame(at index: Data.BMS.Index, cellCount: Int) -> [Float] {
        var voltages: [Float] = []
        for i in 0 ..< cellCount {
            voltages.append(floatValue2Bytes(at: index, additionalOffset: i * 2, unit: 1000))
        }
        return voltages
    }
}
