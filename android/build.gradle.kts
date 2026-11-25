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
// Flutter and its plugins default to flutter.ndkVersion (28.2.13676358), which
// is not installed on this machine. Point every Android module at the NDK that
// is actually installed, so the build does not try to download another one.
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
        val setNdkVersion =
            androidExtension.javaClass.methods.firstOrNull { method ->
                method.name == "setNdkVersion" &&
                    method.parameterTypes.size == 1 &&
                    method.parameterTypes[0] == String::class.java
            } ?: return@afterEvaluate
        setNdkVersion.invoke(androidExtension, "30.0.16248370")
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
