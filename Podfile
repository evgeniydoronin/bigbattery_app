# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'BatteryMonitorBL' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  
  pod 'Zetara', :path=>'./Zetara'

  pod 'SnapKit',  '~> 5.6.0'
  pod 'GradientView', '~> 2.3.4'
  pod 'R.swift', '~> 7.2.0'
  pod 'UICircleProgressView', '0.6.1'
  pod 'Then', '3.0.0'
  pod 'RxBluetoothKit', '~> 6.0.0'
  pod 'RxSwift', '~> 5.1'
  pod 'RxCocoa', '~> 5.1'
  pod 'RxViewController', '~> 1.0.0'
  
end

post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      end
    end
  end
end
