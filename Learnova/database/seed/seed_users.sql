-- Initial Seed Data for Testing Admin and Student
INSERT INTO users (email, password_hash, full_name, is_active) VALUES
('admin@learnova.com', '$2a$10$7R.v/Xm7YdZ0VwNq9UfB.eN4A5J/qO6A1U4k3Vz7W5Y2Z0VwNq9Uf', 'System Admin', TRUE),
('student@learnova.com', '$2a$10$7R.v/Xm7YdZ0VwNq9UfB.eN4A5J/qO6A1U4k3Vz7W5Y2Z0VwNq9Uf', 'Test Student', TRUE)
ON CONFLICT (email) DO NOTHING;