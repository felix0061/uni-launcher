plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "xyz.i4o.uni.launcher"
    compileSdk = flutter.compileSdkVersion
    buildFeatures { buildConfig = true }

    // Compress native libraries in APKs. Android extracts them at install
    // time; this reduces transfer size at the expense of installed disk usage.
    packaging {
        jniLibs { useLegacyPackaging = true }
    }


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "xyz.i4o.uni.launcher"
        minSdk = 24
        // Dedicated Android 9 head unit, distributed locally rather than through Play.
        targetSdk = 28
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 离线语音引擎的设备级冒烟测试（模型加载/合成），本机模拟器与车机均可跑
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    lint {
        // Keep release lint enabled; the Play target API deadline does not apply here.
        disable += "ExpiredTargetSdkVersion"
    }

    sourceSets.getByName("main") {
        java.srcDirs("src/main/java/xyz/i4o/uni/launcher/integration", "src/main/java/xyz/i4o/uni/launcher/core")
        assets.srcDir(layout.buildDirectory.dir("generated/officialCatalog").get().asFile)
    }
    signingConfigs {
        create("uniLocal") {
            storeFile = file(System.getenv("UNI_SIGNING_STORE") ?: "/data/tools/linkco-android/uni-debug.keystore")
            storePassword = "android"
            keyAlias = "uni-debug"
            keyPassword = "android"
        }
    }
    buildTypes {
        debug { signingConfig = signingConfigs.getByName("uniLocal") }
        release {
            // Local test distribution using the existing baseline development certificate.
            signingConfig = signingConfigs.getByName("uniLocal")
            // sherpa-onnx 的 JNI 层用 GetFieldID 按名字读取 Kotlin data class 字段
            // （maxActivePaths / keywordsFile / numTrailingBlanks ...）。R8 会把类和字段
            // 重命名成单字母，JNI 找不到字段就直接抛
            // "Failed to get field ID for maxActivePaths"，引擎降级到 stub。
            // dex 本身不到 1MB，关掉压缩混淆换取离线引擎加载的确定性。
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
    androidTestImplementation("androidx.test.ext:junit:1.1.2")
    androidTestImplementation("androidx.test:runner:1.3.0")
    // 语音已拆成独立 APK（:voice 模块自带 sherpa-onnx 与模型）：
    // 桌面这边不再依赖 sherpa-onnx / okhttp，安装包少掉一整套原生库
}

val syncOfficialCatalog by tasks.registering(Copy::class) {
    from("../../../analysis/official-widgets.json")
    into(layout.buildDirectory.dir("generated/officialCatalog"))
}
tasks.named("preBuild") { dependsOn(syncOfficialCatalog) }
