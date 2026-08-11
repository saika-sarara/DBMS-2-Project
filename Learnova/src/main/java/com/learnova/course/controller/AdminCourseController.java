package com.learnova.course.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.course.dto.AdminCategoryResponse;
import com.learnova.course.dto.AdminCourseResponse;
import com.learnova.course.dto.CategoryCreateRequest;
import com.learnova.course.dto.CategoryUpdateRequest;
import com.learnova.course.dto.CourseLifecycleResponse;
import com.learnova.course.dto.CourseModerationRequest;
import com.learnova.course.service.AdminCourseService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminCourseController {

    private final AdminCourseService adminCourseService;

    public AdminCourseController(AdminCourseService adminCourseService) {
        this.adminCourseService = adminCourseService;
    }

    @GetMapping("/courses")
    public ResponseEntity<ApiResponse<List<AdminCourseResponse>>> listCourses(
            @RequestParam(required = false) String status
    ) {
        return ResponseEntity.ok(
                ApiResponse.ok(adminCourseService.listCourses(status))
        );
    }

    @PostMapping("/courses/{courseId}/publish")
    public ResponseEntity<ApiResponse<CourseLifecycleResponse>> publishCourse(
            @PathVariable Long courseId
    ) {
        CourseLifecycleResponse response =
                adminCourseService.publishCourse(courseId);

        return ResponseEntity.ok(
                ApiResponse.ok("Course published", response)
        );
    }

    @PostMapping("/courses/{courseId}/reject")
    public ResponseEntity<ApiResponse<CourseLifecycleResponse>> rejectCourse(
            @PathVariable Long courseId,
            @RequestBody CourseModerationRequest request
    ) {
        CourseLifecycleResponse response =
                adminCourseService.rejectCourse(courseId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Course rejected", response)
        );
    }

    @PostMapping("/courses/{courseId}/archive")
    public ResponseEntity<ApiResponse<CourseLifecycleResponse>> archiveCourse(
            @PathVariable Long courseId
    ) {
        CourseLifecycleResponse response =
                adminCourseService.archiveCourse(courseId);

        return ResponseEntity.ok(
                ApiResponse.ok("Course archived", response)
        );
    }

    @GetMapping("/categories")
    public ResponseEntity<ApiResponse<List<AdminCategoryResponse>>> listCategories() {
        return ResponseEntity.ok(
                ApiResponse.ok(adminCourseService.listCategories())
        );
    }

    @PostMapping("/categories")
    public ResponseEntity<ApiResponse<AdminCategoryResponse>> createCategory(
            @RequestBody CategoryCreateRequest request
    ) {
        AdminCategoryResponse response =
                adminCourseService.createCategory(request);

        return ResponseEntity.ok(
                ApiResponse.ok("Category created", response)
        );
    }

    @PutMapping("/categories/{categoryId}")
    public ResponseEntity<ApiResponse<AdminCategoryResponse>> updateCategory(
            @PathVariable Long categoryId,
            @RequestBody CategoryUpdateRequest request
    ) {
        AdminCategoryResponse response =
                adminCourseService.updateCategory(categoryId, request);

        return ResponseEntity.ok(
                ApiResponse.ok("Category updated", response)
        );
    }

    @DeleteMapping("/categories/{categoryId}")
    public ResponseEntity<ApiResponse<Void>> deleteCategory(
            @PathVariable Long categoryId
    ) {
        adminCourseService.deleteCategory(categoryId);

        return ResponseEntity.ok(
                ApiResponse.ok("Category deleted", null)
        );
    }
}
