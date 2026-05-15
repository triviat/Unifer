pluginManagement {
    plugins {
        id("com.android.application") version "8.3.2"
        id("org.jetbrains.kotlin.android") version "1.9.23"
    }
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
    }
}

rootProject.name = "UniferAndroid"
include(":app")
