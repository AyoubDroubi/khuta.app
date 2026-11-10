buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.21")
    }
}

plugins {
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.21" apply false
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

// Plugins like home_widget default to JVM 1.8 but inline JVM-11 bytecode from
// Glance/Compose; align every module to 17, matching :app.
subprojects {
    val alignJvm: Project.() -> Unit = {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"; targetCompatibility = "17"
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
        }
    }
    if (state.executed) alignJvm() else afterEvaluate { alignJvm() }
}

// home_widget declares `glance-appwidget:1.+`, which can resolve to a new
// alpha that needs a newer AGP/compileSdk. Pin Glance in every module, not
// only :app, so builds are reproducible.
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.1")
            force("androidx.glance:glance-material3:1.1.1")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
