plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.asiamatrix.matrixcondo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications: the plugin uses java.time
        // APIs through desugared libraries so notifications behave the same on
        // older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.asiamatrix.matrixcondo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
        flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }

        create("prod") {
            dimension = "environment"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Paired with isCoreLibraryDesugaringEnabled above: the version the
    // flutter_local_notifications documentation asks for.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    constraints {
        // firebase_in_app_messaging 0.10.0 exports firebase-inappmessaging and
        // firebase-inappmessaging-display as `api` dependencies without a
        // version, and it only applies the Firebase BoM to its own
        // implementation configuration. That leaves the versionless modules
        // unresolvable on the app compile classpath, so pin them here to the
        // versions the BoM (FirebaseSDKVersion=35.0.0) provides.
        implementation("com.google.firebase:firebase-inappmessaging:23.0.0")
        implementation("com.google.firebase:firebase-inappmessaging-display:23.0.0")
    }
}

flutter {
    source = "../.."
}
