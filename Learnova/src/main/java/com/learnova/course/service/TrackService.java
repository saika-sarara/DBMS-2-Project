package com.learnova.course.service;

import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.course.dto.TrackResponse;
import com.learnova.course.repository.TrackRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class TrackService {

    private final TrackRepository trackRepository;

    public TrackService(TrackRepository trackRepository) {
        this.trackRepository = trackRepository;
    }

    public List<TrackResponse> findPublished() {
        return trackRepository.findPublished();
    }

    public TrackResponse findPublishedById(Long trackId) {
        if (trackId == null || trackId < 1) {
            throw new IllegalArgumentException("trackId must be greater than zero.");
        }
        TrackResponse response = trackRepository.findPublishedById(trackId);
        if (response == null) {
            throw new ResourceNotFoundException("Published track was not found.");
        }
        return response;
    }
}