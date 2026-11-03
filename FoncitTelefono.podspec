# Foncit: teléfono móvil para apps iOS (Linphone, TLS, SRTP, CallKit y PushKit).
# __BASE__ lo cambia ./publicar.sh por el servidor de versiones (https://stg-ios.foncit.com por defecto).
# La versión se queda en 1.0.0.
Pod::Spec.new do |s|
  s.name          = 'FoncitTelefono'
  s.version       = '1.0.0'
  s.summary       = 'Teléfono de Foncit para cualquier app iOS.'
  s.description   = 'Teclado, recientes, llamada entrante y en curso con CallKit; suena con la app cerrada (PushKit).'
  s.homepage      = 'https://foncit.com'
  s.license       = { :type => 'Comercial', :text => 'Foncit derechos reservados.' }
  s.author        = 'Foncit'
  s.platform      = :ios, '15.0'
  s.swift_version = '5.9'
  s.source        = { :http => "__BASE__/FoncitTelefono/#{s.version}/FoncitTelefono-#{s.version}.zip" }

  s.source_files     = 'Sources/FoncitTelefono/**/*.swift'
  s.resource_bundles = { 'FoncitTelefono' => ['Sources/FoncitTelefono/Resources/**/*.strings'] }
  s.frameworks       = 'CallKit', 'PushKit', 'AVFoundation', 'SwiftUI'

  # Motor de llamadas: necesita en el Podfile  source 'https://gitlab.linphone.org/BC/public/podspec.git'
  s.dependency 'linphone-sdk', '~> 5.4'
end
