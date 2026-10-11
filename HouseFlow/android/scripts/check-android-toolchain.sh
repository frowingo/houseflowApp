#!/bin/sh
# Validate the pinned toolchain used by the Android bridge.
set -eu

required_swift='6.4.0'
required_swift_major_minor='6.4'
required_sdk='swift-6.4.0-RELEASE_android'
required_ndk='30.0.16248370'

if ! command -v swift >/dev/null 2>&1; then
    echo 'Swift toolchain not found' >&2
    exit 1
fi
if ! swift --version | grep -Eq "Swift version ${required_swift_major_minor}(\.0)?([[:space:]]|$)"; then
    echo "Expected open-source Swift ${required_swift}; Xcode Swift alone is not the Android toolchain" >&2
    exit 1
fi
if ! swift sdk list 2>/dev/null | grep -q "${required_sdk}"; then
    echo "Missing Swift Android SDK: ${required_sdk}" >&2
    exit 1
fi
if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -d "${ANDROID_NDK_HOME}" ]; then
    echo 'ANDROID_NDK_HOME must point to Android NDK r30' >&2
    exit 1
fi
if [ ! -f "${ANDROID_NDK_HOME}/source.properties" ] ||
   ! grep -Fqx "Pkg.Revision = ${required_ndk}" "${ANDROID_NDK_HOME}/source.properties"; then
    echo "Android NDK ${required_ndk} is required by this spike" >&2
    exit 1
fi
if [ -z "${SWIFT_ANDROID_SDK_BUNDLE:-}" ] || [ ! -d "${SWIFT_ANDROID_SDK_BUNDLE}" ]; then
    echo 'SWIFT_ANDROID_SDK_BUNDLE must point to the installed 6.4 artifactbundle' >&2
    exit 1
fi
if [ "$(basename "${SWIFT_ANDROID_SDK_BUNDLE}")" != "${required_sdk}.artifactbundle" ]; then
    echo "SWIFT_ANDROID_SDK_BUNDLE must select ${required_sdk}.artifactbundle" >&2
    exit 1
fi
if [ ! -d "${SWIFT_ANDROID_SDK_BUNDLE}/swift-android/swift-resources" ]; then
    echo 'SWIFT_ANDROID_SDK_BUNDLE does not look like the installed Android artifactbundle' >&2
    exit 1
fi
if [ ! -d "${SWIFT_ANDROID_SDK_BUNDLE}/swift-android/ndk-sysroot" ]; then
    echo 'Swift Android SDK is not linked to an Android NDK; run swift-android/scripts/setup-android-sdk.sh first' >&2
    exit 1
fi

echo 'Swift Android toolchain and NDK sysroot are ready for cross-builds.'
