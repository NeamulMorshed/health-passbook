-- ═══════════════════════════════════════════════════════════════════════════
-- Row Level Security Policies — VitalPath
-- Principle: patients own their data; doctors see only their linked patients
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.users             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medication_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_sessions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_patient_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications     ENABLE ROW LEVEL SECURITY;

-- ── Helper: is the caller a doctor linked to this patient? ─────────────────
CREATE OR REPLACE FUNCTION public.is_doctor_of(p_patient_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.doctor_patient_links dpl
    JOIN public.users u ON u.id = auth.uid()
    WHERE dpl.doctor_id = auth.uid()
      AND dpl.patient_id = p_patient_id
      AND dpl.is_active = TRUE
      AND u.role = 'doctor'
  );
$$;

-- ── USERS ─────────────────────────────────────────────────────────────────────
CREATE POLICY "Users: read own profile"
  ON public.users FOR SELECT USING (id = auth.uid());

CREATE POLICY "Doctors: read linked patient profiles"
  ON public.users FOR SELECT
  USING (is_doctor_of(id));

CREATE POLICY "Users: update own profile"
  ON public.users FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Users: insert own profile (signup)"
  ON public.users FOR INSERT WITH CHECK (id = auth.uid());

-- ── MEDICATIONS ───────────────────────────────────────────────────────────────
CREATE POLICY "Patients: read own medications"
  ON public.medications FOR SELECT
  USING (patient_id = auth.uid());

CREATE POLICY "Doctors: read linked patient medications"
  ON public.medications FOR SELECT
  USING (is_doctor_of(patient_id));

CREATE POLICY "Doctors: insert prescriptions for linked patients"
  ON public.medications FOR INSERT
  WITH CHECK (
    is_doctor_of(patient_id) AND
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'doctor')
  );

CREATE POLICY "Doctors: soft-delete (update) own prescriptions"
  ON public.medications FOR UPDATE
  USING (
    prescribed_by = auth.uid() AND
    is_doctor_of(patient_id)
  );

-- ── MEDICATION LOGS ───────────────────────────────────────────────────────────
CREATE POLICY "Patients: read own logs"
  ON public.medication_logs FOR SELECT
  USING (patient_id = auth.uid());

CREATE POLICY "Doctors: read linked patient logs"
  ON public.medication_logs FOR SELECT
  USING (is_doctor_of(patient_id));

CREATE POLICY "Patients: insert own logs (via Edge Function)"
  ON public.medication_logs FOR INSERT
  WITH CHECK (patient_id = auth.uid());

CREATE POLICY "Patients: update own log status (undo)"
  ON public.medication_logs FOR UPDATE
  USING (patient_id = auth.uid() AND status \!= 'completed');

-- ── ACTIVITY LOGS ─────────────────────────────────────────────────────────────
CREATE POLICY "Patients: full access to own activity"
  ON public.activity_logs FOR ALL
  USING (patient_id = auth.uid());

CREATE POLICY "Doctors: read linked patient activity"
  ON public.activity_logs FOR SELECT
  USING (is_doctor_of(patient_id));

-- ── SYNC SESSIONS ─────────────────────────────────────────────────────────────
CREATE POLICY "Doctors: manage own sync sessions"
  ON public.sync_sessions FOR ALL
  USING (doctor_id = auth.uid());

CREATE POLICY "Patients: connect to sync session"
  ON public.sync_sessions FOR SELECT
  USING (TRUE);  -- any authenticated user can read a session code to connect

-- ── DOCTOR-PATIENT LINKS ──────────────────────────────────────────────────────
CREATE POLICY "Doctors: read own links"
  ON public.doctor_patient_links FOR SELECT
  USING (doctor_id = auth.uid());

CREATE POLICY "Patients: read own links"
  ON public.doctor_patient_links FOR SELECT
  USING (patient_id = auth.uid());

CREATE POLICY "Doctors: create links"
  ON public.doctor_patient_links FOR INSERT
  WITH CHECK (doctor_id = auth.uid());

-- ── NOTIFICATIONS ─────────────────────────────────────────────────────────────
CREATE POLICY "Users: read own notifications"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users: mark own as read"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid());
