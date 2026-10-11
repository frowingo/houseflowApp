#!/bin/sh
set -eu

android_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
java_file="$android_dir/swift-bridge/.build/plugins/outputs/swift-bridge/HouseFlowAndroidBridge/destination/JExtractSwiftPlugin/src/generated/java/com/houseflow/androidbridge/HouseFlowAndroidBridge.java"

if [ ! -f "$java_file" ]; then
    echo 'Missing generated JNI wrapper; build the Swift bridge first' >&2
    exit 1
fi

grep -Fqx 'package com.houseflow.androidbridge;' "$java_file"
grep -Eq 'public static int bridgeVersion\(\)' "$java_file"
grep -Eq 'public static java\.lang\.String normalizeInviteCode\(java\.lang\.String input\)' "$java_file"
grep -Eq 'public static java\.lang\.String loginRequestBody\(java\.lang\.String email, java\.lang\.String password\)' "$java_file"
grep -Eq 'public static java\.lang\.String loginResponse\(int status, java\.lang\.String body\)' "$java_file"
grep -Eq 'public static java\.lang\.String profileResponse\(int status, java\.lang\.String body\)' "$java_file"
grep -Fq 'SwiftLibraries.loadLibraryWithFallbacks(LIB_NAME);' "$java_file"

public_methods=$(grep -Ec '^[[:space:]]*public static .*\(' "$java_file")
if [ "$public_methods" -ne 5 ]; then
    echo "Expected exactly five public JNI methods, found ${public_methods}" >&2
    exit 1
fi

echo 'Generated JNI API matches the version-2 Kotlin boundary.'
