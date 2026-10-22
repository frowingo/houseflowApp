#!/bin/sh
set -eu

android_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
java_file="$android_dir/swift-bridge/.build/plugins/outputs/swift-bridge/FausCrewAndroidBridge/destination/JExtractSwiftPlugin/src/generated/java/com/fauscrew/androidbridge/FausCrewAndroidBridge.java"

if [ ! -f "$java_file" ]; then
    echo 'Missing generated JNI wrapper; build the Swift bridge first' >&2
    exit 1
fi

grep -Fqx 'package com.fauscrew.androidbridge;' "$java_file"
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
grep -Eq 'public static int houseRocketsBotCreate\(\)' "$java_file"
grep -Eq 'public static boolean houseRocketsBotDestroy\(int handle\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsBotViewport\(int handle, double width, double height, double hudWidth, double hudHeight\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsBotStart\(int handle, int botCount\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsBotCountdown\(int handle\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsBotStep\(int handle, double delta, boolean hasSteer, double heading, int sequence\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsBotPause\(int handle\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsBotResume\(int handle\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsBotRestart\(int handle\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsCopy\(java\.lang\.String language\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsConstants\(\)' "$java_file"
grep -Eq 'public static int houseRocketsOnlineCreate\(java\.lang\.String houseId, java\.lang\.String playerId, java\.lang\.String houseOwnerId, java\.lang\.String excludingSessionId\)' "$java_file"
grep -Eq 'public static boolean houseRocketsOnlineDestroy\(int handle\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsOnlineEvent\(int handle, java\.lang\.String eventJSON\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsOnlineReceive\(int handle, java\.lang\.String text, int connection, double now\)' "$java_file"
grep -Eq 'public static boolean houseRocketsOnlineViewport\(int handle, double width, double height, double hudWidth, double hudHeight\)' "$java_file"
grep -Eq 'public static java\.lang\.String houseRocketsOnlineFrame\(int handle, double now\)' "$java_file"
grep -Eq 'public static java\.lang\.String gameCatalogResponse\(java\.lang\.String houseId, int status, java\.lang\.String body\)' "$java_file"
grep -Eq 'public static int appEventsCreate\(\)' "$java_file"
grep -Eq 'public static boolean appEventsDestroy\(int handle\)' "$java_file"
grep -Eq 'public static java\.lang\.String appEventsEvent\(int handle, java\.lang\.String eventJSON\)' "$java_file"
grep -Eq 'public static java\.lang\.String socialProviderSlug\(int provider\)' "$java_file"
grep -Eq 'public static java\.lang\.String socialSignInRequestBody\(java\.lang\.String idToken, java\.lang\.String accessToken, java\.lang\.String nonce, java\.lang\.String authorizationCode, java\.lang\.String firstName, java\.lang\.String lastName, java\.lang\.String language\)' "$java_file"
grep -Eq 'public static java\.lang\.String socialCompleteCodeRequestBody\(java\.lang\.String pendingToken, java\.lang\.String email\)' "$java_file"
grep -Eq 'public static java\.lang\.String socialCompleteRequestBody\(java\.lang\.String pendingToken, java\.lang\.String email, java\.lang\.String code, java\.lang\.String firstName, java\.lang\.String lastName, java\.lang\.String language\)' "$java_file"
grep -Eq 'public static java\.lang\.String socialResponse\(java\.lang\.String action, int status, java\.lang\.String body\)' "$java_file"
grep -Fq 'SwiftLibraries.loadLibraryWithFallbacks(LIB_NAME);' "$java_file"

public_methods=$(grep -Ec '^[[:space:]]*public static .*\(' "$java_file")
if [ "$public_methods" -ne 44 ]; then
    echo "Expected exactly forty-four public JNI methods, found ${public_methods}" >&2
    exit 1
fi

echo 'Generated JNI API matches the version-10 Kotlin boundary.'
