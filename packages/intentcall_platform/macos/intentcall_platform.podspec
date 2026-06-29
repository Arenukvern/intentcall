Pod::Spec.new do |s|
  s.name             = 'intentcall_platform'
  s.version          = '0.6.0'
  s.summary          = 'Platform bridge for IntentCall pending native invocations.'
  s.description      = <<-DESC
Platform bridge for dispatching generated native invocation envelopes into Dart.
                       DESC
  s.homepage         = 'https://github.com/Arenukvern/intentcall'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Arenukvern' => 'intentcall@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
