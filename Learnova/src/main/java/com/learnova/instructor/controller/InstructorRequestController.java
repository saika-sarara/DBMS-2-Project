package com.learnova.instructor.controller;

import com.learnova.instructor.dto.InstructorRequestCreateRequest;
import com.learnova.instructor.dto.InstructorRequestResponse;
import com.learnova.instructor.service.InstructorRequestService;
import com.learnova.security.UserPrincipal;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/instructor-requests")
@CrossOrigin(origins = "*")
public class InstructorRequestController {

    private final InstructorRequestService instructorRequestService;

    public InstructorRequestController(InstructorRequestService instructorRequestService) {
        this.instructorRequestService = instructorRequestService;
    }

    @GetMapping("/mine")
    public InstructorRequestResponse mine(Authentication authentication) {
        return instructorRequestService.mine(currentUserId(authentication));
    }

    @PostMapping
    public InstructorRequestResponse create(
            @RequestBody InstructorRequestCreateRequest request,
            Authentication authentication
    ) {
        return instructorRequestService.create(currentUserId(authentication), request);
    }

    private Long currentUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();

        if (principal instanceof UserPrincipal userPrincipal) {
            return userPrincipal.getId();
        }

        throw new IllegalArgumentException("Authenticated user was not found.");
    }
}
