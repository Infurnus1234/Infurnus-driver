if (System.getProperty("android.user.home") == null) {
    System.setProperty("android.user.home", rootProject.file(".gradle").absolutePath)
}
if (System.getProperty("ANDROID_PREFS_ROOT") == null) {
    System.setProperty("ANDROID_PREFS_ROOT", rootProject.file(".gradle/android_prefs").absolutePath)
}
if (System.getProperty("ANDROID_USER_HOME") == null) {
    System.setProperty("ANDROID_USER_HOME", rootProject.file(".gradle/android_user").absolutePath)
}

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
