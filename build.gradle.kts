plugins {
    java
    id("org.springframework.boot") version "3.5.6"
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("com.google.api-client:google-api-client:2.7.2")
    implementation("com.google.auth:google-auth-library-oauth2-http:1.30.1")
    implementation("com.google.apis:google-api-services-sheets:v4-rev20260610-2.0.0")
}

tasks.bootJar {
    archiveFileName.set("AlloPayout.jar")
    mainClass.set("com.koreyhinton.AlloPayout")
}
