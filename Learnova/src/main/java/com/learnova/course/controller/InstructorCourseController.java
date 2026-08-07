package com.learnova.course.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.course.dto.ContentBlockCreateRequest;
import com.learnova.course.dto.ContentBlockResponse;
import com.learnova.course.dto.ContentBlockUpdateRequest;
import com.learnova.course.dto.CourseCreateRequest;
import com.learnova.course.dto.CourseLifecycleResponse;
import com.learnova.course.dto.CourseSyllabusResponse;
import com.learnova.course.dto.CourseUpdateRequest;
import com.learnova.course.dto.CurriculumReplaceRequest;
import com.learnova.course.dto.InstructorCourseResponse;
import com.learnova.course.dto.LessonCreateRequest;
import com.learnova.course.dto.LessonResponse;
import com.learnova.course.dto.LessonUpdateRequest;
import com.learnova.course.dto.ModuleCreateRequest;
import com.learnova.course.dto.ModuleResponse;
import com.learnova.course.dto.ModuleUpdateRequest;
import com.learnova.course.repository.CourseContentRepository;
import com.learnova.course.service.InstructorCourseService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/instructor")
public class InstructorCourseController {

    private final InstructorCourseService instructorCourseService;

    public InstructorCourseController(
            InstructorCourseService instructorCourseService
    ) {
        this.instructorCourseService = instructorCourseService;
    }

    @GetMapping("/courses")
    public ResponseEntity<ApiResponse<List<InstructorCourseResponse>>> listMyCourses() {
        return ResponseEntity.ok(
                ApiResponse.ok(instructorCourseService.listMyCourses())
        );
    }

    @GetMapping("/courses/{courseId}")
    public ResponseEntity<ApiResponse<InstructorCourseResponse>> getMyCourse(
            @PathVariable Long courseId
    ) {
        return ResponseEntity.ok(
                ApiResponse.ok(instructorCourseService.getMyCourse(courseId))
        );
    }

    @GetMapping("/courses/{courseId}/curriculum")
    public ResponseEntity<ApiResponse<CourseSyllabusResponse>> getMyCourseCurriculum(
            @PathVariable Long courseId
    ) {
        return ResponseEntity.ok(
                ApiResponse.ok(instructorCourseService.getMyCourseCurriculum(courseId))
        );
    }

    @PutMapping("/courses/{courseId}/curriculum")
    public ResponseEntity<ApiResponse<CurriculumReplaceRequest>> replaceCurriculum(
            @PathVariable Long courseId,
            @RequestBody CurriculumReplaceRequest request
    ) {
        CourseContentRepository.CurriculumReplaceResult result =
                instructorCourseService.replaceCurriculum(courseId, request);

        return ResponseEntity.ok(
                ApiResponse.ok(
                        "Curriculum saved ("
                                + result.moduleCount()
                                + " modules, "
                                + result.lessonCount()
                                + " lessons)",
                        request
                )
        );
    }

    @PostMapping("/courses")
    public ResponseEntity<ApiResponse<CourseLifecycleResponse>> createCourse(
            @RequestBody CourseCreateRequest request
    ) {
        CourseLifecycleResponse response =
                instructorCourseService.createCourse(request);

        return ResponseEntity.ok(
                ApiResponse.ok("Course draft created", response)
        );
    }

    @PutMapping("/courses/{courseId}")
    public ResponseEntity<ApiResponse<CourseLifecycleResponse>> updateCourse(
            @PathVariable Long courseId,
            @RequestBody CourseUpdateRequest request
    ) {
        CourseLifecycleResponse response =
                instructorCourseService.updateCourse(courseId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Course updated", response)
        );
    }

    @PostMapping("/courses/{courseId}/submit")
    public ResponseEntity<ApiResponse<CourseLifecycleResponse>> submitForReview(
            @PathVariable Long courseId
    ) {
        CourseLifecycleResponse response =
                instructorCourseService.submitForReview(courseId);

        return ResponseEntity.ok(
                ApiResponse.ok("Course submitted for review", response)
        );
    }

    @DeleteMapping("/courses/{courseId}")
    public ResponseEntity<ApiResponse<CourseLifecycleResponse>> deleteCourse(
            @PathVariable Long courseId
    ) {
        CourseLifecycleResponse response =
                instructorCourseService.deleteCourse(courseId);

        return ResponseEntity.ok(
                ApiResponse.ok("Course deleted", response)
        );
    }

    @PostMapping("/courses/{courseId}/modules")
    public ResponseEntity<ApiResponse<ModuleResponse>> createModule(
            @PathVariable Long courseId,
            @RequestBody ModuleCreateRequest request
    ) {
        ModuleResponse response =
                instructorCourseService.createModule(courseId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Module created", response)
        );
    }

    @PutMapping("/modules/{moduleId}")
    public ResponseEntity<ApiResponse<ModuleResponse>> updateModule(
            @PathVariable Long moduleId,
            @RequestBody ModuleUpdateRequest request
    ) {
        ModuleResponse response =
                instructorCourseService.updateModule(moduleId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Module updated", response)
        );
    }

    @DeleteMapping("/modules/{moduleId}")
    public ResponseEntity<ApiResponse<Void>> deleteModule(
            @PathVariable Long moduleId
    ) {
        instructorCourseService.deleteModule(moduleId);

        return ResponseEntity.ok(
                ApiResponse.ok("Module deleted", null)
        );
    }

    @PostMapping("/modules/{moduleId}/lessons")
    public ResponseEntity<ApiResponse<LessonResponse>> createLesson(
            @PathVariable Long moduleId,
            @RequestBody LessonCreateRequest request
    ) {
        LessonResponse response =
                instructorCourseService.createLesson(moduleId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Lesson created", response)
        );
    }

    @PutMapping("/lessons/{lessonId}")
    public ResponseEntity<ApiResponse<LessonResponse>> updateLesson(
            @PathVariable Long lessonId,
            @RequestBody LessonUpdateRequest request
    ) {
        LessonResponse response =
                instructorCourseService.updateLesson(lessonId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Lesson updated", response)
        );
    }

    @DeleteMapping("/lessons/{lessonId}")
    public ResponseEntity<ApiResponse<Void>> deleteLesson(
            @PathVariable Long lessonId
    ) {
        instructorCourseService.deleteLesson(lessonId);

        return ResponseEntity.ok(
                ApiResponse.ok("Lesson deleted", null)
        );
    }

    @PostMapping("/lessons/{lessonId}/blocks")
    public ResponseEntity<ApiResponse<ContentBlockResponse>> createBlock(
            @PathVariable Long lessonId,
            @RequestBody ContentBlockCreateRequest request
    ) {
        ContentBlockResponse response =
                instructorCourseService.createBlock(lessonId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Content block created", response)
        );
    }

    @PutMapping("/blocks/{blockId}")
    public ResponseEntity<ApiResponse<ContentBlockResponse>> updateBlock(
            @PathVariable Long blockId,
            @RequestBody ContentBlockUpdateRequest request
    ) {
        ContentBlockResponse response =
                instructorCourseService.updateBlock(blockId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Content block updated", response)
        );
    }

    @DeleteMapping("/blocks/{blockId}")
    public ResponseEntity<ApiResponse<Void>> deleteBlock(
            @PathVariable Long blockId
    ) {
        instructorCourseService.deleteBlock(blockId);

        return ResponseEntity.ok(
                ApiResponse.ok("Content block deleted", null)
        );
    }
}
