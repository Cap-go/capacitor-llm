require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'CapgoCapacitorLlm'
  s.version = package['version']
  s.summary = package['description']
  s.license = package['license']
  s.homepage = package['repository']['url']
  s.author = package['author']
  s.source = { :git => package['repository']['url'], :tag => s.version.to_s }
  s.source_files = 'ios/Sources/**/*.{swift,h,m,c,cc,mm,cpp}'
  s.platform = :ios, '15.0'
  s.ios.deployment_target = '15.0'
  s.pod_target_xcconfig = {
    'SUPPORTS_MACCATALYST' => 'NO',
    'EXCLUDED_ARCHS[sdk=macosx*]' => 'arm64 x86_64'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=macosx*]' => 'arm64 x86_64'
  }
  s.dependency 'Capacitor'
  s.dependency 'MediaPipeTasksGenAI'
  s.dependency 'MediaPipeTasksGenAIC'
  s.swift_version = '5.1'
end
