INSERT INTO roles (id, name, description) VALUES 
(1, 'ROLE_ADMIN', 'System Super Administrator'),
(2, 'ROLE_INSTRUCTOR', 'Course Creator and Educator'),
(3, 'ROLE_STUDENT', 'Platform Learner')
ON CONFLICT (name) DO NOTHING;