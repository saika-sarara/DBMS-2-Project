package com.learnova.authentication;

import com.learnova.authentication.dto.LoginRequest;
import com.learnova.authentication.dto.LoginResponse;
import com.learnova.authentication.dto.RegisterRequest;
import com.learnova.authentication.service.AuthService;
import com.learnova.common.exception.InvalidCredentialsException;
import com.learnova.common.exception.UnauthorizedActionException;
import com.learnova.security.JwtService;
import com.learnova.user.dto.UserProfileResponse;
import com.learnova.user.model.Role;
import com.learnova.user.model.User;
import com.learnova.user.repository.RoleRepository;
import com.learnova.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.LinkedHashSet;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

	@Mock
	private UserRepository userRepository;

	@Mock
	private RoleRepository roleRepository;

	@Mock
	private PasswordEncoder passwordEncoder;

	@Mock
	private JwtService jwtService;

	@InjectMocks
	private AuthService authService;

	@Test
	void registerUserNormalizesInputEncodesPasswordAssignsStudentRoleAndSaves() {
		RegisterRequest request = new RegisterRequest();
		request.setEmail("  ADA@EXAMPLE.COM ");
		request.setFullName("  Ada   Lovelace  ");
		request.setPassword("password123");

		Role studentRole = new Role("STUDENT", "Student role");
		when(userRepository.existsByEmail("ada@example.com")).thenReturn(false);
		when(passwordEncoder.encode("password123")).thenReturn("encoded-password");
		when(roleRepository.findByName("STUDENT")).thenReturn(Optional.of(studentRole));
		when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

		String result = authService.registerUser(request);

		assertEquals("User registered successfully.", result);

		ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
		verify(userRepository).save(userCaptor.capture());
		User savedUser = userCaptor.getValue();
		assertEquals("ada@example.com", savedUser.getEmail());
		assertEquals("encoded-password", savedUser.getPasswordHash());
		assertEquals("Ada", savedUser.getFirstName());
		assertEquals("Lovelace", savedUser.getLastName());
		assertEquals(Set.of(studentRole), savedUser.getRoles());
		verify(passwordEncoder).encode("password123");
		verify(roleRepository).findByName("STUDENT");
	}

	@Test
	void registerUserRejectsDuplicateEmailBeforeEncodingOrRoleLookup() {
		RegisterRequest request = new RegisterRequest();
		request.setEmail(" Existing@Example.com ");
		request.setFullName("Existing User");
		request.setPassword("password123");
		when(userRepository.existsByEmail("existing@example.com")).thenReturn(true);

		IllegalArgumentException exception = assertThrows(
				IllegalArgumentException.class,
				() -> authService.registerUser(request)
		);

		assertEquals("Email is already in use.", exception.getMessage());
		verify(passwordEncoder, never()).encode(any());
		verifyNoInteractions(roleRepository);
		verify(userRepository, never()).save(any(User.class));
	}

	@Test
	void registerUserRejectsShortPasswordBeforeCreatingUser() {
		RegisterRequest request = new RegisterRequest();
		request.setEmail("new@example.com");
		request.setFullName("New User");
		request.setPassword("short");
		when(userRepository.existsByEmail("new@example.com")).thenReturn(false);

		IllegalArgumentException exception = assertThrows(
				IllegalArgumentException.class,
				() -> authService.registerUser(request)
		);

		assertEquals("Password must be at least 8 characters.", exception.getMessage());
		verifyNoInteractions(passwordEncoder, roleRepository);
		verify(userRepository, never()).save(any(User.class));
	}

	@Test
	void registerUserRejectsMissingDefaultStudentRole() {
		RegisterRequest request = new RegisterRequest();
		request.setEmail("new@example.com");
		request.setFullName("New User");
		request.setPassword("password123");
		when(userRepository.existsByEmail("new@example.com")).thenReturn(false);
		when(passwordEncoder.encode("password123")).thenReturn("encoded-password");
		when(roleRepository.findByName("STUDENT")).thenReturn(Optional.empty());

		IllegalStateException exception = assertThrows(
				IllegalStateException.class,
				() -> authService.registerUser(request)
		);

		assertEquals("Default Student role was not found.", exception.getMessage());
		verify(userRepository, never()).save(any(User.class));
	}

	@Test
	void loginUserReturnsTokenAndFrontendRolesForActiveUser() {
		User user = user(5L, "user@example.com", "Ada", "Lovelace", "ACTIVE", "hash",
				new Role("ADMIN", "Admin role"), new Role("INSTRUCTOR", "Instructor role"));
		LoginRequest request = loginRequest(" USER@EXAMPLE.COM ", "password123");
		when(userRepository.findByEmail("user@example.com")).thenReturn(Optional.of(user));
		when(passwordEncoder.matches("password123", "hash")).thenReturn(true);
		when(jwtService.generateToken(user)).thenReturn("jwt-token");

		LoginResponse response = authService.loginUser(request);

		assertEquals(5L, response.getId());
		assertEquals("jwt-token", response.getToken());
		assertEquals("user@example.com", response.getEmail());
		assertEquals("Ada Lovelace", response.getFullName());
		assertEquals(Set.of("Admin", "Instructor"), response.getRoles());
		assertEquals("Admin", response.getRole());
		assertEquals("active", response.getStatus());
		verify(jwtService).generateToken(user);
	}

	@Test
	void loginUserRejectsUnknownUserWithoutCheckingPassword() {
		LoginRequest request = loginRequest("missing@example.com", "password123");
		when(userRepository.findByEmail("missing@example.com")).thenReturn(Optional.empty());

		InvalidCredentialsException exception = assertThrows(
				InvalidCredentialsException.class,
				() -> authService.loginUser(request)
		);

		assertEquals("Invalid email or password.", exception.getMessage());
		verifyNoInteractions(passwordEncoder, jwtService);
	}

	@Test
	void loginUserRejectsIncorrectPasswordWithoutGeneratingToken() {
		User user = user(5L, "user@example.com", "Ada", "Lovelace", "ACTIVE", "hash");
		LoginRequest request = loginRequest("user@example.com", "wrong-password");
		when(userRepository.findByEmail("user@example.com")).thenReturn(Optional.of(user));
		when(passwordEncoder.matches("wrong-password", "hash")).thenReturn(false);

		InvalidCredentialsException exception = assertThrows(
				InvalidCredentialsException.class,
				() -> authService.loginUser(request)
		);

		assertEquals("Invalid email or password.", exception.getMessage());
		verifyNoInteractions(jwtService);
	}

	@Test
	void loginUserRejectsInactiveAccountWithoutGeneratingToken() {
		User user = user(5L, "user@example.com", "Ada", "Lovelace", "SUSPENDED", "hash");
		LoginRequest request = loginRequest("user@example.com", "password123");
		when(userRepository.findByEmail("user@example.com")).thenReturn(Optional.of(user));
		when(passwordEncoder.matches("password123", "hash")).thenReturn(true);

		UnauthorizedActionException exception = assertThrows(
				UnauthorizedActionException.class,
				() -> authService.loginUser(request)
		);

		assertEquals("This account is suspended. Please contact support.", exception.getMessage());
		verifyNoInteractions(jwtService);
	}

	@Test
	void meMapsTheAuthenticatedUserProfile() {
		User user = user(5L, "user@example.com", "Ada", "Lovelace", "ACTIVE", "hash",
				new Role("STUDENT", "Student role"));
		when(userRepository.findById(5L)).thenReturn(Optional.of(user));

		UserProfileResponse response = authService.me(5L);

		assertEquals(5L, response.getId());
		assertEquals("user@example.com", response.getEmail());
		assertEquals("Ada Lovelace", response.getFullName());
		assertEquals(Set.of("Student"), response.getRoles());
		assertEquals("Student", response.getRole());
		assertEquals("active", response.getStatus());
	}

	@Test
	void meRejectsUnknownAuthenticatedUser() {
		when(userRepository.findById(99L)).thenReturn(Optional.empty());

		InvalidCredentialsException exception = assertThrows(
				InvalidCredentialsException.class,
				() -> authService.me(99L)
		);

		assertEquals("Authenticated user was not found.", exception.getMessage());
	}

	private LoginRequest loginRequest(String email, String password) {
		LoginRequest request = new LoginRequest();
		request.setEmail(email);
		request.setPassword(password);
		return request;
	}

	private User user(
			Long id,
			String email,
			String firstName,
			String lastName,
			String accountStatus,
			String passwordHash,
			Role... roles
	) {
		User user = new User(email, passwordHash, firstName, lastName);
		user.setId(id);
		user.setAccountStatus(accountStatus);
		user.setRoles(new LinkedHashSet<>(Set.of(roles)));
		return user;
	}
}
