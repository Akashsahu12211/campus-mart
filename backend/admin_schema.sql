USE campus_mart;

-- Role add karo students table mein
ALTER TABLE students 
  ADD COLUMN role ENUM('STUDENT','MODERATOR','ADMIN') DEFAULT 'STUDENT';

ALTER TABLE students
  ADD COLUMN is_banned BOOLEAN DEFAULT FALSE,
  ADD COLUMN ban_reason TEXT DEFAULT NULL,
  ADD COLUMN banned_at TIMESTAMP NULL;

-- Admin audit log
CREATE TABLE IF NOT EXISTS admin_logs (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  admin_id    BIGINT NOT NULL,
  action      VARCHAR(100) NOT NULL,
  target_type ENUM('USER','ITEM','SYSTEM') NOT NULL,
  target_id   BIGINT,
  description TEXT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES students(id)
);

-- Item reports table
CREATE TABLE IF NOT EXISTS reports (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  reporter_id BIGINT NOT NULL,
  item_id     BIGINT NOT NULL,
  reason      ENUM('FAKE_ITEM','WRONG_PRICE','SPAM','INAPPROPRIATE','ALREADY_SOLD','OTHER') NOT NULL,
  description TEXT,
  status      ENUM('PENDING','REVIEWED','DISMISSED') DEFAULT 'PENDING',
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY  one_report (reporter_id, item_id),
  FOREIGN KEY (reporter_id) REFERENCES students(id),
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

-- Make first user admin (ID 1)
UPDATE students SET role = 'ADMIN' WHERE id = 1;

-- Indexes
CREATE INDEX idx_students_role ON students(role);
CREATE INDEX idx_students_banned ON students(is_banned);
CREATE INDEX idx_admin_logs_date ON admin_logs(created_at DESC);
CREATE INDEX idx_reports_status ON reports(status);

-- Verify
SELECT COUNT(*) as students_count FROM students;

