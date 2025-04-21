//
//  Data.swift
//  Zetara
//
//  Created by xxtx on 2022/12/3.
//

import Foundation
import RxSwift

extension Array where Element == UInt8 {
  public init(hex: String) {
    self.init()
    self.reserveCapacity(hex.unicodeScalars.lazy.underestimatedCount)
    var buffer: UInt8?
    var skip = hex.hasPrefix("0x") ? 2 : 0
    for char in hex.unicodeScalars.lazy {
      guard skip == 0 else {
        skip -= 1
        continue
      }
      guard char.value >= 48 && char.value <= 102 else {
        removeAll()
        return
      }
      let v: UInt8
      let c: UInt8 = UInt8(char.value)
      switch c {
        case let c where c <= 57:
          v = c - 48
        case let c where c >= 65 && c <= 70:
          v = c - 55
        case let c where c >= 97:
          v = c - 87
        default:
          removeAll()
          return
      }
      if let b = buffer {
        append(b << 4 | v)
        buffer = nil
      } else {
        buffer = v
      }
    }
    if let b = buffer {
      append(b)
    }
  }

    public func toHexString(_ denotation: Bool? = false) -> String {
        self.reduce(into: denotation == true ? "0x" : "") { acc, byte in
      var s = String(byte, radix: 16)
      if s.count == 1 {
        s = "0" + s
      }
      acc += s
    }
  }
}

extension Foundation.Data {
    public init(hex: String) {
        self.init(Array<UInt8>(hex: hex))
    }
    
    public func toHexString(_ denotation: Bool = false) -> String {
        Array(self).toHexString(denotation)
    }
}


extension Array where Element == UInt8 {
    func crc16Verify() -> Bool {
        let BITS_OF_BYTE = 8
        let POLYNOMIAL = 0xA001
        let INITIAL_VALUE = 0xFFFF
        let FF  = 0xFF
        
        if (self.count < 3) {
            return false
        }
        
        var res = INITIAL_VALUE

        for index in 0...self.count-3 {
            res = res ^ (Int(self[index]) & FF)
            for _ in 0..<BITS_OF_BYTE {
                res =  (res & 0x0001 == 1) ? (res >> 1 ^ POLYNOMIAL) : (res >> 1)
            }
        }
        let lowByte = UInt8(res >> 8 & FF)
        let highByte = UInt8(res & FF)
        return highByte == self[self.count - 2] && lowByte == self[self.count - 1]
    }
    
    public func crc16() -> [UInt8] {
        if self.count < 3 {
            return self
        }
        
        let BITS_OF_BYTE = 8
        let POLYNOMIAL = 0xA001
        let INITIAL_VALUE = 0xFFFF
        let FF  = 0xFF
        
        var res = INITIAL_VALUE
        for item in self {
            res = res ^ (Int(item) & FF)
            for _ in 0..<BITS_OF_BYTE {
                res =  (res & 0x0001 == 1) ? (res >> 1 ^ POLYNOMIAL) : (res >> 1)
            }
        }
        
        let lowByte = UInt8(res >> 8 & FF)
        let highByte = UInt8(res & FF)
        
        var crc16Array = Array(self)
        crc16Array.append(highByte)
        crc16Array.append(lowByte)
        return crc16Array
    }
}


