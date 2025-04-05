plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.frontend"
    compileSdk = flutter.compileSdkVersion.toInt()

    defaultConfig {
        applicationId = "com.example.frontend"
        minSdk = 24 // Minimum pour local_auth
        targetSdk = flutter.targetSdkVersion.toInt()
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        multiDexEnabled = true
        
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for the release build
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // Configuration spécifique pour le débogage
            isDebuggable = true
        }
    }

    // Configuration pour éviter les conflits de packaging
    packaging {
        resources {
            excludes += "META-INF/*"
        }
    }

    // Activation du viewBinding si nécessaire
    buildFeatures {
        viewBinding = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Ajoutez cette ligne pour le support multidex
    implementation("androidx.multidex:multidex:2.0.1")

    // Dependencies pour OpenStreetMap (optionnel)
    implementation("org.osmdroid:osmdroid-android:6.1.16")
}