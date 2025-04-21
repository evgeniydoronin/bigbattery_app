//
//  ControlData.swift
//  Zetara
//
//  Created by xxtx on 2023/7/26.
//

import Foundation

public protocol ControlData {
    init?(_ bytes: [UInt8])
}

enum ControlDataProtocol: UInt8 {
    case getModuleId = 0x02
    case setModuleId = 0x07
    case getRS485 = 0x03
    case setRS485 = 0x05
    case getCAN = 0x04
    case setCAN = 0x06
}

extension ControlDataProtocol {
    static func ~= (lhs: ControlDataProtocol, rhs: UInt8) -> Bool {
        return lhs.rawValue == rhs
    }
    
    static func ~= (lhs: UInt8, rhs: ControlDataProtocol) -> Bool {
        return lhs == rhs.rawValue
    }
}

extension Zetara.Data {
    static func isControlData(_ bytes: [UInt8]) -> Bool {
        BMS.FunctionCode.isSettingControl(of: bytes)
    }
    
    static func generateControlData(_ bytes: [UInt8]) -> ControlData? {
        if let data = ModuleIdControlData(bytes) {
            return data
        } else if let data = RS485ControlData(bytes) {
            return data
        } else if let data = CANControlData(bytes) {
            return data
        }
        
        return nil
    }
}

extension Zetara.Data {
    
    public struct ResponseData: ControlData {
        var success: Bool
        
        public init?(_ bytes: [UInt8]) {
            guard bytes.count >= 3 else {
                return nil
            }
            
            if bytes[3] == 0 {
                self.success = true
            } else {
                self.success = false
            }
        }
    }
    
    public struct ModuleIdControlData: ControlData {
        public let moduleId: Int
        
        static let supportedIds = Array(1...16)
        
        public init?(_ bytes: [UInt8]) {
            guard bytes.count >= 3 else {
                return nil
            }
            
            switch bytes[1] {
                case .getModuleId, .setModuleId:
                    self.moduleId = Int(bytes[3])
                default:
                    return nil
            }
        }
        
        public static func readableIds() -> [String] {
            supportedIds.map { "ID \($0)" }
        }
        
        public func readableId() -> String {
            "ID \(self.moduleId)"
        }
        
        public func readableId(at index: Int) -> String {
            "ID \(Self.supportedIds[index])"
        }
        
        public func otherProtocolsEnabled() -> Bool {
            moduleId == 1
        }
    }
    
    public struct RS485ControlData: ControlData {
        
        public let selectedIndex: Int
        public let protocols: [[UInt8]]
       
        public init?(_ bytes: [UInt8]) {
            guard bytes.count > 3 else {
                return nil
            }
            
            switch bytes[1] {
                case .getRS485, .setRS485:
                    self.selectedIndex = Int(bytes[3])
                    self.protocols = Data.parseProtocols(bytes)
                default:
                    return nil
            }
        }
        
        public func readableProtocol() -> String {
            return readableProtocol(at: selectedIndex)
        }
        
        public func readableProtocol(at index: Int) -> String {
            
            guard index < self.protocols.count else {
                return ""
            }
            
            return self.protocols[index].parseFromASCII()
        }
        
        public func readableProtocols() -> [String] {
            return self.protocols.map { $0.parseFromASCII() }
        }
    }
    
    public struct CANControlData: ControlData {
        public let selectedIndex: Int
        public let protocols: [[UInt8]]
        
        public init?(_ bytes: [UInt8]) {
            guard bytes.count > 3 else {
                return nil
            }
            
            switch bytes[1] {
                case .getCAN, .setCAN:
                    self.selectedIndex = Int(bytes[3])
                    self.protocols = Data.parseProtocols(bytes)
                default:
                    return nil
            }
        }
        
        public func readableProtocol() -> String {
            return readableProtocol(at: selectedIndex)
        }
        
        public func readableProtocol(at index: Int) -> String {
            
            guard index < self.protocols.count else {
                return ""
            }
            
            return self.protocols[index].parseFromASCII()
        }
        
        public func readableProtocols() -> [String] {
            return self.protocols.map { $0.parseFromASCII() }
        }
    }
    
    fileprivate static func parseProtocols(_ bytes: [UInt8]) -> [[UInt8]] {
        let protocolCount = Int(bytes[4])
        var protocols: [[UInt8]] = []
        for i in 0..<protocolCount {
            var length = 0
            while Int(bytes[5 + i * 10 + length]) != 0 && length <= 10 {
                length = length + 1
            }
            
            let start = 5 + i * 10
            let end = start + length
            let p = Array(bytes[start..<end])
            protocols.append(p)
        }
        return protocols
    }
}

extension Array where Element == UInt8 {
    func parseFromASCII() -> String {
        var result = ""
        for b in self {
            result.append(Character(UnicodeScalar(b)))
        }
        return result
    }
}
