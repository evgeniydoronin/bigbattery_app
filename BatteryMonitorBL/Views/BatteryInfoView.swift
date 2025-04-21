//
//  BatteryInfoView.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/6.
//

import UIKit
import Then
import SnapKit
import UICircleProgressView

class BatteryInfoView: UIView {
    
    fileprivate var chargingImageView = UIImageView(image: R.image.batteryCharging())
    
    let progressView = UICircleProgressView(frame: .zero, style: .old).then {
        $0.strokeWidth = 5
        $0.colorPaused = R.color.homeBatteryProgress() ?? .clear
    }
    
    let batteryLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 16, weight: .bold)
        $0.textColor = .black
        $0.textAlignment = .center
    }
    
    let statusLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 18, weight: .medium)
        $0.textColor = .black
    }
    
    var charging: Bool = false {
        didSet {
            self.chargingImageView.isHidden = !charging
            if oldValue != charging {
                didSetupConstraints = false
                self.setNeedsUpdateConstraints()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        setupUI()
    }
    
    func setupUI() {
        addSubview(chargingImageView)
        addSubview(progressView)
        addSubview(batteryLabel)
        addSubview(statusLabel)
        chargingImageView.isHidden = true
    }
    
    func update(battery: Float, status: String) {
        progressView.progress = battery
        batteryLabel.text = "\(Int(battery * 100))%"
        statusLabel.text = status
    }
    
    fileprivate var didSetupConstraints = false
    override func updateConstraints() {
        
        if !didSetupConstraints {
            
            chargingImageView.snp.remakeConstraints { make in
                make.top.equalTo(progressView).offset(progressView.strokeWidth)
                make.centerX.equalTo(progressView)
            }
            
            progressView.snp.remakeConstraints { make in
                make.top.leading.equalToSuperview()
                make.width.height.equalTo(60)
                make.bottom.lessThanOrEqualToSuperview()
            }
            
            batteryLabel.snp.remakeConstraints { make in
                if chargingImageView.isHidden {
                    make.center.equalTo(progressView)
                } else {
                    make.centerX.equalTo(progressView)
                    make.top.equalTo(chargingImageView.snp.bottom)
                }
                
                make.width.equalTo(progressView).offset(-12)
            }
            
            statusLabel.snp.remakeConstraints { make in
                make.leading.equalTo(progressView.snp.trailing).offset(24)
                make.trailing.equalToSuperview()
                make.centerY.equalTo(progressView)
                make.bottom.lessThanOrEqualToSuperview()
            }
            
            didSetupConstraints = true
        }
        super.updateConstraints()
    }
}
