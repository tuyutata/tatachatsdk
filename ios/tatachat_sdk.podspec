framework_path = 'TataChatSDK.xcframework'
unless Dir.exist?(File.join(__dir__, framework_path))
  raise "缺少 #{framework_path}，先运行 scripts/build-native.sh ios"
end

Pod::Spec.new do |spec|
  spec.name = 'tatachat_sdk'
  spec.version = '1.0.0'
  spec.summary = 'TataChatSDK OpenMLS native engine'
  spec.description = 'The independently built TataChatSDK OpenMLS dynamic framework.'
  spec.homepage = 'https://github.com/tuyutata/tatachatsdk'
  spec.license = { :type => 'AGPL-3.0-only' }
  spec.author = { 'TataChatSDK' => 'devnull@example.invalid' }
  spec.source = { :path => '.' }
  spec.platform = :ios, '16.0'
  spec.swift_version = '5.0'
  spec.source_files = 'TataChatSdkPlugin.swift'
  spec.frameworks = 'AVFoundation', 'UIKit', 'UniformTypeIdentifiers'
  spec.dependency 'Flutter'
  # 本机开发视图与正式Git/公开包均只使用pod根内的同一相对Framework名称。
  spec.vendored_frameworks = framework_path
  # 隐私清单只声明SDK自身真实行为；不借宿主或依赖的清单伪造采集与API用途。
  spec.resource_bundles = {
    'tatachat_sdk_privacy' => ['PrivacyInfo.xcprivacy']
  }
end
