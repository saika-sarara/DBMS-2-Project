package com.learnova.user.service;

import com.learnova.common.exception.InvalidCredentialsException;
import com.learnova.user.dto.UpdateProfileRequest;
import com.learnova.user.dto.UserProfileResponse;
import com.learnova.user.model.User;
import com.learnova.user.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public UserProfileResponse getProfile(Long userId) {
        return UserProfileResponse.from(findUser(userId));
    }

    @Transactional
    public UserProfileResponse updateProfile(Long userId, UpdateProfileRequest request) {
        User user = findUser(userId);

        if (request.getFirstName() != null && !request.getFirstName().isBlank()) {
            user.setFirstName(request.getFirstName().trim());
        }

        if (request.getLastName() != null && !request.getLastName().isBlank()) {
            user.setLastName(request.getLastName().trim());
        }

        String newPassword = request.getNewPassword();
        if (newPassword != null && !newPassword.isBlank()) {
            String currentPassword = request.getCurrentPassword() == null ? "" : request.getCurrentPassword();

            if (!passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
                throw new InvalidCredentialsException("Current password is incorrect.");
            }

            if (newPassword.length() < 8) {
                throw new IllegalArgumentException("New password must be at least 8 characters.");
            }

            user.setPasswordHash(passwordEncoder.encode(newPassword));
        }

        return UserProfileResponse.from(userRepository.save(user));
    }

    private User findUser(Long userId) {
        if (userId == null || userId <= 0) {
            throw new IllegalArgumentException("Invalid user id.");
        }
        return userRepository.findById(userId)
                .orElseThrow(() -> new InvalidCredentialsException("Authenticated user was not found."));
    }
}
