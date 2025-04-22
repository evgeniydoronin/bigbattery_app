# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'BatteryMonitorBL' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'Zetara', :path=>'./Zetara'

  pod 'SnapKit', '~> 5.7.0'
  pod 'GradientView', '~> 2.3.4'
  pod 'R.swift', '~> 7.2.0'
  pod 'UICircleProgressView', '0.6.1'
  pod 'Then', '3.0.0'
  pod 'RxBluetoothKit2', '~> 6.6.0'
  pod 'RxSwift', '~> 6.7.0'
  pod 'RxCocoa', '~> 6.7.0'
  pod 'RxRelay', '~> 6.7.0'
  pod 'RxViewController', '~> 2.0.0'

end

post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      end
      
      # Add privacy manifest files to RxSwift, RxCocoa, and RxRelay
      if ['RxSwift', 'RxCocoa', 'RxRelay'].include?(target.name)
        target.build_phases.each do |build_phase|
          if build_phase.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase)
            privacy_file_path = "#{target.name}/Sources/PrivacyInfo.xcprivacy"
            privacy_file_ref = project.new_file(privacy_file_path)
            build_phase.add_file_reference(privacy_file_ref)
          end
        end
      end
    end
  end
end
