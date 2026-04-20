// ═══════════════════════════════════════════════════════════════════════════
// Supabase Edge Function: push-notification
// FCM push via HTTP v1 API — called from other edge functions or cron
// ═══════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects/YOUR_FIREBASE_PROJECT/messages:send";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  }

  const { user_id, title, body, data } = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")\!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")\!,
  );

  // Get FCM token
  const { data: user } = await supabase.from("users").select("fcm_token, name").eq("id", user_id).single();
  if (\!user?.fcm_token) return new Response(JSON.stringify({ skipped: "no_token" }), { status: 200 });

  // Send via FCM
  const fcmToken = Deno.env.get("FIREBASE_SERVER_KEY")\!;
  const response = await fetch(FCM_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${fcmToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: user.fcm_token,
        notification: { title, body },
        data: data ?? {},
        android: { priority: "high", notification: { channel_id: "vitalpath_reminders", sound: "default" } },
        apns: {
          payload: { aps: { alert: { title, body }, sound: "default", badge: 1 } },
        },
      },
    }),
  });

  const result = await response.json();

  // Log in DB
  await supabase.from("notifications").insert({
    user_id, title, body,
    type: data?.type ?? "system",
    sent_at: new Date().toISOString(),
    data,
  });

  return new Response(JSON.stringify(result), {
    status: response.ok ? 200 : 500,
    headers: { "Content-Type": "application/json" },
  });
});
