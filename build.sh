#!/bin/bash
# Makes the two zips from package/ (rebuild package/WolfparkHUD/WolfparkHUD.pck first with pack.gd, see the README):
#   out/WolfparkHUD-mod.zip         the WolfparkHUD folder to drop into GDWeave/mods
#   out/WolfparkHUD-<version>.zip   the Thunderstore upload
set -e
cd "$(dirname "$0")"
mkdir -p out
V=$(python3 -c "import json;print(json.load(open('thunderstore/manifest.json'))['version_number'])")
rm -f out/WolfparkHUD-mod.zip out/WolfparkHUD-$V.zip
(cd package && zip -qr ../out/WolfparkHUD-mod.zip WolfparkHUD)
T=$(mktemp -d)
cp thunderstore/manifest.json thunderstore/README.md thunderstore/CHANGELOG.md thunderstore/icon.png $T/
cp LICENSE $T/
mkdir -p $T/GDWeave/mods/WolfparkHUD
cp package/WolfparkHUD/manifest.json package/WolfparkHUD/WolfparkHUD.pck $T/GDWeave/mods/WolfparkHUD/
(cd $T && zip -qr - .) > out/WolfparkHUD-$V.zip
rm -rf $T
echo "out/WolfparkHUD-mod.zip"
echo "out/WolfparkHUD-$V.zip"
