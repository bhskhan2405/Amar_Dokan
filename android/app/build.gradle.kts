plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.bhskhan.amardokan"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.bhskhan.amardokan"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Force copy the APK to where Flutter expects it
tasks.register<Copy>("copyApkToFlutterDir") {
    from("${layout.buildDirectory.get().asFile}/outputs/apk/debug/app-debug.apk")
    into("${project.rootProject.projectDir}/../build/app/outputs/flutter-apk")
}

project.afterEvaluate {
    tasks.named("assembleDebug") {
        finalizedBy("copyApkToFlutterDir")
    }
}

flutter {
    source = "../.."
}

dependencies {
}
