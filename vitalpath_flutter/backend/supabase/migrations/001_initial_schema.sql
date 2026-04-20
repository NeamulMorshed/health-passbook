-- ═══════════════════════════════════════════════════════════════════════════
-- VitalPath — Supabase PostgreSQL Schema
-- Designed for scalability: RLS, indexes, TimescaleDB-ready columns
-- ═══════════════════════════════════════════════════════════════════════════

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- fuzzy search on names
CREATE EXTENSION IF NOT EXISTS "btree_gist";     -- time-range overlap checks

-- ─── USERS ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone             TEXT NOT NULL,
  name              TEXT,
  avatar_url        TEXT,
  role              TEXT NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'doctor', 'admin')),
  email             TEXT,
  date_of_birth     DATE,
  gender            TEXT CHECK (gender IN ('M', 'F', 'O', NULL)),
  primary_condition TEXT,
  is_onboarded      BOOLEAN NOT NULL DEFAULT FALSE,
  fcm_token         TEXT,                            -- Firebase push token
  timezone          TEXT DEFAULT 'UTC',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_role    ON public.users(role);
CREATE INDEX idx_users_phone   ON public.users(phone);
CREATE INDEX idx_users_name_trgm ON public.users USING gin(name gin_trgm_ops);

-- ─── DOCTOR-PATIENT LINKS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.doctor_patient_links (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doctor_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  patient_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  linked_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  unlinked_at TIMESTAMPTZ,
  UNIQUE (doctor_id, patient_id)
);

CREATE INDEX idx_dpl_doctor  ON public.doctor_patient_links(doctor_id);
CREATE INDEX idx_dpl_patient ON public.doctor_patient_links(patient_id);

-- ─── MEDICATIONS ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.medications (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  prescribed_by    UUID REFERENCES public.users(id),        -- doctor user_id
  name             TEXT NOT NULL,
  dosage           TEXT NOT NULL,
  frequency        TEXT NOT NULL,
  scheduled_times  TIMESTAMPTZ[] NOT NULL DEFAULT '{}',     -- recurring daily times
  instructions     TEXT,
  is_verified      BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at      TIMESTAMPTZ,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  color            TEXT,
  icon_type        TEXT DEFAULT 'pill' CHECK (icon_type IN ('pill','capsule','liquid','injection','patch')),
  remaining_count  INTEGER,
  total_count      INTEGER,
  next_refill_date DATE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ                              -- soft delete
);

CREATE INDEX idx_medications_patient   ON public.medications(patient_id);
CREATE INDEX idx_medications_active    ON public.medications(patient_id, is_active);
CREATE INDEX idx_medications_verified  ON public.medications(is_verified);

-- ─── MEDICATION LOGS ─────────────────────────────────────────────────────────
-- Core audit table — every log action is immutable (append-only for audit trail)
CREATE TABLE IF NOT EXISTS public.medication_logs (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  medication_id  UUID NOT NULL REFERENCES public.medications(id) ON DELETE CASCADE,
  patient_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  scheduled_at   TIMESTAMPTZ NOT NULL,
  logged_at      TIMESTAMPTZ,
  status         TEXT NOT NULL DEFAULT 'upcoming'
                   CHECK (status IN ('upcoming','in_progress','completed','overdue','skipped','undone')),
  source         TEXT DEFAULT 'manual'
                   CHECK (source IN ('manual','reminder','force','auto','doctor')),
  notes          TEXT,
  is_duplicate   BOOLEAN NOT NULL DEFAULT FALSE,     -- §5.2 — flagged duplicate
  timezone       TEXT,                               -- §5.4 — IANA timezone at log time
  device_info    JSONB,                              -- platform, OS version
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TimescaleDB hypertable candidate (partition by logged_at)
-- SELECT create_hypertable('medication_logs', 'scheduled_at');

CREATE INDEX idx_logs_patient_time ON public.medication_logs(patient_id, scheduled_at DESC);
CREATE INDEX idx_logs_medication   ON public.medication_logs(medication_id, logged_at DESC);
CREATE INDEX idx_logs_status       ON public.medication_logs(status);

-- ─── ACTIVITY LOGS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date                DATE NOT NULL,
  steps               INTEGER NOT NULL DEFAULT 0,
  step_goal           INTEGER NOT NULL DEFAULT 10000,
  distance_km         NUMERIC(6,2),
  active_minutes      INTEGER,
  weight_kg           NUMERIC(5,2),          -- §5.6 — validated 30–250 kg
  blood_pressure_sys  INTEGER,
  blood_pressure_dia  INTEGER,
  heart_rate_bpm      INTEGER,
  blood_glucose       NUMERIC(5,2),          -- mmol/L
  spo2                NUMERIC(4,1),          -- %
  sleep_minutes       INTEGER,
  mood_score          INTEGER CHECK (mood_score BETWEEN 1 AND 5),
  symptoms            TEXT[],
  notes               TEXT,
  source              TEXT DEFAULT 'manual' CHECK (source IN ('manual','healthkit','health_connect','wearable')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (patient_id, date)
);

CREATE INDEX idx_activity_patient_date ON public.activity_logs(patient_id, date DESC);

-- ─── SYNC SESSIONS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sync_sessions (
  code         TEXT PRIMARY KEY,                     -- 6-digit code
  doctor_id    UUID NOT NULL REFERENCES public.users(id),
  patient_id   UUID REFERENCES public.users(id),
  expires_at   TIMESTAMPTZ NOT NULL,                 -- NOW() + 10 min
  is_connected BOOLEAN NOT NULL DEFAULT FALSE,
  connected_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_sessions_doctor  ON public.sync_sessions(doctor_id);
CREATE INDEX idx_sync_sessions_expires ON public.sync_sessions(expires_at);

-- Auto-cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sync_sessions()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.sync_sessions WHERE expires_at < NOW() - INTERVAL '1 hour';
END;
$$;

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,   -- 'dose_reminder' | 'duplicate_alert' | 'rx_added' | 'refill_reminder'
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  data        JSONB,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at     TIMESTAMPTZ,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON public.notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id) WHERE is_read = FALSE;

-- ─── UPDATED_AT TRIGGER ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_medications_updated_at BEFORE UPDATE ON public.medications FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── ADHERENCE STATS VIEW ─────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.patient_adherence_7d AS
SELECT
  patient_id,
  COUNT(*) FILTER (WHERE status = 'completed' AND scheduled_at >= NOW() - INTERVAL '7 days') AS completed_7d,
  COUNT(*) FILTER (WHERE status IN ('completed','overdue','skipped') AND scheduled_at >= NOW() - INTERVAL '7 days') AS total_7d,
  ROUND(
    COUNT(*) FILTER (WHERE status = 'completed' AND scheduled_at >= NOW() - INTERVAL '7 days')::NUMERIC /
    NULLIF(COUNT(*) FILTER (WHERE status IN ('completed','overdue','skipped') AND scheduled_at >= NOW() - INTERVAL '7 days'), 0) * 100, 1
  ) AS adherence_pct_7d
FROM public.medication_logs
GROUP BY patient_id;
