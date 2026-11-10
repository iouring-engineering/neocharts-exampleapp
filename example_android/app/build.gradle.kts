import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// The NeoCharts licence home key, from the untracked local.properties
// (`neocharts.homeKey=...`); blank means no key, and the licence error shows.
val neochartsHomeKey: String = Properties().run {
    rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
    getProperty("neocharts.homeKey", "").trim()
}

android {
    namespace = "com.example.example_android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.example_android"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField(
            "String",
            "NEOCHARTS_HOME_KEY",
            "\"" + neochartsHomeKey.replace("\\", "\\\\").replace("\"", "\\\"") + "\"",
        )
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
    }
}

dependencies {
    // NeoCharts SDK (built AAR)
    implementation("com.iouring.neocharts:flutter_release:1.0")

    coreLibraryDesugaring(libs.desugar.jdk.libs)

    // AndroidX & Material
    implementation(libs.androidx.core.ktx.v1131)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)

    // Testing
    testImplementation(libs.junit)
    // A real org.json for JVM tests; android.jar's is a stub there.
    testImplementation(libs.org.json)
    androidTestImplementation(libs.androidx.junit.v115)
    androidTestImplementation(libs.androidx.espresso.core.v351)

    // Jetpack Compose
    implementation("androidx.compose.material:material-icons-extended:1.7.8")
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)

    debugImplementation(libs.androidx.ui.tooling)
}
