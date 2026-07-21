-- Enable uuid-ossp extension for uuid generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enum types
CREATE TYPE user_role AS ENUM ('student', 'mentor');
CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'late');

-- 1. profiles table
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  full_name TEXT NOT NULL,
  role user_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. access_codes table
CREATE TABLE access_codes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  role user_role NOT NULL,
  code TEXT NOT NULL UNIQUE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_by UUID REFERENCES profiles(id)
);

-- 3. tasks table
CREATE TABLE tasks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  sort_order INT NOT NULL,
  points INT DEFAULT 1 NOT NULL
);

-- 4. daily_logs table
CREATE TABLE daily_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  log_date DATE NOT NULL,
  sleep_hours NUMERIC,
  weight NUMERIC,
  eat_smart_breakfast TEXT,
  eat_smart_lunch TEXT,
  eat_smart_tea TEXT,
  eat_smart_dinner TEXT,
  total_cals NUMERIC,
  reflection_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, log_date)
);

-- 5. task_entries table
CREATE TABLE task_entries (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  daily_log_id UUID REFERENCES daily_logs(id) NOT NULL,
  task_id UUID REFERENCES tasks(id) NOT NULL,
  content TEXT,
  submitted_at TIMESTAMP WITH TIME ZONE,
  approved BOOLEAN DEFAULT FALSE NOT NULL,
  approved_by UUID REFERENCES profiles(id),
  points_awarded INT DEFAULT 0 NOT NULL,
  mentor_note TEXT,
  UNIQUE(daily_log_id, task_id)
);

-- 6. attendance table
CREATE TABLE attendance (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  date DATE NOT NULL,
  status attendance_status NOT NULL,
  marked_by UUID REFERENCES profiles(id) NOT NULL,
  UNIQUE(user_id, date)
);

-- 7. feedback table
CREATE TABLE feedback (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  submitted_by_role TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. mentor_suggestions table
CREATE TABLE mentor_suggestions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  mentor_id UUID REFERENCES profiles(id) NOT NULL,
  student_id UUID REFERENCES profiles(id) NOT NULL,
  date DATE NOT NULL,
  suggestion TEXT NOT NULL,
  UNIQUE(student_id, date)
);

-- Seed tasks
INSERT INTO tasks (title, sort_order, points) VALUES
('Master the Mic', 1, 1),
('Mind Gym', 2, 1),
('World Watch', 3, 1),
('Smart Tools Mastery', 4, 1),
('Brain Boost', 5, 1),
('Startup Garage', 6, 1),
('Fit & Strong', 7, 1),
('Real-World Problems', 8, 1),
('Power Circles', 9, 1),
('Level Up Look', 10, 1),
('Talk Like a Pro', 11, 1),
('Build Your Brand', 12, 1),
('Impact Hour', 13, 1),
('Life Hacks Lab', 14, 1),
('Do & Learn', 15, 1),
('Growth Fuel', 16, 1),
('Sleep', 17, 1),
('Eat Smart', 18, 1),
('Weight', 19, 1),
('Prayer / Meditation', 20, 1);

-- Seed access codes (default codes, can be changed later)
INSERT INTO access_codes (role, code) VALUES
('student', 'Edex@life2026'),
('mentor', 'Edex@mentor2627');

-- Set up Row Level Security (RLS)

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentor_suggestions ENABLE ROW LEVEL SECURITY;

-- Create a helper function to get current user's role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Profiles: 
-- Anyone can view profiles (needed for names). Users can insert/update their own profile.
CREATE POLICY "Profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Access Codes:
-- Only mentors can see access codes. (During signup, we might need a stored procedure or bypass RLS, 
-- but let's allow read for all authenticated users to check during signup if needed, wait, signup happens BEFORE auth.
-- We must bypass RLS for signup checking, or use a security definer function.)
CREATE POLICY "Mentors can read access codes" ON access_codes FOR SELECT USING (get_user_role() = 'mentor');
CREATE POLICY "Mentors can update access codes" ON access_codes FOR UPDATE USING (get_user_role() = 'mentor');

-- Create a security definer function to validate access code during signup
CREATE OR REPLACE FUNCTION public.validate_access_code(input_code TEXT, input_role TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  is_valid BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM access_codes WHERE code = input_code AND role::text = input_role) INTO is_valid;
  RETURN is_valid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Tasks:
-- Everyone can read tasks. No one can update via app (admin only).
CREATE POLICY "Tasks are viewable by everyone" ON tasks FOR SELECT USING (true);

-- Daily Logs:
-- Students can select/insert/update their own. Mentors can select all.
CREATE POLICY "Students can view their own logs" ON daily_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Mentors can view all logs" ON daily_logs FOR SELECT USING (get_user_role() = 'mentor');
CREATE POLICY "Students can insert their own logs" ON daily_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Students can update their own logs" ON daily_logs FOR UPDATE USING (auth.uid() = user_id);

-- Task Entries:
-- Students can select/insert their own (via daily_log). Mentors can select all.
CREATE POLICY "Students can view their own task entries" ON task_entries FOR SELECT USING (
  EXISTS (SELECT 1 FROM daily_logs WHERE daily_logs.id = task_entries.daily_log_id AND daily_logs.user_id = auth.uid())
);
CREATE POLICY "Mentors can view all task entries" ON task_entries FOR SELECT USING (get_user_role() = 'mentor');
CREATE POLICY "Students can insert their own task entries" ON task_entries FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM daily_logs WHERE daily_logs.id = task_entries.daily_log_id AND daily_logs.user_id = auth.uid())
);
-- Students can update content, but NOT approved/points. 
-- Wait, RLS policies for UPDATE on specific columns is tricky. We'll rely on the policy for the whole row, and restrict specific columns via the API/server action.
CREATE POLICY "Students can update their own task entries" ON task_entries FOR UPDATE USING (
  EXISTS (SELECT 1 FROM daily_logs WHERE daily_logs.id = task_entries.daily_log_id AND daily_logs.user_id = auth.uid())
);
CREATE POLICY "Mentors can update all task entries" ON task_entries FOR UPDATE USING (get_user_role() = 'mentor');

-- Attendance:
-- Students can read their own. Mentors can read all and insert/update all.
CREATE POLICY "Students can view their own attendance" ON attendance FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Mentors can view all attendance" ON attendance FOR SELECT USING (get_user_role() = 'mentor');
CREATE POLICY "Mentors can insert attendance" ON attendance FOR INSERT WITH CHECK (get_user_role() = 'mentor');
CREATE POLICY "Mentors can update attendance" ON attendance FOR UPDATE USING (get_user_role() = 'mentor');

-- Feedback:
-- Students can read their own, insert their own. Mentors can read all, insert their own.
CREATE POLICY "Users can view their own feedback" ON feedback FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Mentors can view all feedback" ON feedback FOR SELECT USING (get_user_role() = 'mentor');
CREATE POLICY "Users can insert their own feedback" ON feedback FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Mentor Suggestions:
-- Students can read their own. Mentors can read all and insert/update all.
CREATE POLICY "Students can view their own suggestions" ON mentor_suggestions FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Mentors can view all suggestions" ON mentor_suggestions FOR SELECT USING (get_user_role() = 'mentor');
CREATE POLICY "Mentors can insert suggestions" ON mentor_suggestions FOR INSERT WITH CHECK (get_user_role() = 'mentor');
CREATE POLICY "Mentors can update suggestions" ON mentor_suggestions FOR UPDATE USING (get_user_role() = 'mentor');

-- Trigger to create profile automatically on Auth Signup with Access Code Validation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  input_code TEXT;
  input_role TEXT;
  is_valid BOOLEAN;
BEGIN
  input_role := new.raw_user_meta_data->>'role';
  input_code := new.raw_user_meta_data->>'access_code';

  -- If this is an API signup (processed under anon or authenticated roles)
  IF current_setting('role', true) IN ('anon', 'authenticated') THEN
    -- Enforce role presence and validity
    IF input_role IS NULL OR input_role NOT IN ('student', 'mentor') THEN
      RAISE EXCEPTION 'A valid role (student/mentor) must be provided in user metadata.';
    END IF;

    -- Validate access code against the access_codes table
    SELECT EXISTS(
      SELECT 1 FROM public.access_codes 
      WHERE role::text = input_role AND code = input_code
    ) INTO is_valid;

    IF NOT is_valid THEN
      RAISE EXCEPTION 'Invalid access code for the role: %', input_role;
    END IF;
  END IF;

  -- Create profile
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    COALESCE(input_role, 'student')::public.user_role
  );
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Trigger to prevent role updates on profiles table
CREATE OR REPLACE FUNCTION public.prevent_profile_role_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Role updates are not permitted.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_profile_role_update ON public.profiles;
CREATE TRIGGER check_profile_role_update
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_profile_role_update();

-- Function to securely fetch leaderboard data, bypassing RLS
CREATE OR REPLACE FUNCTION get_leaderboard(start_date DATE, end_date DATE)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    total_points BIGINT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        dl.user_id,
        p.full_name,
        COALESCE(SUM(te.points_awarded), 0)::BIGINT as total_points
    FROM daily_logs dl
    JOIN profiles p ON p.id = dl.user_id
    JOIN task_entries te ON te.daily_log_id = dl.id
    WHERE te.approved = true
        AND dl.log_date >= start_date
        AND dl.log_date <= end_date
    GROUP BY dl.user_id, p.full_name
    ORDER BY total_points DESC;
$$;