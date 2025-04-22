//
//  AppDelegate.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/5/23.
//

import UIKit
import Zetara
import RxBluetoothKit2
import RxSwift

let appColor = UIColor(red: 0.1, green: 0.4, blue: 0.6, alpha: 1)

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        RxBluetoothKitLog.setLogLevel(.info)
        let config = Configuration(identifiers: [.v1, .v2],
                                   refreshBMSTimeInterval: 2)
        ZetaraManager.setup(config)
        
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.black]
        
        return true
    }
    

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}


extension UIApplication {
    
    var connectedWindowScene: UIWindowScene? {
        return self.connectedScenes.first as? UIWindowScene
    }
    
    func gotoApplicationSetting() {
        let settingURL = URL(string: UIApplication.openSettingsURLString)
        if let settingURL = settingURL, canOpenURL(settingURL) {
            open(settingURL)
        }
    }
    
    func gotoSytemBluetoothSetting() {
        let settingURL = URL(string: "App-Prefs:root=Bluetooth")
        if let settingURL = settingURL, canOpenURL(settingURL) {
            open(settingURL)
        }
    }
}

extension UIAlertController {
    func show() {
        UIApplication.shared.keyWindow?.rootViewController?.present(self, animated: true)
    }
}
