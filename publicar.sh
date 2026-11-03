#!/bin/bash
# Foncit v2: genera el SDK de iOS para CocoaPods en la carpeta de versiones PHP/FONCIT/SDK/FONCIT/IOS
# Incluye tanto Sources como Frameworks (Linphone preintegrado, sin fuentes externas de gitlab):
#   FoncitTelefono/<versión>/FoncitTelefono-<versión>.zip
#   FoncitTelefono/<versión>/FoncitTelefono.podspec
# Otro servidor: BASE=https://sdk-ios.foncit.com ./publicar.sh
set -e
cd "$(dirname "$0")"
BASE=${BASE:-https://stg-ios.foncit.com}
VERSIONES=/Users/antecit/Archivo/PHP/FONCIT/SDK/FONCIT/IOS

VERSION=$(grep -m1 "s.version " FoncitTelefono.podspec | sed "s/.*'\(.*\)'.*/\1/")
DESTINO=$VERSIONES/FoncitTelefono/$VERSION

if [ -d "$DESTINO" ]; then
    echo "La versión $VERSION ya está en $DESTINO. Bórrala o sube s.version en FoncitTelefono.podspec."
    exit 1
fi

mkdir -p "$DESTINO"
echo "Empaquetando Sources y Frameworks (Linphone integrado)..."
zip -qr "$DESTINO/FoncitTelefono-$VERSION.zip" Sources Frameworks -x "*.DS_Store"
sed "s#__BASE__#$BASE#" FoncitTelefono.podspec > "$DESTINO/FoncitTelefono.podspec"

echo "Listo: versión $VERSION en $DESTINO"
echo "Sube al servidor la carpeta FoncitTelefono/$VERSION"
echo "En el Podfile de la app (¡ya no requiere source gitlab de linphone!):"
echo "  pod 'FoncitTelefono', :podspec => '$BASE/FoncitTelefono/$VERSION/FoncitTelefono.podspec'"
