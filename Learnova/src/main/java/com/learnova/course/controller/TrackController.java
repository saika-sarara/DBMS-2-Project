package com.learnova.course.controller;

import com.learnova.course.dto.TrackResponse;
import com.learnova.course.service.TrackService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/tracks")
public class TrackController {

    private final TrackService trackService;

    public TrackController(TrackService trackService) {
        this.trackService = trackService;
    }

    @GetMapping
    public List<TrackResponse> listPublished() {
        return trackService.findPublished();
    }

    @GetMapping("/{trackId}")
    public TrackResponse getPublished(@PathVariable Long trackId) {
        return trackService.findPublishedById(trackId);
    }
}