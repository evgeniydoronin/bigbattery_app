//
//  GradientBackgroundView.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/5.
//

import Foundation
import UIKit
import GradientView
import SnapKit
import RswiftResources

func makeGradientBackgroundView(in viewController: UIViewController) {
    let gradientBackgroundView = GradientView(frame: .zero)
    viewController.view.addSubview(gradientBackgroundView)
    viewController.view.sendSubviewToBack(gradientBackgroundView)
    
    gradientBackgroundView.snp.makeConstraints { make in
        make.edges.equalToSuperview()
    }
    
    gradientBackgroundView.direction = .horizontal
    gradientBackgroundView.colors = [
        R.color.commonGradientBackground1() ?? .clear,
        R.color.commonGradientBackground2() ?? .clear,
        R.color.commonGradientBackground3() ?? .clear
    ]
}
