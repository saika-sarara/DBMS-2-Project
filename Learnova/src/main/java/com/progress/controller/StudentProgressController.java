package com.learnova.progress.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/student/progress")
public class StudentProgressController {

    @GetMapping("/course/{courseId}")
    public ResponseEntity<?> getCourseProgress(@PathVariable Long courseId) {
        // Returns recalculation of completed modules and quizzes
        return ResponseEntity.ok().build();
    }

    @GetMapping("/track/{trackId}")
    public ResponseEntity<?> getTrackProgress(@PathVariable Long trackId) {
        // Returns overall learning track progress percentage
        return ResponseEntity.ok().build();
    }
}