import com.android.build.gradle.internal.api.BaseVariantOutputImpl
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
import java.util.Properties
import java.io.FileInputStream
        import org.jetbrains.kotlin.gradle.dsl.JvmTarget

android {
            namespace = "com.vartrusdata.vartchat.vartchat"
            compileSdk = 37

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }



            sourceSets {
                getByName("main") {
                    java.srcDir("src/main/kotlin")
                }
            }

            defaultConfig {
                applicationId = "com.vartrusdata.vartchat.vartchat"
                minSdk = flutter.minSdkVersion
                targetSdk = 37
                versionCode = flutter.versionCode
                versionName = flutter.versionName
            }

            // Загружаем свойства из keystore.properties (находится в корне проекта)
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = Properties()
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            }

            signingConfigs {
                create("release") {
                    if (keystorePropertiesFile.exists()) {
                        // Явно указываем тип String?
                        val alias: String? = keystoreProperties.getProperty("keyAlias")
                        val keyPwd: String? = keystoreProperties.getProperty("keyPassword")
                        val storePwd: String? = keystoreProperties.getProperty("storePassword")
                        val storePath: String? = keystoreProperties.getProperty("storeFile")

                        // Проверяем, что ни одно свойство не null и не пусто
                        if (alias.isNullOrBlank() || keyPwd.isNullOrBlank() || storePwd.isNullOrBlank() || storePath.isNullOrBlank()) {
                            throw GradleException("key.properties: одно из свойств (keyAlias, keyPassword, storePassword, storeFile) отсутствует или пусто.")
                        }

                        // Присваиваем (теперь типы совпадают)
                        keyAlias = alias
                        keyPassword = keyPwd
                        storePassword = storePwd
                        storeFile = file(storePath)
                    } else {
                        // Если файла нет — используем debug-ключ (только для тестов, не для релиза)
                        logger.warn("key.properties не найден! Используется отладочная подпись для release-сборки (не для публикации).")
                        keyAlias = "vartchat"
                        keyPassword = "123456"
                        storePassword = "123456"
                        storeFile = file("C:\\Users\\builder\\AndroidStudioProjects\\vartchat\\my-keystore.jks")
                    }
                }
            }

            buildTypes {
                getByName("release") {

                    signingConfig = signingConfigs.getByName("release")
                }
                getByName("debug") {
                    signingConfig = signingConfigs.getByName("release")
                }
                getByName("profile") {
                    signingConfig = signingConfigs.getByName("release")
                }
            }
            applicationVariants.all {
    // Только для release-сборки
    if (buildType.name != "release") return@all

    val versionName = defaultConfig.versionName
    val versionCode = defaultConfig.versionCode

    outputs.all {
        val output = this as BaseVariantOutputImpl
        if (output.outputFileName.endsWith(".apk")) {
            output.outputFileName =
                "../../flutter-apk/vartchat-${versionName}(${versionCode}).apk"
        }
    }

    // Удаляем старый APK до упаковки: если версия в pubspec.yaml не менялась,
    // имя файла совпадёт, и IncrementalSplitter упадёт с "already contains entry".
    val flutterRoot = rootProject.projectDir.parentFile
    val oldApk = File(
        flutterRoot,
        "build/app/outputs/flutter-apk/vartchat-${versionName}(${versionCode}).apk"
    )
    val packageTaskName = "package${name.replaceFirstChar { it.uppercaseChar() }}"

    tasks.matching { it.name == packageTaskName }.configureEach {
        doFirst {
            if (oldApk.exists()) {
                val deleted = oldApk.delete()
                println(
                    "[build.gradle.kts] Старый APK ${if (deleted) "удалён" else "НЕ УДАЛОСЬ удалить"}: ${oldApk.name}"
                )
            }
        }
    }
}
        }

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
