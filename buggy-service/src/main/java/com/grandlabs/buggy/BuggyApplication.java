package com.grandlabs.buggy;

import org.springframework.boot.Banner;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;

@SpringBootApplication
public class BuggyApplication {

    public static void main(String[] args) {
        new SpringApplicationBuilder(BuggyApplication.class)
                .bannerMode(Banner.Mode.OFF)
                .run(args);
    }
}

