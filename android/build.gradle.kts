allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        gradlePluginPortal()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // 强制同步所有项目的 Kotlin 版本，解决 image_gallery_saver_plus 等插件的版本冲突
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.1.0") // 2026年 2.1.0 是非常稳定的版本
            }
        }
    }
}

// 核心补丁：统一所有子项目的 JVM 版本为 17，并解决 namespace 缺失问题
// 特别针对 Isar 3.x 等老旧插件，在配置阶段物理修复 Manifest 冲突
allprojects {
    val p = this
    
    // 激进修复：直接物理移除 Manifest 中的 package 属性
    // 必须在配置阶段执行，以绕过 AGP 8.10+ 的预扫描报错
    val manifestFile = File(p.projectDir, "src/main/AndroidManifest.xml")
    if (manifestFile.exists()) {
        val content = manifestFile.readText()
        if (content.contains("package=")) {
            println("--- AGP Compatibility Fix: Patching ${p.name} manifest at ${manifestFile.absolutePath}")
            val updatedContent = content.replace(Regex("""\s+package="[^"]*""""), "")
            manifestFile.writeText(updatedContent)
        }
    }

    val configureProject = Action<Project> {
        // 1. 解决部分插件缺失 namespace 的通用问题
        p.extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
            if (namespace == null) {
                namespace = "com.puked.generated.${p.name.replace("-", "_")}"
            }
        }

        // 2. 强制同步 Java 和 Kotlin 的 JVM 版本为 17，并提升 compileSdkVersion
        p.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileSdkVersion(36)
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }

        p.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    if (p.state.executed) {
        configureProject.execute(p)
    } else {
        p.afterEvaluate(configureProject)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
