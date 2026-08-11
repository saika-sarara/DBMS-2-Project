package com.learnova.course.controller;

import com.learnova.course.dto.PersonalizedCataloguePageResponse;
import com.learnova.course.dto.CategoryResponse;
import com.learnova.course.dto.CourseSearchRequest;
import com.learnova.course.service.PublicCourseService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/catalogue")
public class CourseController {

    private final PublicCourseService publicCourseService;

    public CourseController(
            PublicCourseService publicCourseService
    ) {
        this.publicCourseService = publicCourseService;
    }

    /**
     * Returns all active course categories.
     *
     * Public endpoint:
     * GET /api/v1/catalogue/categories
     */
    @GetMapping("/categories")
    public List<CategoryResponse> getActiveCategories() {
        return publicCourseService.getActiveCategories();
    }

    /**
     * Searches and filters publicly visible courses.
     *
     * Public endpoint:
     * GET /api/v1/catalogue/courses
     *
     * Supported query parameters:
     * - search
     * - categoryId
     * - difficulty
     * - sort
     * - page
     * - size
     */
    @GetMapping("/courses")
    public PersonalizedCataloguePageResponse searchCourses(
            @RequestParam(required = false)
            String search,

            @RequestParam(required = false)
            Long categoryId,

            @RequestParam(required = false)
            String difficulty,

            @RequestParam(defaultValue = "relevance")
            String sort,

            @RequestParam(defaultValue = "0")
            int page,

            @RequestParam(defaultValue = "12")
            int size
    ) {
        CourseSearchRequest request =
                new CourseSearchRequest(
                        search,
                        categoryId,
                        difficulty,
                        sort,
                        page,
                        size
                );

        return publicCourseService.searchCourses(request);
    }

    /*
     * This handler keeps catalogue validation errors as HTTP 400
     * without replacing or weakening the project's existing global
     * exception handling.
     */
    @ExceptionHandler({
            IllegalArgumentException.class,
            MethodArgumentTypeMismatchException.class
    })
    public ResponseEntity<Map<String, Object>> handleInvalidRequest(
            Exception exception,
            HttpServletRequest request
    ) {
        String message;

        if (exception instanceof MethodArgumentTypeMismatchException mismatch) {
            String expectedType = mismatch.getRequiredType() == null
                    ? "valid value"
                    : mismatch.getRequiredType().getSimpleName();

            message = "Parameter '"
                    + mismatch.getName()
                    + "' must contain a valid "
                    + expectedType
                    + " value.";
        } else {
            message = exception.getMessage();

            if (message == null || message.isBlank()) {
                message = "The catalogue request contains an invalid value.";
            }
        }

        Map<String, Object> body = new LinkedHashMap<>();

        body.put(
                "timestamp",
                OffsetDateTime.now(ZoneOffset.UTC).toString()
        );

        body.put(
                "status",
                HttpStatus.BAD_REQUEST.value()
        );

        body.put(
                "error",
                HttpStatus.BAD_REQUEST.getReasonPhrase()
        );

        body.put(
                "message",
                message
        );

        body.put(
                "path",
                request.getRequestURI()
        );

        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(body);
    }
}