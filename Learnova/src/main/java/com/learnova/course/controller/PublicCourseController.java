package com.learnova.course.controller;

import com.learnova.course.dto.CategoryResponse;
import com.learnova.course.dto.CourseDetailsResponse;
import com.learnova.course.dto.CourseSearchRequest;
import com.learnova.course.dto.CourseSyllabusResponse;
import com.learnova.course.dto.LessonContentBlockResponse;
import com.learnova.course.dto.PersonalizedCataloguePageResponse;
import com.learnova.course.service.PublicCourseService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
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
@RequestMapping("/api/v1")
public class PublicCourseController {

    private final PublicCourseService publicCourseService;

    public PublicCourseController(PublicCourseService publicCourseService) {
        this.publicCourseService = publicCourseService;
    }

    @GetMapping("/categories")
    public List<CategoryResponse> getCategories() {
        return publicCourseService.getActiveCategories();
    }

    @GetMapping("/courses")
    public PersonalizedCataloguePageResponse searchCourses(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) String difficulty,
            @RequestParam(defaultValue = "relevance") String sort,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "12") int size
    ) {
        return publicCourseService.searchCourses(
                new CourseSearchRequest(
                        search,
                        categoryId,
                        difficulty,
                        sort,
                        page,
                        size
                )
        );
    }

    @GetMapping("/courses/{courseId}")
    public CourseDetailsResponse getCourseDetail(
            @PathVariable Long courseId
    ) {
        return publicCourseService.getCourseDetail(courseId);
    }

    @GetMapping("/courses/{courseId}/syllabus")
    public CourseSyllabusResponse getCourseSyllabus(
            @PathVariable Long courseId
    ) {
        return publicCourseService.getCourseSyllabus(courseId);
    }

    /*
     * Legacy alias kept so the existing frontend curriculum route keeps
     * working without changes. Both return the same syllabus structure.
     */
    @GetMapping("/courses/{courseId}/curriculum")
    public CourseSyllabusResponse getCourseCurriculum(
            @PathVariable Long courseId
    ) {
        return publicCourseService.getCourseSyllabus(courseId);
    }

    @GetMapping("/lessons/{lessonId}/content")
    public List<LessonContentBlockResponse> getLessonContent(
            @PathVariable Long lessonId
    ) {
        return publicCourseService.getLessonContent(lessonId);
    }

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
        }

        Map<String, Object> body = new LinkedHashMap<>();

        body.put(
                "timestamp",
                OffsetDateTime.now(ZoneOffset.UTC).toString()
        );

        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("error", "Bad Request");
        body.put("message", message);
        body.put("path", request.getRequestURI());

        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(body);
    }
}
