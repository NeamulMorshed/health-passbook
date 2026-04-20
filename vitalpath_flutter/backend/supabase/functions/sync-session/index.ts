// ═══════════════════════════════════════════════════════════════════════════
// Supabase Edge Function: sync-session
// Doctor-Patient real-time sync code management
// ═══════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const SESSION_TTL_SECONDS = 600;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")\!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")\!,
  );

  const url = new URL(req.url);
  const action = url.searchParams.get("action") ?? "create";

  try {
    // ── CREATE — doctor generates a new code ─────────────────
    if (req.method === "POST" && action === "create") {
      const { doctor_id } = await req.json();
      if (\!doctor_id) return json({ error: "doctor_id required" }, 400);

      // Expire any previous unused sessions for this doctor
      await supabase.from("sync_sessions")
        .update({ expires_at: new Date().toISOString() })
        .eq("doctor_id", doctor_id)
        .eq("is_connected", false);

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + SESSION_TTL_SECONDS * 1000).toISOString();

      const { data, error } = await supabase.from("sync_sessions")
        .insert({ code, doctor_id, expires_at: expiresAt, is_connected: false })
        .select().single();

      if (error) throw error;
      return json(data);
    }

    // ── CONNECT — patient scans code and links ────────────────
    if (req.method === "POST" && action === "connect") {
      const { code, patient_id } = await req.json();
      if (\!code || \!patient_id) return json({ error: "code and patient_id required" }, 400);

      const { data: session, error: fetchErr } = await supabase
        .from("sync_sessions").select().eq("code", code).single();

      if (fetchErr || \!session) return json({ error: "Invalid code" }, 404);
      if (new Date(session.expires_at) < new Date()) return json({ error: "Code expired" }, 410);
      if (session.is_connected) return json({ error: "Code already used" }, 409);

      // Link the patient to this session
      const { data: updated, error: updateErr } = await supabase
        .from("sync_sessions")
        .update({ patient_id, is_connected: true, connected_at: new Date().toISOString() })
        .eq("code", code).select().single();

      if (updateErr) throw updateErr;

      // Create doctor-patient link if not exists
      await supabase.from("doctor_patient_links").upsert({
        doctor_id:  session.doctor_id,
        patient_id,
        is_active:  true,
        linked_at:  new Date().toISOString(),
      }, { onConflict: "doctor_id,patient_id" });

      return json(updated);
    }

    return json({ error: "Unknown action" }, 400);
  } catch (err) {
    console.error("[sync-session]", err);
    return json({ error: err instanceof Error ? err.message : "Error" }, 500);
  }
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
