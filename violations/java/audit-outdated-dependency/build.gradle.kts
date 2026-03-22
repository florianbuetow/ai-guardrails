plugins {
    java
    application
    checkstyle
    jacoco
    id("com.diffplug.spotless") version "7.0.2"
    id("com.github.spotbugs") version "6.1.2"
    id("net.ltgt.errorprone") version "4.1.0"
    id("com.github.ben-manes.versions") version "0.51.0"
    id("com.autonomousapps.dependency-analysis") version "2.7.0"
}

group = "com.example"
version = "0.1.0"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

application {
    mainClass = "com.example.testcliproject.Main"
}

repositories {
    mavenCentral()
}

dependencies {
    // Error Prone
    errorprone("com.google.errorprone:error_prone_core:2.36.0")

    // SpotBugs annotations
    compileOnly("com.github.spotbugs:spotbugs-annotations:4.9.1")

    // Find Security Bugs plugin for SpotBugs
    spotbugsPlugins("com.h3xstream.findsecbugs:findsecbugs-plugin:1.13.0")

    // Testing — intentionally outdated JUnit to trigger code-audit failure
    testImplementation(platform("org.junit:junit-bom:5.9.0"))
    testImplementation("org.junit.jupiter:junit-jupiter-api")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.assertj:assertj-core:3.27.3")
    testImplementation("com.tngtech.archunit:archunit-junit5-api:1.4.0")
    testImplementation("com.tngtech.archunit:archunit:1.4.0")
    testRuntimeOnly("com.tngtech.archunit:archunit-junit5:1.4.0")
}

// --- Checkstyle ---
checkstyle {
    toolVersion = "10.21.4"
    configFile = file("config/checkstyle/checkstyle.xml")
    isIgnoreFailures = false
    maxWarnings = 0
}

// --- Spotless (formatting) ---
spotless {
    java {
        googleJavaFormat()
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}

// --- SpotBugs ---
spotbugs {
    effort = com.github.spotbugs.snom.Effort.MAX
    reportLevel = com.github.spotbugs.snom.Confidence.LOW
}

tasks.withType<com.github.spotbugs.snom.SpotBugsTask>().configureEach {
    reports.create("html") {
        required = true
    }
    reports.create("xml") {
        required = false
    }
}

// --- JaCoCo (code coverage) ---
jacoco {
    toolVersion = "0.8.12"
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required = true
        html.required = true
    }
}

tasks.jacocoTestCoverageVerification {
    dependsOn(tasks.jacocoTestReport)
    violationRules {
        rule {
            limit {
                minimum = "0.80".toBigDecimal()
            }
        }
    }
}

// --- Dependency Analysis ---
dependencyAnalysis {
    issues {
        all {
            onAny {
                severity("fail")
            }
        }
    }
}

// --- Dependency Audit ---
tasks.withType<com.github.benmanes.gradle.versions.updates.DependencyUpdatesTask>().configureEach {
    outputFormatter = "json"
    doLast {
        val reportFile = file("build/dependencyUpdates/report.json")
        if (!reportFile.exists()) {
            return@doLast
        }

        val report = groovy.json.JsonSlurper().parse(reportFile) as? Map<*, *> ?: return@doLast
        val outdated = report["outdated"] as? Map<*, *> ?: return@doLast
        val outdatedCount = when (val count = outdated["count"]) {
            is Number -> count.toInt()
            is String -> count.toIntOrNull() ?: 0
            else -> 0
        }

        if (outdatedCount > 0) {
            throw GradleException("Outdated dependencies found. Run './gradlew dependencyUpdates' to see details.")
        }
    }
}

// --- Test configuration ---
tasks.test {
    useJUnitPlatform()
    finalizedBy(tasks.jacocoTestReport)
}

// --- LSP-equivalent compiler checks (javac -Xlint:all -Werror) ---
tasks.register<JavaCompile>("lspChecks") {
    description = "Compile with strict javac warnings (-Xlint:all -Werror)"
    source = sourceSets.main.get().java
    classpath = sourceSets.main.get().compileClasspath
    destinationDirectory = layout.buildDirectory.dir("classes/lspChecks")
    options.compilerArgs.addAll(listOf("-Xlint:all", "-Werror"))
}

// --- Build lifecycle ---
tasks.check {
    dependsOn(
        tasks.named("spotlessCheck"),
        tasks.named("checkstyleMain"),
        tasks.named("checkstyleTest"),
        tasks.named("spotbugsMain"),
        tasks.named("spotbugsTest"),
        tasks.named("jacocoTestCoverageVerification"),
    )
}
