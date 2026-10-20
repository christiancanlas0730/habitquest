plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = java.util.Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

android {
    namespace = "com.habitquest.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this ID stable for APKPure updates and existing installations.
        applicationId = "com.habitquest.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingPropertiesFile.exists()) {
            create("release") {
                val storePath = signingProperties.getProperty("storeFile")
                    ?: throw GradleException("key.properties is missing storeFile")
                storeFile = rootProject.file(storePath)
                storePassword = signingProperties.getProperty("storePassword")
                    ?: throw GradleException("key.properties is missing storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                    ?: throw GradleException("key.properties is missing keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                    ?: throw GradleException("key.properties is missing keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to the debug certificate for a publishable build.
            if (signingPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

