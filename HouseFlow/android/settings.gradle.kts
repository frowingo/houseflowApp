pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenLocal() // swift-java SwiftKitCore is not yet published centrally.
        google()
        mavenCentral()
    }
}

rootProject.name = "HouseFlowAndroid"
include(":app", ":swift-bridge")
