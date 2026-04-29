package com.grandlabs.buggy.controller;

import lombok.AccessLevel;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;

@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
@RequiredArgsConstructor
@RestController
public class BuggyControllerImpl implements BuggyController {

    /**
     * Responds with a simple greeting message.
     *
     * @return a ResponseEntity with HTTP status 200 (OK) and body "Hello World!"
     */
    @Override
    public ResponseEntity<String> helloWorld() {
        return ResponseEntity.ok("Hello World!");
    }
}
