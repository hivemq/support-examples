plugins {
    alias(libs.plugins.hivemq.extension)
    alias(libs.plugins.defaults)
    alias(libs.plugins.license)
}

group = "com.hivemq.extensions"
description = "HiveMQ 4 Hello Read Extension - a simple sample"

hivemqExtension {
    name = "Hello Read Extension"
    author = "HiveMQ"
    priority = 1100
    startPriority = 1100
    mainClass = "$group.helloworld.HelloWorldMain"
    sdkVersion = "$version"

    resources {
        from("LICENSE")
    }
}

@Suppress("UnstableApiUsage")
testing {
    suites {
        withType<JvmTestSuite> {
            useJUnitJupiter(libs.versions.junit.jupiter)
        }
        "test"(JvmTestSuite::class) {
            dependencies {
                implementation(libs.mockito)
            }
        }
        "integrationTest"(JvmTestSuite::class) {
            dependencies {
                compileOnly(libs.jetbrains.annotations)
                implementation(libs.hivemq.mqttClient)
                implementation(libs.testcontainers.junitJupiter)
                implementation(libs.testcontainers.hivemq)
                runtimeOnly(libs.logback.classic)
            }
        }
    }
}

license {
    header = rootDir.resolve("HEADER")
    mapping("java", "SLASHSTAR_STYLE")
}

/* ******************** debugging ******************** */

tasks.prepareHivemqHome {
    hivemqHomeDirectory = file("/your/path/to/hivemq-<VERSION>")
}

tasks.runHivemqWithExtension {
    debugOptions {
        enabled = false
    }
}
