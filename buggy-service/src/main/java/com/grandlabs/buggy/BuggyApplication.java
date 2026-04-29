package com.grandlabs.buggy;

import org.springframework.boot.Banner;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;

@SpringBootApplication
public class BuggyApplication {

    /**
     * Application entry point that builds and runs the Spring Boot application with the startup banner disabled.
     *
     * @param args command-line arguments forwarded to the Spring application
     */
    public static void main(String[] args) {
        new SpringApplicationBuilder(BuggyApplication.class)
                .bannerMode(Banner.Mode.OFF)
                .run(args);
    }
}

