package com.grandlabs.buggy.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Tag(name = "Buggy Controller", description = "API for bugs")
@RequestMapping("/api/v1/buggy")
public interface BuggyController {

    @Operation(
            summary = "get hello world",
            description = "returns hello world"
    )
    @GetMapping("/")
    ResponseEntity<String> helloWorld();
}