package com.learnova.notification.controller;

import com.learnova.common.response.ApiResponse;
import com.learnova.notification.dto.NotificationResponse;
import com.learnova.notification.service.NotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> listMine() {
        return ResponseEntity.ok(ApiResponse.ok(notificationService.listMine()));
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<ApiResponse<Void>> markRead(
            @PathVariable Long id
    ) {
        notificationService.markRead(id);
        return ResponseEntity.ok(ApiResponse.ok("Notification marked as read.", null));
    }

    @PutMapping("/read-all")
    public ResponseEntity<ApiResponse<Map<String, Long>>> markAllRead() {
        long count = notificationService.markAllRead();
        return ResponseEntity.ok(ApiResponse.ok(
                "Notifications marked as read.",
                Map.of("updated", count)
        ));
    }
}
