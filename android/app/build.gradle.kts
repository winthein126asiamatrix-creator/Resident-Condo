
import java.util.Properties
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties().apply {
    val propertiesFile = file("${System.getProperty("user.home")}/keys/key.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use { load(it) }
    }
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

    signingConfigs {
        create("prodRelease") {
            val storePath = releaseKeyProperties.getProperty("storeFile")
            require(!storePath.isNullOrBlank()) {
                "Missing storeFile in C:/Users/winth/keys/key.properties"
            }
            storeFile = file(storePath)
            storePassword = releaseKeyProperties.getProperty("storePassword")
            keyAlias = releaseKeyProperties.getProperty("keyAlias")
            keyPassword = releaseKeyProperties.getProperty("keyPassword")
        }
    }

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            signingConfig = signingConfigs.getByName("debug")
            manifestPlaceholders["hostUrl"] = "matrix-condo-dev.web.app"
        }

        create("prod") {
            dimension = "environment"
            signingConfig = signingConfigs.getByName("prodRelease")
            manifestPlaceholders["hostUrl"] = "matrix-condo.web.app"
        }
    }

buildTypes {
    release {
        // Signing is configured per product flavor below.
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
