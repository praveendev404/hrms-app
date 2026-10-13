import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vectoredge.hrms"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications (scheduled reminders).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vectoredge.hrms"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Support for all device architectures
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }

        // Add applicationName for AndroidManifest.xml
        manifestPlaceholders["applicationName"] = "com.vectoredge.hrms.MainApplication"
    }
    
    // Enable splits for different device types (optional - for smaller APKs)
    splits {
        abi {
            isEnable = false // Set to true if you want separate APKs per architecture
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            isUniversalApk = true // Create universal APK that works on all devices
        }
    }

    signingConfigs {
        create("release") {
            // Load keystore properties from key.properties file if it exists
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystorePropertiesFile.inputStream().use {
                    keystoreProperties.load(it)
                }
                
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
                val storeFileProp = keystoreProperties.getProperty("storeFile")
                if (storeFileProp != null) {
                    storeFile = file(storeFileProp)
                }
                storePassword = keystoreProperties.getProperty("storePassword") ?: ""
            } else {
                // Fallback to debug signing if key.properties doesn't exist
                // This allows building without signing setup for testing
            }
        }
    }

    buildTypes {
        release {
            // Use release signing if configured, otherwise fallback to debug
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
                isMinifyEnabled = false  // Disabled temporarily to avoid R8 issues
                // proguardFiles(
                //     getDefaultProguardFile("proguard-android-optimize.txt"),
                //     "proguard-rules.pro"
                // )
            } else {
                // Debug signing for development/testing
                signingConfig = signingConfigs.getByName("debug")
                isMinifyEnabled = false  // Disabled to avoid R8 issues
            }
            // Explicitly disable resource shrinking when minification is off
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
