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
grep -Eq 'public static java\.lang\.String profileUpdateRequestBody\(' "$java_file"
grep -Eq 'public static java\.lang\.String profileUpdateResponse\(int status, java\.lang\.String body\)' "$java_file"
grep -Eq 'public static java\.lang\.String profileImagesResponse\(int status, java\.lang\.String body\)' "$java_file"
grep -Eq 'public static java\.lang\.String signupRequestBody\(java\.lang\.String email, java\.lang\.String password, java\.lang\.String firstName, java\.lang\.String lastName\)' "$java_file"
grep -Eq 'public static java\.lang\.String forgotPasswordRequestBody\(java\.lang\.String email\)' "$java_file"
grep -Eq 'public static java\.lang\.String resetPasswordRequestBody\(java\.lang\.String email, java\.lang\.String code, java\.lang\.String newPassword\)' "$java_file"
grep -Eq 'public static java\.lang\.String verifyEmailRequestBody\(java\.lang\.String code\)' "$java_file"
grep -Eq 'public static java\.lang\.String birthdayRequestBody\(java\.lang\.String birthDay\)' "$java_file"
grep -Eq 'public static java\.lang\.String authActionResponse\(java\.lang\.String action, int status, java\.lang\.String body\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseResponse\(java\.lang\.String action, int status, java\.lang\.String body\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRequestBody\(' "$java_file"
grep -Eq 'public static java\.lang\.String dashboardRequestBody\(' "$java_file"
grep -Eq 'public static java\.lang\.String dashboardResponse\(java\.lang\.String action, int status, java\.lang\.String body\)' "$java_file"
grep -Fq 'SwiftLibraries.loadLibraryWithFallbacks(LIB_NAME);' "$java_file"

public_methods=$(grep -Ec '^[[:space:]]*public static .*\(' "$java_file")
if [ "$public_methods" -ne 18 ]; then
    echo "Expected exactly eighteen public JNI methods, found ${public_methods}" >&2
    exit 1
fi

echo 'Generated JNI API matches the version-6 Kotlin boundary.'
