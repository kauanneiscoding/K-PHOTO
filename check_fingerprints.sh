#!/bin/bash

echo "Verificando Fingerprints para Debug"
keytool -list -v -keystore ~/.android/debug.keystore -storepass android | grep -E "SHA1:|SHA256:"

echo -e "\nVerificando Fingerprints para Release (se existir)"
keytool -list -v -keystore path/to/your/release/keystore.jks -storepass SUASENHA | grep -E "SHA1:|SHA256:"
