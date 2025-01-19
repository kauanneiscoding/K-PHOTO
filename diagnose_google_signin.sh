#!/bin/bash

echo "🔍 DIAGNÓSTICO DE GOOGLE SIGN-IN"
echo "================================"

echo -e "\n📱 INFORMAÇÕES DO DISPOSITIVO:"
adb devices
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release

echo -e "\n🔧 GOOGLE PLAY SERVICES:"
adb shell dumpsys package com.google.android.gms | grep versionName
adb shell pm list packages | grep google

echo -e "\n🌐 CONFIGURAÇÕES DE REDE:"
adb shell settings get global http_proxy
adb shell settings get global wifi_networks_available_notification_on

echo -e "\n🔒 CONFIGURAÇÕES DE SEGURANÇA:"
adb shell settings get secure location_providers_allowed
adb shell settings get secure user_setup_complete

echo -e "\n📡 CONECTIVIDADE:"
adb shell ping -c 4 google.com

echo -e "\n🔑 CONTAS CONFIGURADAS:"
adb shell dumpsys account | grep "type=com.google"
