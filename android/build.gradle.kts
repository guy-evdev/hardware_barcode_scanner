group = "com.eventer.hardware_barcode_scanner"
version = "1.0-SNAPSHOT"

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

// AGP 9 compiles Kotlin natively unless the host app opts out with android.builtInKotlin=false.
// Applying the Kotlin plugin on top of that fails the build.
val builtInKotlinEnabled =
    agpMajor >= 9 &&
        (providers.gradleProperty("android.builtInKotlin").orNull?.toBoolean() ?: true)

if (!builtInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

android {
    namespace = "com.eventer.hardware_barcode_scanner"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 21
        consumerProguardFiles("consumer-rules.pro")
    }
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
    outputs.upToDateWhen { false }

    testLogging {
        events("passed", "skipped", "failed", "standardOut", "standardError")
        showStandardStreams = true
    }
}

dependencies {
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar"))))
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
}
