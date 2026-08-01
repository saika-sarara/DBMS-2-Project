INSERT INTO roles (name, description) VALUES 
('ROLE_ADMIN', 'System Super Administrator'),
('ROLE_INSTRUCTOR', 'Course Creator and Educator'),
('ROLE_STUDENT', 'Platform Learner')
ON CONFLICT (name) DO NOTHING;