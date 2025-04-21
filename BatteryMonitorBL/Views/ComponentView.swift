//
//  InfoView.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/5/29.
//

import Foundation
import UIKit
import SnapKit

class ComponentView: UIView {
    
    fileprivate var iconImageView: UIImageView = {
        let image = UIImageView(frame: .init(x: 0, y: 0, width: 40, height: 40))
        return image
    }()
    
    fileprivate var valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = R.color.homeComponentValue()
        label.textAlignment = .center
        return label
    }()
    
    fileprivate var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .black //R.color.homeComponentTitle()
        label.autoresizingMask = [.flexibleWidth, ]
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        return label
    }()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(iconImageView)
        addSubview(valueLabel)
        addSubview(titleLabel)
        
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(iconImageView)
        addSubview(valueLabel)
        addSubview(titleLabel)
    }
    
    convenience init(icon: UIImage, title: String, value: String) {
        self.init(frame: .zero)
        self.iconImageView.image = icon
        self.titleLabel.text = title
        self.valueLabel.text = value
        
        iconImageView.contentMode = .scaleAspectFit
        self.valueLabel.setContentCompressionResistancePriority(.init(900), for: .horizontal)
        
    }
    
    var didSetupConstraints = false
    override func updateConstraints() {
        if !didSetupConstraints {
            iconImageView.snp.makeConstraints { make in
                make.top.leading.equalToSuperview()
                make.centerX.equalToSuperview()
            }
            
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconImageView.heightAnchor.constraint(equalToConstant: 40),
                iconImageView.widthAnchor.constraint(equalToConstant: 40)
            ])
            
            valueLabel.snp.makeConstraints { make in
                make.top.equalTo(iconImageView.snp.bottom).offset(8)
                make.leading.trailing.equalToSuperview()
                make.centerX.equalToSuperview()
            }
            
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(valueLabel.snp.bottom).offset(8)
                make.leading.trailing.bottom.equalToSuperview()
                make.centerX.equalToSuperview()
            }
        }
        didSetupConstraints = true
        super.updateConstraints()
    }
    
    var icon: UIImage? {
        didSet {
            self.iconImageView.image = icon
        }
    }
    
    var value: String? {
        didSet {
            self.valueLabel.text = value
        }
    }
    
    var title: String? {
        didSet {
            self.titleLabel.text = title
        }
    }
}
