// ═══════════════════════════════════════════════════════════════════════════
// Supabase Edge Function: log-dose
// §5.2 — Server-side duplicate detection + atomic insert
// Runtime: Deno (TypeScript)
// ═══════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DUPLICATE_WINDOW_MINS = 15;
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface LogDoseRequest {
  medication_id:  string;
  patient_id:     string;
  scheduled_at:   string;
  source?:        string;
  force_log?:     boolean;
  timezone?:      string;
}

serve(async (req: Request) => {
  // ── CORS preflight ──────────────────────────────────────
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // ── Auth: extract JWT ───────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (\!authHeader) {
      return json({ error: "Unauthorized" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")\!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")\!,  // service role for bypass RLS in atomic ops
    );

    // ── Parse body ──────────────────────────────────────────
    const body: LogDoseRequest = await req.json();
    const { medication_id, patient_id, scheduled_at, source = "manual", force_log = false, timezone } = body;

    if (\!medication_id || \!patient_id || \!scheduled_at) {
      return json({ error: "Missing required fields" }, 400);
    }

    // ── §5.2 Duplicate check ────────────────────────────────
    if (\!force_log) {
      const windowStart = new Date(Date.now() - DUPLICATE_WINDOW_MINS * 60 * 1000).toISOString();

      const { data: recentLogs, error: fetchErr } = await supabase
        .from("medication_logs")
        .select("id, logged_at")
        .eq("medication_id", medication_id)
        .eq("patient_id", patient_id)
        .eq("status", "completed")
        .gte("logged_at", windowStart)
        .order("logged_at", { ascending: false })
        .limit(1);

      if (fetchErr) throw fetchErr;

      if (recentLogs && recentLogs.length > 0) {
        const lastLog = recentLogs[0];
        const minsAgo = Math.round((Date.now() - new Date(lastLog.logged_at).getTime()) / 60000);
        return json({
          code: "DUPLICATE_DOSE",
          last_logged_at: lastLog.logged_at,
          minutes_ago: minsAgo,
          message: `Dose logged ${minsAgo} minute(s) ago. Use force_log=true to override.`,
        }, 409);
      }
    }

    // ── Verify medication belongs to patient ────────────────
    const { data: med, error: medErr } = await supabase
      .from("medications")
      .select("id, is_active")
      .eq("id", medication_id)
      .eq("patient_id", patient_id)
      .eq("is_active", true)
      .single();

    if (medErr || \!med) {
      return json({ error: "Medication not found or inactive" }, 404);
    }

    // ── Atomic insert ───────────────────────────────────────
    const now = new Date().toISOString();
    const { data: log, error: insertErr } = await supabase
      .from("medication_logs")
      .insert({
        medication_id,
        patient_id,
        scheduled_at,
        logged_at:    now,
        status:       "completed",
        source:       force_log ? "force" : source,
        is_duplicate: force_log,
        timezone:     timezone ?? "UTC",
      })
      .select()
      .single();

    if (insertErr) throw insertErr;

    // ── Trigger push notification (async, non-blocking) ─────
    EdgeRuntime.waitUntil(sendDoseLoggedNotification(supabase, patient_id, medication_id));

    return json(log, 200);

  } catch (err) {
    console.error("[log-dose] Error:", err);
    return json({ error: err instanceof Error ? err.message : "Internal error" }, 500);
  }
});

async function sendDoseLoggedNotification(supabase: ReturnType<typeof createClient>, patientId: string, medicationId: string) {
  try {
    const { data: med } = await supabase.from("medications").select("name").eq("id", medicationId).single();
    const { data: user } = await supabase.from("users").select("fcm_token").eq("id", patientId).single();

    if (\!user?.fcm_token || \!med?.name) return;

    // Insert notification record
    await supabase.from("notifications").insert({
      user_id: patientId,
      type:    "dose_logged",
      title:   `${med.name} logged`,
      body:    `Dose recorded at ${new Date().toLocaleTimeString()}`,
      sent_at: new Date().toISOString(),
    });

    // TODO: Call Firebase FCM API with user.fcm_token
  } catch (e) {
    console.warn("[notify] Failed:", e);
  }
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
