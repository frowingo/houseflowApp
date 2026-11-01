plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Keep the default universal debug APK for emulator/CI coverage. A physical
// arm64 device can request a smaller installable APK with -PfauscrewAbi=arm64-v8a.
val requestedAbi = providers.gradleProperty("fauscrewAbi").orNull
require(requestedAbi == null || requestedAbi in setOf("arm64-v8a", "x86_64")) {
    "fauscrewAbi must be arm64-v8a or x86_64"
}

android {
    namespace = "com.fauscrew"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.fauscrew"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0-spike"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk {
            abiFilters += requestedAbi?.let { setOf(it) } ?: setOf("arm64-v8a", "x86_64")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
    sourceSets.getByName("test").resources.srcDir("../../shared/Fixtures")
}

dependencies {
    implementation(project(":swift-bridge"))
    implementation("androidx.datastore:datastore-preferences:1.2.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    // SF Symbol equivalents used by the iOS design; release R8 strips unused icons.
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation("androidx.navigation:navigation-compose:2.9.7")
    // Social sign-in SDKs; each provider only proves identity, the session is our own JWT.
    implementation("androidx.credentials:credentials:1.6.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.6.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1") // 1.2.x needs Kotlin metadata 2.4; this project compiles with Kotlin 2.0
    implementation("com.facebook.android:facebook-login:18.3.0")
    implementation("com.snap.loginkit:loginkit:3.0.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.06.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}
