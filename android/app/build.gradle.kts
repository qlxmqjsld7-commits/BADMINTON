plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // 구글 서비스(Firebase)를 연결하는 핵심 열쇠이옵니다!
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.badminton"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.badminton"
        // 파이어베이스를 위해 23으로 높였나이다
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
    }
}

dependencies {
    implementation("com.android.support:multidex:1.0.3")
}