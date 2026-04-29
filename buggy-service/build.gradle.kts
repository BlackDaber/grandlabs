plugins {
    java
    id("org.springframework.boot")
    id("io.spring.dependency-management")
}

group = "com.grandlabs"
version = "0.0.1"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.postgresql:postgresql")
    implementation("org.liquibase:liquibase-core")

    implementation("org.springframework.boot:spring-boot-starter-data-jdbc")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation(libs.springdoc.openapi.starter)

    annotationProcessor("org.springframework.boot:spring-boot-configuration-processor")

    implementation(libs.spring.cloud.vault.starter)
    implementation(libs.logback)

    compileOnly(libs.lombok)
    annotationProcessor(libs.lombok)

    // --- Testing ---

    testImplementation("org.springframework.boot:spring-boot-starter-test")

    testImplementation("org.junit.jupiter:junit-jupiter-api")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

java {
    sourceCompatibility = JavaVersion.VERSION_25
    targetCompatibility = JavaVersion.VERSION_25
}

tasks {
    withType(JavaCompile::class) {
        options.encoding = "UTF-8"
    }
}