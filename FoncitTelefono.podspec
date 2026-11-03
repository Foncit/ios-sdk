# Foncit v2: teléfono móvil para apps iOS con Linphone 100% integrado (sin fuentes externas).
# __BASE__ lo cambia ./publicar.sh por el servidor de versiones (https://stg-ios.foncit.com por defecto).
Pod::Spec.new do |s|
  s.name          = 'FoncitTelefono'
  s.version       = '2.0.0'
  s.summary       = 'Teléfono de Foncit para cualquier app iOS con Linphone integrado.'
  s.description   = 'Teclado, recientes, llamada entrante y en curso con CallKit; suena con la app cerrada (PushKit). Incluye Linphone integrado.'
  s.homepage      = 'https://foncit.com'
  s.license       = { :type => 'Comercial', :text => 'Foncit derechos reservados.' }
  s.author        = 'Foncit'
  s.platform      = :ios, '15.0'
  s.swift_version = '5.9'
  s.source        = { :http => "__BASE__/FoncitTelefono/#{s.version}/FoncitTelefono-#{s.version}.zip" }

  s.source_files        = 'Sources/FoncitTelefono/**/*.swift', 'Sources/linphonesw/**/*.swift'
  s.resource_bundles    = { 'FoncitTelefono' => ['Sources/FoncitTelefono/Resources/**/*.strings'] }
  s.vendored_frameworks = 'Frameworks/*.xcframework'
  s.frameworks          = 'CallKit', 'PushKit', 'AVFoundation', 'SwiftUI'
  s.libraries           = 'c++', 'resolv'

  s.pod_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO'
  }
end
