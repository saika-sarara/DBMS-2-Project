package com.learnova.authentication.service;

import com.learnova.authentication.dto.LoginRequest;
import com.learnova.authentication.dto.LoginResponse;
import com.learnova.authentication.dto.RegisterRequest;
import com.learnova.common.exception.InvalidCredentialsException;
import com.learnova.common.exception.UnauthorizedActionException;
import com.learnova.security.JwtService;
import com.learnova.user.dto.UserProfileResponse;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import com.learnova.user.repository.RoleRepository;
import com.learnova.user.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(
            UserRepository userRepository,
            RoleRepository roleRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService
    ) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public String registerUser(RegisterRequest request) {
        String normalizedEmail = normalizeEmail(request.getEmail());

        if (userRepository.existsByEmail(normalizedEmail)) {
            throw new IllegalArgumentException("Email is already in use.");
        }

        String password = request.getPassword();
        if (password == null || password.length() < 8) {
            throw new IllegalArgumentException("Password must be at least 8 characters.");
        }

        NameParts nameParts = splitName(request.getFullName());

        User user = new User(
                normalizedEmail,
                passwordEncoder.encode(password),
                nameParts.firstName(),
                nameParts.lastName()
        );

        Role studentRole = roleRepository.findByName("STUDENT")
                .orElseThrow(() -> new IllegalStateException("Default Student role was not found."));

        Set<Role> roles = new LinkedHashSet<>();
        roles.add(studentRole);
        user.setRoles(roles);

        userRepository.save(user);

        return "User registered successfully.";
    }

    @Transactional(readOnly = true)
    public LoginResponse loginUser(LoginRequest request) {
        String normalizedEmail = normalizeEmail(request.getEmail());

        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password."));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new InvalidCredentialsException("Invalid email or password.");
        }

        if (!"ACTIVE".equalsIgnoreCase(user.getAccountStatus())) {
            throw new UnauthorizedActionException(
                    "This account is " + user.getAccountStatus().toLowerCase(Locale.ROOT) +
                            ". Please contact support.");
        }

        String token = jwtService.generateToken(user);

        Set<String> frontendRoles = user.getRoles()
                .stream()
                .map(Role::getName)
                .map(this::toFrontendRole)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        return new LoginResponse(
                user.getId(),
                token,
                user.getEmail(),
                user.getFullName(),
                frontendRoles,
                user.getAccountStatus().toLowerCase(Locale.ROOT)
        );
    }

    @Transactional(readOnly = true)
    public UserProfileResponse me(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new InvalidCredentialsException("Authenticated user was not found."));
        return UserProfileResponse.from(user);
    }

    private String normalizeEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("Email is required.");
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private NameParts splitName(String fullName) {
        if (fullName == null || fullName.isBlank()) {
            throw new IllegalArgumentException("Name is required.");
        }

        String cleaned = fullName.trim().replaceAll("\\s+", " ");
        String[] parts = cleaned.split(" ", 2);

        String firstName = parts[0];
        String lastName = parts.length > 1 ? parts[1] : "User";

        return new NameParts(firstName, lastName);
    }

    private String toFrontendRole(String databaseRole) {
        if ("ADMIN".equalsIgnoreCase(databaseRole)) {
            return "Admin";
        }
        if ("INSTRUCTOR".equalsIgnoreCase(databaseRole)) {
            return "Instructor";
        }
        return "Student";
    }

    private record NameParts(String firstName, String lastName) {
    }
}
