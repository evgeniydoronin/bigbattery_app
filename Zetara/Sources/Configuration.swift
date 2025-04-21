//
//  Configuration.swift
//  Zetara
//
//  Created by xxtx on 2023/1/8.
//

import Foundation
import RxBluetoothKit
import UIKit

public struct Configuration {
    let identifiers: [Identifier]
    let refreshBMSTimeInterval: TimeInterval
    var mockData: Foundation.Data? = nil
    var mockSetModuleIdData: Foundation.Data? = nil
    
    public init(identifiers: [Identifier],
                refreshBMSTimeInterval: TimeInterval,
                mockData: Foundation.Data? = nil,
                mockSetModuleIdData: Foundation.Data? = nil) {
        self.identifiers = identifiers
        self.refreshBMSTimeInterval = refreshBMSTimeInterval
        self.mockData = mockData
        self.mockSetModuleIdData = mockSetModuleIdData
    }
    
    public static let `default` = Configuration(identifiers: [.v2], refreshBMSTimeInterval: 4)
    
    public mutating func mockData(_ data: Foundation.Data) -> Configuration {
        var newOne = self
        newOne.mockData = data
        return newOne
    }
    
    public mutating func mockSetModuleIdData(_ data: Foundation.Data) -> Configuration {
        var newOne = self
        newOne.mockSetModuleIdData = data
        return newOne
    }
}

extension ZetaraService {
    static let service1000 = ZetaraService(uuidString: "1000")
    static let service1006 = ZetaraService(uuidString: "1006")
}

extension ZetaraCharacteristic {
    static let write1001 = ZetaraCharacteristic(uuidString: "1001", service: .service1000)
    static let notify1002 = ZetaraCharacteristic(uuidString: "1002", service: .service1000)
    
    static let write1008 = ZetaraCharacteristic(uuidString: "1008", service: .service1006)
    static let notify1007 = ZetaraCharacteristic(uuidString: "1007", service: .service1006)
}

extension Identifier {
    public static let v1 = Identifier(service: .service1000,
                                            writeCharacteristic: .write1001,
                                            notifyCharacteristic: .notify1002)
    public static let v2 = Identifier(service: .service1006,
                                            writeCharacteristic: .write1008,
                                            notifyCharacteristic: .notify1007)
    
    static func supportIdentifiers() -> [Identifier] {
        return [v1, v2]
    }
}

// MARK: Regular data
public extension Foundation.Data {
    static let getBMSData = Self(hex: "01030000002705d0")
    static let getModuleId = Self(hex: "1002007165")
    static let getRS485 = Self(hex: "10030070F5")
    static let getCAN = Self(hex: "10040072C5")
}

// MARK: Mock data
extension Foundation.Data {
    
    // 正常数据模拟
    public static let mockNormalBMSData = Foundation.Data(hex: "01034e053200000cfe0cff0cff0d01000000000000000000000000000000000000000000000000000f00000010005d00640064005e00000000000000000003000015752a00101000000000000403e8000075da")
    
    // 充电时数据
    public static let mockInChargingBMSData = Foundation.Data(hex: "01034E052D00690CEF0CEE0CED0CF300000000000000000000000000000000000000000000000000160016001500680000000000340001000000000000000100002AEA5400000000150015000407D00000F0C7")
    
    // 四路温度模拟
    public static let mockCellTempsData = Foundation.Data(hex: "01034E0514FF6B0CB10CB40CB10CB200000000000000000000000000000000000000000000000000150015001B00650000000000330002000000000000000100002AEA5400E4E5E6E70000000407D0000000")
    
    // 负数温度模拟，这个数据好像有点问题
    public static let mockBMSData1 = Foundation.Data(hex: "01034E1BAD00000DD90DD60DD40DD50DD30DD70DD60DD60DD20DD50DD50DD80DD80DD60DD60DD7001AFFFAFFFA3D407D00006300190004000000000000000000010000E7F9FAF7D8D8FAFA00147D000000E3C6")
}
