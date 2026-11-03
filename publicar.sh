#!/bin/bash
# Foncit: genera el SDK de iOS para CocoaPods en la carpeta de versiones PHP/FONCIT/SDK/FONCIT/IOS
# (de ahí se sube a https://stg-ios.foncit.com/ o al de producción):
#   FoncitTelefono/<versión>/FoncitTelefono-<versión>.zip  (código del SDK)
#   FoncitTelefono/<versión>/FoncitTelefono.podspec        (lo que pone la app en su Podfile)
# Otro servidor: BASE=https://sdk-ios.foncit.com ./publicar.sh
set -e
cd "$(dirname "$0")"
BASE=${BASE:-https://stg-ios.foncit.com}
VERSIONES=/Users/antecit/Archivo/PHP/FONCIT/SDK/FONCIT/IOS

VERSION=$(grep -m1 "s.version " FoncitTelefono.podspec | sed "s/.*'\(.*\)'.*/\1/")
DESTINO=$VERSIONES/FoncitTelefono/$VERSION

# Una versión publicada no se vuelve a publicar con cambios (CocoaPods la guarda en caché): bórrala antes o sube el número
if [ -d "$DESTINO" ]; then
    echo "La versión $VERSION ya está en $DESTINO. Bórrala (ver ios_compilacion.md) o sube s.version en FoncitTelefono.podspec."
    exit 1
fi

mkdir -p "$DESTINO"
zip -qr "$DESTINO/FoncitTelefono-$VERSION.zip" Sources -x "*.DS_Store"
sed "s#__BASE__#$BASE#" FoncitTelefono.podspec > "$DESTINO/FoncitTelefono.podspec"

echo "Listo: versión $VERSION en $DESTINO"
echo "Sube al servidor la carpeta FoncitTelefono/$VERSION"
echo "En el Podfile de la app: pod 'FoncitTelefono', :podspec => '$BASE/FoncitTelefono/$VERSION/FoncitTelefono.podspec'"
