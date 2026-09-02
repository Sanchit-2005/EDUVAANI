CREATE TABLE lessons (
  id INT AUTO_INCREMENT PRIMARY KEY,
  grade VARCHAR(50) NOT NULL,
  subject VARCHAR(100) NOT NULL,
  topic VARCHAR(255) NOT NULL,
  learning_outcome TEXT NOT NULL,
  hindi_instruction TEXT NOT NULL,
  santali_translation TEXT,
  is_prototype_translation BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE translations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  hindi TEXT NOT NULL,
  santali TEXT NOT NULL,
  validation_status ENUM('prototype', 'validated') NOT NULL DEFAULT 'prototype'
);

CREATE TABLE activities (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(255) NOT NULL, payload JSON NOT NULL);
CREATE TABLE assessments (id INT AUTO_INCREMENT PRIMARY KEY, grade VARCHAR(50) NOT NULL, subject VARCHAR(100) NOT NULL, topic VARCHAR(255) NOT NULL, payload JSON NOT NULL);
CREATE TABLE model_versions (id INT AUTO_INCREMENT PRIMARY KEY, model_name VARCHAR(100) NOT NULL, version VARCHAR(50) NOT NULL, size_bytes BIGINT NOT NULL, status VARCHAR(50) NOT NULL);

CREATE TABLE progress (
  id INT AUTO_INCREMENT PRIMARY KEY,
  class_name VARCHAR(50) NOT NULL,
  students INT NOT NULL,
  lessons_completed INT NOT NULL,
  total_lessons INT NOT NULL,
  literacy_percent INT NOT NULL,
  numeracy_percent INT NOT NULL,
  vocabulary_percent INT NOT NULL,
  uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sync_metadata (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(100),
  synced_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
