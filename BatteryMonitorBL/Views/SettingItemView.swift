//
//  SettingItemView.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/7.
//

import UIKit
import SnapKit
import Then
import RxSwift
import RxCocoa

class SettingItemView: UIView {
    
    /// 标题
    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }
    
    var label: String? {
        didSet {
            if let label = label {
                update(label: label)
            } else {
                update(label: "")
            }
        }
    }
    
    /// 选项列表
    var options: [String] = [] {
        didSet {
            print("Options set to \(options)")
            update(options: options)
        }
    }
    
    var selectedOptionIndex = BehaviorSubject<Int>(value: 0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 16, weight: .bold)
        $0.textColor = .black
    }
    
    private let selectedButton = UIButton().then {
        $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        $0.setTitleColor(R.color.detailsTemperatureTitle(), for: .normal)
    }
    
    public let optionsButton = UIButton().then {
        $0.setImage(R.image.settingsUp(), for: .highlighted)
        $0.setImage(R.image.settingsDown(), for: .normal)
    }
    
    func setupUI() {
        addSubview(titleLabel)
        addSubview(optionsButton)
        addSubview(selectedButton)
        
        let action = UIAction {[weak self] _ in
            self?.expandOptionsMenu()
        }
        selectedButton.addAction(action, for: .touchUpInside)
        
        backgroundColor = R.color.settingsCell() ?? .clear
        layer.cornerRadius = 2
        layer.borderColor = R.color.detailsCellVoltageBorder()?.cgColor
        layer.borderWidth = 1
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
        }
        
        optionsButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-24)
        }
        
        selectedButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(optionsButton.snp.leading).offset(-18)
        }
    }
    
    fileprivate func expandOptionsMenu() {
        
        guard self.optionsButton.isEnabled else {
            return
        }
        
        let touchDownGestureRecognizer = optionsButton.gestureRecognizers?.first{
            let dd = String(describing: type(of: $0))
            return dd.hasSuffix("TouchDownGestureRecognizer")
        }
        touchDownGestureRecognizer?.touchesBegan([], with: UIEvent())
    }
    
    fileprivate func onOptionTapped(_ option: String) {
        if let index = self.options.firstIndex(of: option) {
            self.selectedOptionIndex.onNext(index)
        }
    }
    
    
    fileprivate func update(options: [String]?) {
        self.optionsButton.isHidden = options == nil
        //self.options = options ?? []
        
        if let options = options {
            let menu = UIMenu(title: "", options: [], children: options.map({
                UIAction(title: $0) { [weak self] action in
                    self?.onOptionTapped(action.title)
                }
            }))
            optionsButton.menu = menu
            optionsButton.showsMenuAsPrimaryAction = true
        } else {
            optionsButton.menu = nil
        }
    }
    
    fileprivate func update(label: String) {
        self.selectedButton.setTitle(label, for: .normal)
    }
}
