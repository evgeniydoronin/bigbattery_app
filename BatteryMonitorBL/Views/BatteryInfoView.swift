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

class TitleButton: UIButton {
    override var intrinsicContentSize: CGSize {
        UIView.layoutFittingExpandedSize
    }
}

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
    
    // Добавляем кнопку Bluetooth
    let bluetoothButton = TitleButton().then {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setImage(R.image.homeBluetooth(), for: .normal)
        $0.imageView?.contentMode = .scaleAspectFill
        $0.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        $0.setTitleColor(.black, for: .normal)
        $0.imageEdgeInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 12)
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
        // Добавляем фон с закругленными углами для карточки
        backgroundColor = UIColor.white.withAlphaComponent(0.8)
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        addSubview(chargingImageView)
        addSubview(progressView)
        addSubview(batteryLabel)
        addSubview(statusLabel)
        addSubview(bluetoothButton)
        chargingImageView.isHidden = true
    }
    
    func update(battery: Float, status: String) {
        progressView.progress = battery
        batteryLabel.text = "\(Int(battery * 100))%"
        statusLabel.text = status
    }
    
    // Метод для обновления текста кнопки Bluetooth
    func updateBluetoothButton(title: String?) {
        bluetoothButton.setTitle(title, for: .normal)
    }
    
    fileprivate var didSetupConstraints = false
    override func updateConstraints() {
        
        if !didSetupConstraints {
            
            chargingImageView.snp.remakeConstraints { make in
                make.top.equalTo(progressView).offset(progressView.strokeWidth)
                make.centerX.equalTo(progressView)
            }
            
            progressView.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.leading.equalToSuperview().offset(12)
                make.width.height.equalTo(60)
                make.bottom.lessThanOrEqualToSuperview().offset(-12)
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
                make.trailing.equalTo(bluetoothButton.snp.leading).offset(-12)
                make.centerY.equalTo(progressView)
            }
            
            bluetoothButton.snp.remakeConstraints { make in
                make.centerY.equalTo(progressView)
                make.trailing.equalToSuperview().offset(-12)
                make.width.equalTo(44)
                make.height.equalTo(44)
            }
            
            didSetupConstraints = true
        }
        super.updateConstraints()
    }
}
