package com.learnova.prerequisite.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.prerequisite.dto.PrerequisiteEditorResponse;
import com.learnova.prerequisite.dto.PrerequisiteReplaceRequest;
import com.learnova.prerequisite.service.PrerequisiteService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(
        "/api/v1/instructor/courses/{courseId}/prerequisites"
)
@PreAuthorize(
        "hasAnyRole('INSTRUCTOR','ADMIN')"
)
public class PrerequisiteController {

    private final PrerequisiteService prerequisiteService;


    public PrerequisiteController(
            PrerequisiteService prerequisiteService
    ) {

        this.prerequisiteService =
                prerequisiteService;
    }


    @GetMapping
    public ResponseEntity<
            ApiResponse<PrerequisiteEditorResponse>
            > getEditor(
            @PathVariable Long courseId
    ) {

        PrerequisiteEditorResponse response =
                prerequisiteService.getEditor(
                        courseId
                );


        return ResponseEntity.ok(
                ApiResponse.ok(
                        response
                )
        );
    }


    @PutMapping
    public ResponseEntity<
            ApiResponse<PrerequisiteEditorResponse>
            > replacePrerequisites(
            @PathVariable Long courseId,
            @RequestBody PrerequisiteReplaceRequest request
    ) {

        PrerequisiteEditorResponse response =
                prerequisiteService
                        .replacePrerequisites(
                                courseId,
                                request
                        );


        return ResponseEntity.ok(
                ApiResponse.ok(
                        "Prerequisites saved",
                        response
                )
        );
    }
}