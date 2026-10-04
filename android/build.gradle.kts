// 塔塔聊天 SDK 的 Android 库模块只声明唯一包身份以及编译、运行和 Java 基线。
plugins {
    id("com.android.library")
}

group = "chat.tata.sdk"
version = "1.0.0"

android {
    namespace = "chat.tata.sdk"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
