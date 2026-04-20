-- ============================================================
-- VitalPath Supabase Database Schema
-- PostgreSQL (via Supabase)
-- HIPAA & GDPR compliant — Row Level Security on all tables
-- ============================================================

-- Enable pgaudit for medical accountability (Tech Blueprint §4)
-- CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Users ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number TEXT NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    height_cm REAL,
    weight_kg REAL,
    conditions TEXT DEFAULT '[]',
    blood_type TEXT,
    date_of_birth TEXT,
    unit_preference TEXT DEFAULT 'km',
    step_goal INTEGER DEFAULT 10000,
    home_timezone TEXT,
    notification_prefs JSONB DEFAULT '{}',
    onboarding_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own profile"
    ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"
    ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile"
    ON users FOR INSERT WITH CHECK (auth.uid() = id);

-- ── Medicines ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS medicines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    unit TEXT DEFAULT 'pills',
    dosage REAL NOT NULL CHECK (dosage > 0),
    frequency TEXT NOT NULL,
    scheduled_times JSONB DEFAULT '[]',
    scheduled_days JSONB DEFAULT '[]',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    inventory_count INTEGER DEFAULT 0,
    refill_threshold INTEGER DEFAULT 5,
    image_path TEXT,
    notes TEXT,
    color_hex TEXT DEFAULT '#0B6E4F',
    is_verified BOOLEAN DEFAULT FALSE,
    doctor_connection_id UUID,
    is_active BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE medicines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own medicines"
    ON medicines FOR ALL USING (auth.uid() = user_id);

-- ── Medicine Logs ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS medicine_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    medicine_id UUID NOT NULL REFERENCES medicines(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('taken', 'skipped', 'snoozed', 'rescheduled')),
    scheduled_at TIMESTAMPTZ NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL,  -- Original timestamp preserved (SRS §5.1)
    notes TEXT,
    _original_timestamp TIMESTAMPTZ,  -- Set by sync engine (SRS §5.1)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE medicine_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own medicine logs"
    ON medicine_logs FOR ALL USING (auth.uid() = user_id);
-- Doctor can read patient logs (read-only via connection)
CREATE POLICY "Doctors can read patient logs"
    ON medicine_logs FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM doctor_connections dc
        WHERE dc.patient_id = medicine_logs.user_id
        AND dc.doctor_id = auth.uid()
        AND dc.status = 'active'
    ));

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_medicine_logs_user_scheduled
    ON medicine_logs(user_id, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_medicine_logs_medicine_logged
    ON medicine_logs(medicine_id, logged_at);

-- ── Meal Routines ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meal_routines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    meal_name TEXT NOT NULL,
    window_start TEXT NOT NULL,
    window_end TEXT NOT NULL,
    description TEXT,
    nutritional_tags JSONB DEFAULT '[]',
    active_days JSONB DEFAULT '["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]',
    target_calories INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE meal_routines ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own meal routines"
    ON meal_routines FOR ALL USING (auth.uid() = user_id);

-- ── Meal Logs ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS meal_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meal_routine_id UUID NOT NULL REFERENCES meal_routines(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('logged', 'skipped', 'snoozed')),
    scheduled_at TIMESTAMPTZ NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL,
    notes TEXT,
    actual_calories INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own meal logs"
    ON meal_logs FOR ALL USING (auth.uid() = user_id);

-- ── Activity Logs ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date TEXT NOT NULL,  -- "yyyy-MM-dd"
    step_count INTEGER DEFAULT 0,
    step_goal INTEGER DEFAULT 10000,
    distance_meters REAL DEFAULT 0,
    calories_burned REAL,
    active_minutes INTEGER DEFAULT 0,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own activity"
    ON activity_logs FOR ALL USING (auth.uid() = user_id);

-- ── Walk Sessions ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS walk_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    distance_meters REAL DEFAULT 0,
    step_count INTEGER DEFAULT 0,
    duration_seconds INTEGER DEFAULT 0,
    avg_pace_sec_per_km REAL,
    polyline_json TEXT,  -- May be NULL if storage was full (SRS §5.3)
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE walk_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own walk sessions"
    ON walk_sessions FOR ALL USING (auth.uid() = user_id);

-- ── Doctor Connections ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS doctor_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    doctor_name TEXT NOT NULL,
    clinic_name TEXT,
    contact_number TEXT,
    specialty TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'revoked')),
    sync_code TEXT,
    sync_code_expires_at TIMESTAMPTZ,
    connected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE doctor_connections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Patients see own connections"
    ON doctor_connections FOR SELECT USING (auth.uid() = patient_id);
CREATE POLICY "Doctors see their connections"
    ON doctor_connections FOR SELECT USING (auth.uid() = doctor_id);
CREATE POLICY "Patients manage own connections"
    ON doctor_connections FOR ALL USING (auth.uid() = patient_id);

-- ── Prescriptions ─────────────────────────────────────────────
-- Server-side timestamp wins for conflict resolution (SRS §5.3)
CREATE TABLE IF NOT EXISTS prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_connection_id UUID NOT NULL REFERENCES doctor_connections(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES users(id),
    medicine_id UUID REFERENCES medicines(id) ON DELETE SET NULL,
    medicine_name TEXT NOT NULL,
    dosage REAL NOT NULL,
    unit TEXT NOT NULL,
    frequency TEXT NOT NULL,
    scheduled_times JSONB DEFAULT '[]',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    instructions TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    server_timestamp TIMESTAMPTZ DEFAULT NOW(),  -- Conflict resolution stamp (SRS §5.3)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctors manage prescriptions"
    ON prescriptions FOR ALL USING (auth.uid() = doctor_id);
CREATE POLICY "Patients read own prescriptions"
    ON prescriptions FOR SELECT USING (auth.uid() = patient_id);

-- ── Appointments ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_connection_id UUID NOT NULL REFERENCES doctor_connections(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    location TEXT,
    appointment_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER DEFAULT 30,
    notes TEXT,
    status TEXT DEFAULT 'scheduled',
    is_verified BOOLEAN DEFAULT TRUE,  -- Doctor entries are verified (SRS §4.4)
    server_timestamp TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctors manage appointments"
    ON appointments FOR ALL USING (
        auth.uid() = (SELECT doctor_id FROM doctor_connections WHERE id = doctor_connection_id)
    );
CREATE POLICY "Patients read own appointments"
    ON appointments FOR SELECT USING (auth.uid() = patient_id);

-- ── Realtime subscriptions (for doctor->patient sync) ─────────
-- Enable realtime on these tables so patients receive instant updates
ALTER publication supabase_realtime ADD TABLE prescriptions;
ALTER publication supabase_realtime ADD TABLE appointments;
ALTER publication supabase_realtime ADD TABLE doctor_connections;

-- ── Functions ─────────────────────────────────────────────────

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_medicines_updated_at
    BEFORE UPDATE ON medicines
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_meal_routines_updated_at
    BEFORE UPDATE ON meal_routines
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_activity_logs_updated_at
    BEFORE UPDATE ON activity_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- End of VitalPath Schema
-- Run this in Supabase SQL Editor to set up your database
-- ============================================================
