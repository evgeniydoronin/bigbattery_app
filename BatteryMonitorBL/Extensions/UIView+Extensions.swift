//
//  UIView+Extensions.swift
//  VoltGoPower
//
//  Created by xxtx on 2023/2/6.
//

import Foundation
import UIKit

extension UIView {
    func removeSubviews(of cls: UIView.Type) {
        for v in subviews {
            if v.isKind(of: cls) {
                v.removeFromSuperview()
            }
        }
    }
    
    func removeAllSubviews() {
        for v in subviews {
            v.removeFromSuperview()
        }
    }
}
