//
//  Alert.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/10.
//

import UIKit
import SnapKit
import Then

class AlertManager {
    static let shared = AlertManager()
    
    var alerts: [Alert] = []
    var window: UIWindow = {
        let window = UIWindow(windowScene: UIApplication.shared.connectedWindowScene!)
        window.isHidden = true
        window.windowLevel = .alert - 1
        return window
    }()
    
    func show(_ alertView: Alert, timeout: TimeInterval? = nil) {
        
        hide()
        
        window.isHidden = false
        window.addSubview(alertView)
        alertView.center = window.center
        alertView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if let timeout = timeout {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                AlertManager.shared.hide()
            }
        }
    }
    
    func hide(_ alertView: Alert) {
        window.isHidden = true
        window.removeSubviews(of: Alert.self)
    }
    
    func hide() {
        window.isHidden = true
        window.removeSubviews(of: Alert.self)
    }
}

class Alert: UIView {
    
    private let contentView = UIView().then {
        $0.backgroundColor = R.color.alertContentBackground()
        $0.layer.cornerRadius = 2
        $0.layer.borderWidth = 1
        $0.layer.borderColor = R.color.alertContentBorder()?.cgColor
    }
    
    private let warningIcon = UIImageView().then {
        $0.image = R.image.alert()
    }
    
    private let messageLabel = UILabel().then {
        $0.textAlignment = .center
        $0.font = .systemFont(ofSize: 16, weight: .bold)
        $0.textColor = R.color.alertMessage()
    }
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        
        self.backgroundColor = R.color.alertBackground() ?? .clear
        
        addSubview(contentView)
        contentView.addSubview(warningIcon)
        contentView.addSubview(messageLabel)
        
        contentView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().offset(-120)
            make.height.equalTo(141)
        }
        
        warningIcon.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(warningIcon.snp.bottom).offset(8)
            make.width.lessThanOrEqualToSuperview().offset(-32)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func show(_ message: String, timeout: TimeInterval? = nil) {
        
        let alertView = Alert(frame: .zero)
        alertView.messageLabel.text = message
        AlertManager.shared.show(alertView, timeout: timeout)
    }

    static func hide() {
        AlertManager.shared.hide()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        Alert.hide()
    }
}
