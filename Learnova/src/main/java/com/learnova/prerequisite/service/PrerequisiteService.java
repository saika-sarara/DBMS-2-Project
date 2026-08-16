package com.learnova.prerequisite.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.learnova.common.exception.DatabaseException;
import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.prerequisite.dto.PrerequisiteEditorResponse;
import com.learnova.prerequisite.dto.PrerequisiteReplaceRequest;
import com.learnova.prerequisite.repository.PrerequisiteRepository;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PrerequisiteService {

    private static final TypeReference<
            List<PrerequisiteEditorResponse.Prerequisite>
            > PREREQUISITE_LIST_TYPE =
            new TypeReference<>() {
            };


    private static final TypeReference<
            List<PrerequisiteEditorResponse.Candidate>
            > CANDIDATE_LIST_TYPE =
            new TypeReference<>() {
            };


    private final CurrentUserResolver currentUserResolver;

    private final PrerequisiteRepository prerequisiteRepository;

    private final ObjectMapper objectMapper;


    public PrerequisiteService(
            CurrentUserResolver currentUserResolver,
            PrerequisiteRepository prerequisiteRepository,
            ObjectMapper objectMapper
    ) {

        this.currentUserResolver =
                currentUserResolver;

        this.prerequisiteRepository =
                prerequisiteRepository;

        this.objectMapper =
                objectMapper;
    }


    public PrerequisiteEditorResponse getEditor(
            Long courseId
    ) {

        validateCourseId(
                courseId
        );


        Long actorId =
                currentUserResolver
                        .getCurrentUserId();


        try {

            PrerequisiteRepository.PrerequisiteEditorRow row =
                    prerequisiteRepository.findEditor(
                            actorId,
                            courseId
                    );


            if (row == null) {

                throw new ResourceNotFoundException(
                        "Course prerequisite editor was not found."
                );
            }


            return mapEditor(
                    row
            );

        } catch (DataAccessException ex) {

            throw DatabaseException.from(
                    ex
            );
        }
    }


    public PrerequisiteEditorResponse replacePrerequisites(
            Long courseId,
            PrerequisiteReplaceRequest request
    ) {

        validateCourseId(
                courseId
        );


        if (request == null) {

            throw new IllegalArgumentException(
                    "Prerequisite data is required."
            );
        }


        Long actorId =
                currentUserResolver
                        .getCurrentUserId();


        try {

            /*
             * Spring serializes the request as transport data only.
             *
             * PostgreSQL remains responsible for validating:
             *
             *   - prerequisite IDs
             *   - duplicates
             *   - score bounds
             *   - score precision
             *   - course ownership
             *   - course lifecycle
             *   - candidate validity
             *   - circular dependencies
             *   - maximum chain depth
             */
            String prerequisitesJson =
                    objectMapper.writeValueAsString(
                            request.prerequisites()
                    );


            PrerequisiteRepository.PrerequisiteEditorRow row =
                    prerequisiteRepository.replacePrerequisites(
                            actorId,
                            courseId,
                            prerequisitesJson
                    );


            if (row == null) {

                throw new ResourceNotFoundException(
                        "Course prerequisite editor was not found."
                );
            }


            return mapEditor(
                    row
            );

        } catch (JsonProcessingException ex) {

            throw new IllegalArgumentException(
                    "Prerequisite data could not be serialized.",
                    ex
            );

        } catch (DataAccessException ex) {

            throw DatabaseException.from(
                    ex
            );
        }
    }


    private PrerequisiteEditorResponse mapEditor(
            PrerequisiteRepository.PrerequisiteEditorRow row
    ) {

        try {

            List<PrerequisiteEditorResponse.Prerequisite>
                    prerequisites =
                    readPrerequisites(
                            row.prerequisitesJson()
                    );


            List<PrerequisiteEditorResponse.Candidate>
                    candidates =
                    readCandidates(
                            row.candidatesJson()
                    );


            return new PrerequisiteEditorResponse(

                    row.targetCourseId(),

                    row.targetTitle(),

                    row.targetSlug(),

                    row.targetStatus(),

                    row.editable(),

                    prerequisites,

                    candidates
            );

        } catch (JsonProcessingException ex) {

            /*
             * This represents a broken DB/API contract rather than a
             * user business-rule error.
             */
            throw new IllegalStateException(
                    "Database returned invalid prerequisite editor JSON.",
                    ex
            );
        }
    }


    private List<PrerequisiteEditorResponse.Prerequisite>
    readPrerequisites(
            String json
    ) throws JsonProcessingException {

        if (
                json == null ||
                json.isBlank()
        ) {
            return List.of();
        }


        return objectMapper.readValue(
                json,
                PREREQUISITE_LIST_TYPE
        );
    }


    private List<PrerequisiteEditorResponse.Candidate>
    readCandidates(
            String json
    ) throws JsonProcessingException {

        if (
                json == null ||
                json.isBlank()
        ) {
            return List.of();
        }


        return objectMapper.readValue(
                json,
                CANDIDATE_LIST_TYPE
        );
    }


    private void validateCourseId(
            Long courseId
    ) {

        if (
                courseId == null ||
                courseId < 1
        ) {

            throw new IllegalArgumentException(
                    "A valid course id is required."
            );
        }
    }
}