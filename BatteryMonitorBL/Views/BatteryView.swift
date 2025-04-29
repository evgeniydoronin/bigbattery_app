//
//  BatteryView.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/5/29.
//

import Foundation
import UIKit
import SnapKit

@IBDesignable
final class BatteryView: UIView {
    fileprivate let backgroundImageView = UIImageView(image: .init(named: "BatteryBackground"))
    fileprivate let maskImageView = UIImageView(image: .init(named: "BatteryMask"))
    fileprivate let batteryImageView = UIImageView(image: .init(named: "BatteryFull"))
    fileprivate let batteryContainerView = UIView()
    fileprivate var greenImageNow = true
    
    
    @IBInspectable var level: Float = 1.0 {
        didSet {
            didSetupConstraints = false
            self.setNeedsUpdateConstraints()
            
            if level <= 0.1 && greenImageNow {
                batteryImageView.image = .init(named: "BatteryLow")
                greenImageNow = false
            } else if level > 0.1 && !greenImageNow {
                batteryImageView.image = .init(named: "BatteryFull")
                greenImageNow = true
            }
            
            UIView.animate(withDuration: 0.25) {
                self.layoutIfNeeded()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Настраиваем фоновое изображение
        backgroundImageView.contentMode = .scaleAspectFill
        addSubview(backgroundImageView)
        
        // Добавляем остальные элементы
        addSubview(maskImageView)
        backgroundColor = .clear
        addSubview(batteryContainerView)
        batteryContainerView.addSubview(batteryImageView)
        bringSubviewToFront(maskImageView)
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            return maskImageView.intrinsicContentSize
        }
    }
    
    fileprivate var didSetupConstraints = false
    override func updateConstraints() {
        
        if !didSetupConstraints {
            // Настраиваем ограничения для фонового изображения
            backgroundImageView.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                // Делаем квадрат немного больше, чем сама батарея
                make.width.height.equalTo(max(self.bounds.width, self.bounds.height) + 70)
            }
            
            maskImageView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            batteryContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(8)
                make.bottom.equalToSuperview().offset(-4)
                make.leading.trailing.equalToSuperview()
            }
            
            batteryImageView.snp.remakeConstraints { make in
                make.top.greaterThanOrEqualToSuperview()
                make.leading.trailing.bottom.equalToSuperview()
                make.height.equalTo(batteryContainerView).multipliedBy(level)
            }
            didSetupConstraints = true
        }
        super.updateConstraints()
    }
}
