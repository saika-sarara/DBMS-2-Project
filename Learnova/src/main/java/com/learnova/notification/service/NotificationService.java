package com.learnova.notification.service;

import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.notification.dto.NotificationResponse;
import com.learnova.notification.repository.NotificationRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final CurrentUserResolver currentUserResolver;

    public NotificationService(
            NotificationRepository notificationRepository,
            CurrentUserResolver currentUserResolver
    ) {
        this.notificationRepository = notificationRepository;
        this.currentUserResolver = currentUserResolver;
    }

    public List<NotificationResponse> listMine() {
        return notificationRepository.findByUser(
                currentUserResolver.getCurrentUserId()
        );
    }

    public void markRead(Long notificationId) {
        validateId(notificationId);
        notificationRepository.markRead(
                notificationId,
                currentUserResolver.getCurrentUserId()
        );
    }

    public long markAllRead() {
        return notificationRepository.markAllRead(
                currentUserResolver.getCurrentUserId()
        );
    }

    private void validateId(Long id) {
        if (id == null || id < 1) {
            throw new IllegalArgumentException(
                    "notificationId must be greater than zero."
            );
        }
    }
}
