#!/bin/sh
set -eu

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    echo 'Usage: sh android/scripts/check-android-package.sh <app.apk|app.aab|bridge.aar>' >&2
    exit 2
fi

archive=$1
case "$archive" in
    *.apk) prefix='lib' ;;
    *.aab) prefix='base/lib' ;;
    *.aar) prefix='jni' ;;
    *) echo 'Expected an APK, AAB or AAR archive' >&2; exit 2 ;;
esac

for abi in arm64-v8a x86_64; do
    for library in FausCrewAndroidBridge SwiftJava swiftCore swiftObservation c++_shared; do
        entry="${prefix}/${abi}/lib${library}.so"
        if ! unzip -Z -1 "$archive" | grep -Fqx "$entry"; then
            echo "Missing ${entry} in ${archive}" >&2
            exit 1
        fi
    done
done

echo "Native libraries found for both ABIs in ${archive}"
unzip -Z -1 "$archive" | grep -E "^${prefix}/(arm64-v8a|x86_64)/.*\.so$" | wc -l | awk '{print "Packaged .so entries: " $1}'
du -h "$archive"
