#!/bin/bash

WIX_PATH="%{wix-path}%"

"$WIX_PATH/heat.exe" dir bin -srd -dr INSTALLDIR -cg BinComponentGroup -gg -out bin.wxs

"$WIX_PATH/candle.exe" -d"BinDir=bin" -out bin.wixobj bin.wxs

"$WIX_PATH/light.exe" -ext WixUIExtension -ext WixUtilExtension -out bin.msi bin.wixobj

rm bin.wxs bin.wixobj

echo "Installation package bin.msi created."
