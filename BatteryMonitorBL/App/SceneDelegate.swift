//
//  SceneDelegate.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/5/23.
//

import UIKit
import Zetara
import RxBluetoothKit
import RxSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    var disposeBag = DisposeBag()
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        print("scene did become active")
        ZetaraManager.shared.observableState
            .subscribeOn(MainScheduler.instance)
            .subscribe { (state: BluetoothState) in
                switch state {
                    case .unauthorized:
                        let alert = UIAlertController(title: .unauthorizedBluetooth, message: nil, preferredStyle: .alert)
                        alert.addAction(.init(title: .cancel, style: .cancel))
                        alert.addAction(.init(title: .gotoAuthorizeBluetooth, style: .default, handler: { _ in
                            UIApplication.shared.gotoApplicationSetting()
                        }))
                        alert.show()
                    case .poweredOff:
                        let alert = UIAlertController(title: .bluetoothPowerOff, message: nil, preferredStyle: .alert)
                        alert.addAction(.init(title: .cancel, style: .cancel))
                        alert.addAction(.init(title: .gotoTurnOnBluetooth, style: .default, handler: { _ in
                            UIApplication.shared.gotoSytemBluetoothSetting()
                        }))
                        alert.show()
                    default:
                        return
                        
                }
            }.disposed(by: disposeBag)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

