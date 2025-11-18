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
        // Активируем мок-данные mockCellTempsData для отображения данных на главном экране и экране деталей
        // Это позволяет тестировать приложение без физического подключения к батарее
        // mockCellTempsData содержит данные о температуре ячеек
        // 
        // ВАЖНО: Мы добавили отладочную информацию в метод getBMSData() в ZetaraManager.swift,
        // чтобы понять, что происходит при обработке мок-данных. Если bmsDataHandler.append()
        // возвращает nil, то теперь мы создаем фейковый объект BMS с данными для отладки.
        // Настраиваем конфигурацию ZetaraManager
        // Для отладочных сборок используем мок-данные, для релизных - нет
        var mockDataForConfig: Foundation.Data? = nil
        var mockDeviceNameForConfig: String? = nil
        
        #if DEBUG
        // Включаем мок-данные только для отладочных сборок
        mockDataForConfig = Foundation.Data.mockCellTempsData
        mockDeviceNameForConfig = "Husky 2 (Mock)"
        #endif
        
        let config = Configuration(identifiers: [.v1, .v2],
                                   refreshBMSTimeInterval: 5,
                                   mockData: mockDataForConfig,
                                   mockDeviceName: mockDeviceNameForConfig)
        ZetaraManager.setup(config)

        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.black]

        // Build 34: Refresh peripheral instance on launch to prevent stale characteristics
        // This catches cached peripherals from previous session before any operations attempt to use them
        ZetaraManager.shared.refreshPeripheralInstanceIfNeeded()

        // Build 39: Initiate startup auto-reconnect if UUID exists in UserDefaults
        // This enables cross-session auto-reconnect (app restart with battery off → app auto-reconnects when battery powers on)
        ZetaraManager.shared.initiateStartupAutoReconnect()

        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Build 34: Refresh peripheral instance when returning from background
        // Prevents stale characteristics if peripheral disconnected while app was in background
        ZetaraManager.shared.refreshPeripheralInstanceIfNeeded()
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
