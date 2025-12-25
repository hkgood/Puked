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

subprojects {
    project.evaluationDependsOn(":app")
}

// 核心补丁：解决 isar_flutter_libs 缺失 namespace 的问题
subprojects {
    val project = this
    if (project.name.contains("isar_flutter_libs")) {
        project.afterEvaluate {
            val android = project.extensions.findByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                android.namespace = "dev.isar.isar_flutter_libs"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
