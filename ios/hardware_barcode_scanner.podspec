#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hardware_barcode_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hardware_barcode_scanner'
  s.version          = '0.1.1'
  s.summary          = 'Unified hardware scanner input for Flutter.'
  s.description      = <<-DESC
Unified hardware scanner input for HID scanners and rugged Android broadcast scanners.
                       DESC
  s.homepage         = 'https://github.com/eventer/hardware_barcode_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Eventer' => 'dev@eventer.co' }
  s.source           = { :path => '.' }
  s.source_files = 'hardware_barcode_scanner/Sources/hardware_barcode_scanner/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'hardware_barcode_scanner_privacy' => [
      'hardware_barcode_scanner/Sources/hardware_barcode_scanner/PrivacyInfo.xcprivacy'
    ]
  }
end
