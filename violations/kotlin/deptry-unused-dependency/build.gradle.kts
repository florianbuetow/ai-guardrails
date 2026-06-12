import io.gitlab.arturbosch.detekt.Detekt

plugins {
    application
    kotlin("jvm") version "2.1.20"
    id("io.gitlab.arturbosch.detekt") version "1.23.8"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.2"
    id("org.jetbrains.kotlinx.kover") version "0.9.1"
    id("com.github.ben-manes.versions") version "0.51.0"
    id("com.autonomousapps.dependency-analysis") version "2.7.0"
}

group = "com.example"
version = "0.1.0"

kotlin {
    jvmToolchain(21)
    compilerOptions {
        // Strict compilation: every compiler warning is a build error.
        // This is the LSP-equivalent guardrail (mirrors javac -Werror).
        allWarningsAsErrors = true
    }
}

application {
    mainClass = "com.example.testcliproject.MainKt"
}

repositories {
    mavenCentral()
}

dependencies {
    // Intentionally unused dependency for dependency-hygiene testing.
    implementation("com.google.guava:guava:33.4.0-jre")

    // Testing
    testImplementation(platform("org.junit:junit-bom:5.11.4"))
    testImplementation("org.junit.jupiter:junit-jupiter-api")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core:3.27.3")

    // Konsist — architecture constraint tests
    testImplementation("com.lemonappdev:konsist:0.17.3")
}

// --- detekt (static analysis: bug patterns, complexity, exception handling) ---
detekt {
    buildUponDefaultConfig = true
    allRules = false
    config.setFrom(files("config/detekt/detekt.yml"))
    basePath = projectDir.path
}

tasks.withType<Detekt>().configureEach {
    reports {
        html.required = true
        xml.required = false
        txt.required = false
        sarif.required = false
    }
}

// --- ktlint (formatting and style, including wildcard imports) ---
ktlint {
    version = "1.5.0"
    ignoreFailures = false
    reporters {
        reporter(org.jlleitschuh.gradle.ktlint.reporter.ReporterType.PLAIN)
    }
}

// --- Kover (code coverage) ---
kover {
    reports {
        verify {
            rule {
                minBound(80)
            }
        }
    }
}

// --- Dependency locking (for vulnerability scanning with trivy) ---
configurations {
    compileClasspath { resolutionStrategy.activateDependencyLocking() }
    runtimeClasspath { resolutionStrategy.activateDependencyLocking() }
    testCompileClasspath { resolutionStrategy.activateDependencyLocking() }
    testRuntimeClasspath { resolutionStrategy.activateDependencyLocking() }
}

// --- Dependency analysis (unused / undeclared dependency hygiene) ---
dependencyAnalysis {
    issues {
        all {
            onAny {
                severity("fail")
            }
        }
    }
}

// --- Test configuration ---
tasks.test {
    useJUnitPlatform()
}
