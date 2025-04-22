//
//  SettingsViewController.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/5.
//

import Foundation
import UIKit
import Zetara
import RxSwift
import RxBluetoothKit2
import RxViewController

class SettingsViewController: UIViewController {
    @IBOutlet weak var versionItemView: SettingItemView?
    @IBOutlet weak var moduleIdSettingItemView: SettingItemView?
    @IBOutlet weak var canProtocolView: SettingItemView?
    @IBOutlet weak var rs485ProtocolView: SettingItemView?
    
    private var moduleIdData: Zetara.Data.ModuleIdControlData?
    private var rs485Data: Zetara.Data.RS485ControlData?
    private var canData: Zetara.Data.CANControlData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        makeGradientBackgroundView(in: self)
        
        moduleIdSettingItemView?.title = "Module ID"
        moduleIdSettingItemView?.options = Zetara.Data.ModuleIdControlData.readableIds()
        moduleIdSettingItemView?.selectedOptionIndex
            .skip(1)
            .subscribe {[weak self] index in
                self?.setModuleId(at:index)
        }.disposed(by: disposeBag)
        
        versionItemView?.title = "Version"
        versionItemView?.label = version()
        
        canProtocolView?.title = "CAN Protocol"
        canProtocolView?.options = []
        canProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                self?.setCAN(at: index)
            }.disposed(by: disposeBag)
        
        rs485ProtocolView?.title = "RS485 Protocol"
        rs485ProtocolView?.options = []
        rs485ProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                self?.setRS485(at: index)
        }.disposed(by: disposeBag)
        
        // 进入设置页，就暂停 bms data 刷新，离开恢复
        self.rx.isVisible.subscribe { [weak self] (visible: Bool) in
            print("visible change")
            if visible {
                ZetaraManager.shared.pauseRefreshBMSData()
                
                let deviceConnected = (try? ZetaraManager.shared.connectedPeripheralSubject.value()) != nil
                let protocolDataIsEmpty = (self?.canData == nil || self?.rs485Data == nil)
                if deviceConnected && protocolDataIsEmpty {
                    self?.getAllSettings()
                }
                
            } else {
                ZetaraManager.shared.resumeRefreshBMSData()
            }
        }.disposed(by: disposeBag)
        
        ZetaraManager.shared.connectedPeripheralSubject.subscribeOn(MainScheduler.instance)
            .filter { $0 == nil }
            .subscribe { [weak self] _ in
                self?.canProtocolView?.options = []
                self?.rs485ProtocolView?.options = []
                self?.canProtocolView?.label = nil
                self?.rs485ProtocolView?.label = nil
                self?.canData = nil
                self?.rs485Data = nil
                self?.moduleIdSettingItemView?.label = nil
            }.disposed(by: disposeBag)
        
//        self.moduleIdSettingItemView.selectedOptionIndex
//            .map { $0 == 0 }
//            .bind(to: self.canProtocolView.optionsButton.rx.isEnabled,
//                  self.rs485ProtocolView.optionsButton.rx.isEnabled)
//            .disposed(by: disposeBag)
        
        self.toggleRS485AndCAN(false)
    }
    
    func version() -> String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return ""
        }
        
        if let shortVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version)(\(shortVersion))"
        } else {
            return version
        }
    }
    
    var disposeBag = DisposeBag()
    
    func toggleRS485AndCAN(_ enabled: Bool) {
        self.rs485ProtocolView?.optionsButton.isEnabled = enabled
        self.canProtocolView?.optionsButton.isEnabled = enabled
    }
    
    func getAllSettings() {
        Alert.show("Loading...", timeout: 3)
        
        // 一个一个来
        self.getModuleId().subscribe { [weak self] idData in
            Alert.hide()
            self?.moduleIdData = idData
            self?.moduleIdSettingItemView?.label = idData.readableId()
            self?.toggleRS485AndCAN(idData.otherProtocolsEnabled())
            self?.getRS485().subscribe(onSuccess: { [weak self] rs485 in
                Alert.hide()
                self?.rs485Data = rs485
                self?.rs485ProtocolView?.options = rs485.readableProtocols()
                self?.rs485ProtocolView?.label = rs485.readableProtocol()
                self?.getCAN().subscribe(onSuccess: { can in
                    Alert.hide()
                    self?.canData = can
                    self?.canProtocolView?.options = can.readableProtocols()
                    self?.canProtocolView?.label = can.readableProtocol()
                }, onError: { error in
                    Alert.hide()
//                    Alert.show("Invalid Response")
                })
            }, onError: { error in
                Alert.hide()
//                Alert.show("Invalid Response")
            })
        } onError: { error in
            Alert.hide()
//            Alert.show("Invalid Response")
        }.disposed(by: self.disposeBag)
    }
    
    func setModuleId(at index: Int) {
        Alert.show("Setting, please wait patiently", timeout: 3)
        // module id 从 1 开始的
        ZetaraManager.shared.setModuleId(index + 1)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] (success: Bool) in
                Alert.hide()
                if success, let idData = self?.moduleIdData {
                    self?.moduleIdSettingItemView?.label = idData.readableId(at: index)
                    self?.toggleRS485AndCAN(index == 0) // 这里是 0 ，因为这里的 id 从 0 开始
                } else {
                    Alert.show("Set module id failed")
                }
            } onError: { _ in
                Alert.hide()
                Alert.show("Set module id error")
                
//                self?.moduleIdSettingItemView.set(label: "ID\(id + 1)")
//                self?.toggleRS485AndCAN(id == 0) // 这里是 0 ，因为这里的 id 从 0 开始
                
            }.disposed(by: disposeBag)
    }
    
    func setRS485(at index: Int) {
        Alert.show("Setting, please wait patiently", timeout: 3)
        ZetaraManager.shared.setRS485(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] success in
                Alert.hide()
                if success, let rs485 = self?.rs485Data {
                    self?.rs485ProtocolView?.label = rs485.readableProtocol(at: index)
                } else {
                    self?.rs485ProtocolView?.label = "fail"
                }
            } onError: { [weak self] _ in
                Alert.hide()
                self?.rs485ProtocolView?.label = "error"
            }.disposed(by: disposeBag)
    }
    
    func setCAN(at index: Int) {
        Alert.show("Setting, please wait patiently", timeout: 3)
        ZetaraManager.shared.setCAN(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] success in
                Alert.hide()
                if success, let can = self?.canData {
                    self?.canProtocolView?.label = can.readableProtocol(at: index)
                } else {
                    self?.canProtocolView?.label = "fail"
                }
            } onError: { [weak self] _ in
                Alert.hide()
                self?.canProtocolView?.label = "error"
            }.disposed(by: disposeBag)
    }
    
    func getModuleId() -> Maybe<Zetara.Data.ModuleIdControlData> {
        print("get control data: module id")
        return ZetaraManager.shared.getModuleId().timeout(.seconds(3), scheduler: MainScheduler.instance).subscribeOn(MainScheduler.instance)
    }
    
    func getRS485() -> Maybe<Zetara.Data.RS485ControlData> {
        print("get control data: rs485")
        return ZetaraManager.shared.getRS485().timeout(.seconds(3), scheduler: MainScheduler.instance).subscribeOn(MainScheduler.instance)
    }
    
    func getCAN() -> Maybe<Zetara.Data.CANControlData> {
        print("get control data: can")
        return ZetaraManager.shared.getCAN().timeout(.seconds(3), scheduler: MainScheduler.instance).subscribeOn(MainScheduler.instance)
    }
}
