#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ] || [ ! -f "$1" ]; then
    echo 'Usage: sh android/scripts/check-android-package.sh <app.apk|app.aab|bridge.aar> ["abi ..."]' >&2
    echo 'The ABI list defaults to "arm64-v8a x86_64"; pass one ABI to check a -PfauscrewAbi build.' >&2
    exit 2
fi

archive=$1
abis=${2:-'arm64-v8a x86_64'}
case "$archive" in
    *.apk) prefix='lib' ;;
    *.aab) prefix='base/lib' ;;
    *.aar) prefix='jni' ;;
    *) echo 'Expected an APK, AAB or AAR archive' >&2; exit 2 ;;
esac

for abi in $abis; do
    for library in FausCrewAndroidBridge SwiftJava swiftCore swiftObservation c++_shared; do
        entry="${prefix}/${abi}/lib${library}.so"
        if ! unzip -Z -1 "$archive" | grep -Fqx "$entry"; then
            echo "Missing ${entry} in ${archive}" >&2
            exit 1
        fi
    done
done

echo "Native libraries found for ${abis} in ${archive}"
abi_pattern=$(echo "$abis" | tr ' ' '|')
unzip -Z -1 "$archive" | grep -E "^${prefix}/(${abi_pattern})/.*\.so$" | wc -l | awk '{print "Packaged .so entries: " $1}'
du -h "$archive"
