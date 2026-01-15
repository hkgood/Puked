// 统一管理版本号，避免在代码中散落硬编码
object BuildVersions {
    const val KOTLIN = "2.1.0"
    const val AGP_COMPILE_SDK = 36
    const val JVM_TARGET = 17
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // 只有在没有环境变量指明禁用镜像时才使用镜像，增加灵活性
        if (System.getenv("SKIP_MIRRORS") == null) {
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://maven.aliyun.com/repository/google") }
        }
        gradlePluginPortal()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // 统一 Kotlin 版本
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion(BuildVersions.KOTLIN)
            }
        }
    }

    // 配置完成后统一修复 AGP 兼容性问题
    afterEvaluate {
        val p = this
        
        // 1. 解决命名空间 (Namespace) 缺失或冲突问题
        // 这是 AGP 8.0+ 的核心要求
        val androidExtension = p.extensions.findByName("android")
        if (androidExtension != null) {
            val namespaceValue = "com.puked.generated.${p.name.replace("-", "_")}"
            
            when (androidExtension) {
                is com.android.build.gradle.LibraryExtension -> {
                    if (androidExtension.namespace == null) {
                        androidExtension.namespace = namespaceValue
                    }
                }
                is com.android.build.gradle.AppExtension -> {
                    if (androidExtension.namespace == null) {
                        androidExtension.namespace = namespaceValue
                    }
                }
            }

            // 2. 统一 JVM 版本和 SDK 版本
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(BuildVersions.AGP_COMPILE_SDK)
                androidExtension.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }

        // 3. 强制 Kotlin 编译目标
        p.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

// 针对 Isar 3.x 等老旧插件的 Manifest 兼容性补丁
// 采用更温和的方式：仅在发现 package 属性时进行处理，并添加详细日志
tasks.register("patchOldPluginsManifests") {
    doLast {
        subprojects.forEach { p ->
            val manifestFile = File(p.projectDir, "src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    logger.lifecycle("--- AGP Compatibility: Patching manifest for plugin '${p.name}'")
                    val updatedContent = content.replace(Regex("""\s+package="[^"]*""""), "")
                    manifestFile.writeText(updatedContent)
                }
            }
        }
    }
}

// 确保在编译前执行补丁
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            tasks.matching { it.name.contains("PreBuild") }.configureEach {
                dependsOn(":patchOldPluginsManifests")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
