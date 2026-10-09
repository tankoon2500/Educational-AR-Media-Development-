-- ==========================================
-- 1. EXTENSIONS & SCHEMA SETUP
-- ==========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 2. CREATE TABLES
-- ==========================================
CREATE TABLE teachers (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE students (
    id VARCHAR(11) PRIMARY KEY, -- รหัสนักศึกษา 11 หลัก
    title VARCHAR(50),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    section VARCHAR(10),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    photo_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    kind VARCHAR(4) CHECK (kind IN ('pre', 'post')),
    score INTEGER NOT NULL,
    answers JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, kind)
);

CREATE TABLE progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    unit INTEGER NOT NULL CHECK (unit BETWEEN 1 AND 5),
    done BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, unit)
);

CREATE TABLE submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    unit INTEGER NOT NULL,
    kind VARCHAR(10) CHECK (kind IN ('link', 'file')),
    url TEXT,
    storage_path TEXT,
    note TEXT,
    score INTEGER,
    teacher_comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, unit)
);

CREATE TABLE materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    kind VARCHAR(10) CHECK (kind IN ('file', 'link', 'video')),
    url TEXT,
    storage_path TEXT,
    file_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 3. SECURITY DEFINER FUNCTIONS
-- ==========================================
-- ฟังก์ชันเช็คอาจารย์ (ตั้ง search_path ป้องกัน search path injection)
CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (SELECT 1 FROM teachers WHERE user_id = auth.uid());
$$;

-- ==========================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;

-- Revoke default access
REVOKE ALL ON teachers FROM anon, authenticated;
REVOKE ALL ON students FROM anon, authenticated;
REVOKE ALL ON attempts FROM anon, authenticated;
REVOKE ALL ON progress FROM anon, authenticated;
REVOKE ALL ON submissions FROM anon, authenticated;
REVOKE ALL ON materials FROM anon, authenticated;

-- Grant minimal necessary rights
GRANT SELECT ON teachers TO authenticated;
GRANT SELECT, UPDATE ON students TO authenticated;
GRANT SELECT, INSERT ON attempts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON progress TO authenticated;
GRANT SELECT, INSERT, UPDATE ON submissions TO authenticated;
GRANT SELECT ON materials TO authenticated;

-- Policies for Teachers
CREATE POLICY "Teacher full access on teachers" ON teachers FOR ALL TO authenticated USING (is_teacher());
CREATE POLICY "Teacher full access on students" ON students FOR ALL TO authenticated USING (is_teacher());
CREATE POLICY "Teacher full access on attempts" ON attempts FOR ALL TO authenticated USING (is_teacher());
CREATE POLICY "Teacher full access on progress" ON progress FOR ALL TO authenticated USING (is_teacher());
CREATE POLICY "Teacher full access on submissions" ON submissions FOR ALL TO authenticated USING (is_teacher());
CREATE POLICY "Teacher full access on materials" ON materials FOR ALL TO authenticated USING (is_teacher());

-- Policies for Students
CREATE POLICY "Student read own profile" ON students FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Student update own photo" ON students FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "Student read own attempts" ON attempts FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Student insert own attempts" ON attempts FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "Student read own progress" ON progress FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Student insert own progress" ON progress FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Student update own progress" ON progress FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "Student read own submissions" ON submissions FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Student insert own submissions" ON submissions FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Student update own submissions" ON submissions FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "Student read materials" ON materials FOR SELECT TO authenticated USING (true);

-- ==========================================
-- 5. COLUMN-LEVEL SECURITY TRIGGERS
-- ==========================================
-- ป้องกันนักศึกษาแก้ไข score และ teacher_comment ในตาราง submissions
CREATE OR REPLACE FUNCTION protect_submission_grading()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT is_teacher() THEN
        IF NEW.score IS DISTINCT FROM OLD.score OR NEW.teacher_comment IS DISTINCT FROM OLD.teacher_comment THEN
            RAISE EXCEPTION 'นักศึกษาไม่สามารถแก้ไขคะแนนหรือข้อเสนอแนะได้';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER check_submission_update
BEFORE UPDATE ON submissions
FOR EACH ROW
EXECUTE FUNCTION protect_submission_grading();

-- ==========================================
-- 6. AUTH TRIGGER FOR AUTO-LINKING STUDENTS
-- ==========================================
CREATE OR REPLACE FUNCTION link_auth_to_student()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    student_id_prefix VARCHAR(11);
BEGIN
    -- สกัดรหัสนักศึกษาจากอีเมล
    student_id_prefix := split_part(NEW.email, '@', 1);
    
    -- ข้ามหากเป็นอีเมลอาจารย์ (ไม่ขึ้นต้นด้วยตัวเลข 11 หลัก)
    IF student_id_prefix ~ '^\d{11}$' THEN
        -- ถ้ารหัสไม่มีในระบบ หรือโดนผูกกับบัญชีอื่นไปแล้ว ให้ reject
        IF NOT EXISTS (SELECT 1 FROM students WHERE id = student_id_prefix AND user_id IS NULL) THEN
            RAISE EXCEPTION 'ไม่พบรหัสนักศึกษานี้ในระบบ หรือบัญชีถูกลงทะเบียนไปแล้ว';
        END IF;
        
        -- อัปเดต user_id ในตาราง students
        UPDATE students SET user_id = NEW.id WHERE id = student_id_prefix;
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION link_auth_to_student();

-- ==========================================
-- 7. VIEWS FOR TEACHERS
-- ==========================================
CREATE VIEW results WITH (security_invoker = true) AS
SELECT 
    s.id AS student_id,
    s.title,
    s.first_name,
    s.last_name,
    s.section,
    s.photo_path,
    (SELECT score FROM attempts a WHERE a.user_id = s.user_id AND a.kind = 'pre') AS pre_score,
    (SELECT score FROM attempts a WHERE a.user_id = s.user_id AND a.kind = 'post') AS post_score,
    (SELECT COUNT(*) FROM progress p WHERE p.user_id = s.user_id AND p.done = true) AS units_completed,
    (SELECT score FROM submissions sub WHERE sub.user_id = s.user_id AND sub.unit = 4) AS assignment_score
FROM students s;

-- ==========================================
-- 8. STORAGE BUCKETS & POLICIES
-- ==========================================
-- ต้องสร้าง Bucket ก่อน (เนื่องจาก script ไม่สามารถสร้าง bucket ผ่าน SQL ตรงๆ ใน Supabase ปัจจุบันได้ 100% ให้ใช้ function หรือคู่มือ แต่อันนี้จำลองการ insert ลง schema storage)
INSERT INTO storage.buckets (id, name, public) VALUES ('photos', 'photos', false) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('submissions', 'submissions', false) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('materials', 'materials', false) ON CONFLICT DO NOTHING;

-- RLS for Storage (Photos) - จำกัดให้ไฟล์อยู่ในโฟลเดอร์ UID ตัวเอง
CREATE POLICY "Student manage own photo" ON storage.objects FOR ALL TO authenticated 
USING (bucket_id = 'photos' AND (storage.foldername(name))[1] = auth.uid()::text) 
WITH CHECK (bucket_id = 'photos' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Teacher read photos" ON storage.objects FOR SELECT TO authenticated 
USING (bucket_id = 'photos' AND is_teacher());

-- RLS for Storage (Submissions)
CREATE POLICY "Student manage own submissions" ON storage.objects FOR ALL TO authenticated 
USING (bucket_id = 'submissions' AND (storage.foldername(name))[1] = auth.uid()::text) 
WITH CHECK (bucket_id = 'submissions' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Teacher read submissions" ON storage.objects FOR SELECT TO authenticated 
USING (bucket_id = 'submissions' AND is_teacher());

-- RLS for Storage (Materials)
CREATE POLICY "Anyone read materials" ON storage.objects FOR SELECT TO authenticated 
USING (bucket_id = 'materials');

CREATE POLICY "Teacher manage materials" ON storage.objects FOR ALL TO authenticated 
USING (bucket_id = 'materials' AND is_teacher()) 
WITH CHECK (bucket_id = 'materials' AND is_teacher());

-- ==========================================
-- 9. MOCK DATA (6 STUDENTS)
-- ==========================================
-- การนำเข้าจริงให้ใช้ Table Editor อัปโหลด CSV
INSERT INTO students (id, title, first_name, last_name, section) VALUES
('66101234001', 'นาย', 'สมชาย', 'เรียนดี', '01'),
('66101234002', 'นางสาว', 'สมหญิง', 'ขยันยิ่ง', '01'),
('66101234003', 'นาย', 'มานะ', 'อดทน', '02'),
('66101234004', 'นางสาว', 'ปิติ', 'ยินดี', '02'),
('66101234005', 'นาย', 'ชูใจ', 'รักเรียน', '03'),
('66101234006', 'นางสาว', 'วีระ', 'กล้าหาญ', '03')
ON CONFLICT (id) DO NOTHING;

-- ==========================================
-- 10. SETUP TEACHER ACCOUNT (MANUAL)
-- ==========================================
-- เมื่ออาจารย์สมัครสมาชิกด้วยอีเมล ให้คัดลอก UID จาก auth.users มาใส่ในคำสั่งด้านล่าง
-- หรือใช้วิธีรันคำสั่งนี้โดยแก้อีเมลอาจารย์ที่ต้องการ
/*
INSERT INTO teachers (user_id)
SELECT id FROM auth.users WHERE email = 'teacher@edu.fictional.ac.th'
ON CONFLICT DO NOTHING;
*/