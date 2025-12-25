allprojects {
    repositories {
        google()
        mavenCentral()
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
}

// 移除掉这个可能导致 Evaluation 顺序冲突的行
// subprojects {
//    project.evaluationDependsOn(":app")
// }

// 核心补丁：统一所有子项目的 JVM 版本为 17，并解决 isar 缺失 namespace 问题
allprojects {
    val p = this
    val configureProject = Action<Project> {
        // 1. 解决 isar_flutter_libs 缺失 namespace 问题
        if (p.name.contains("isar_flutter_libs")) {
            p.extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
                if (namespace == null) namespace = "dev.isar.isar_flutter_libs"
            }
        }

        // 2. 强制同步 Java 和 Kotlin 的 JVM 版本为 17
        p.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
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

    // 如果项目已经评估过，立即执行；否则等待评估完成后执行
    if (p.state.executed) {
        configureProject.execute(p)
    } else {
        p.afterEvaluate(configureProject)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
