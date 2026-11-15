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
        google()
        mavenCentral()
        mavenLocal { // swift-java SwiftKitCore is not yet published centrally.
            content {
                includeGroup("org.swift.swiftkit")
            }
        }
    }
}

rootProject.name = "FausCrewAndroid"
include(":app", ":swift-bridge")
