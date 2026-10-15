// Supabase Edge Function: admin-create-player
// Deploy with: supabase functions deploy admin-create-player
// Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY as function secrets.
// The service-role key MUST never be added to index.html or GitHub.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!url || !serviceKey || !authHeader) return new Response(JSON.stringify({ error: "Server configuration missing" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const adminClient = createClient(url, serviceKey, { auth: { persistSession: false } });
  const token = authHeader.replace(/^Bearer\s+/i, "");
  const { data: userData, error: userError } = await adminClient.auth.getUser(token);
  if (userError || !userData.user || userData.user.app_metadata?.role !== "admin") {
    return new Response(JSON.stringify({ error: "Admin access required" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  let body;
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
  const playerId = String(body.player_id || "");
  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "");
  if (!playerId || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 10) {
    return new Response(JSON.stringify({ error: "Valid player, email, and password of at least 10 characters are required" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  const { data: player, error: playerError } = await adminClient.from("players").select("id").eq("id", playerId).maybeSingle();
  if (playerError || !player) return new Response(JSON.stringify({ error: "Roster player not found" }), { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({ email, password, email_confirm: true, app_metadata: { role: "player" } });
  if (createError || !created.user) return new Response(JSON.stringify({ error: createError?.message || "User creation failed" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  const { error: profileError } = await adminClient.from("player_profiles").insert({ player_id: playerId, user_id: created.user.id, show_stats: true });
  if (profileError) {
    await adminClient.auth.admin.deleteUser(created.user.id);
    return new Response(JSON.stringify({ error: profileError.message }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  return new Response(JSON.stringify({ ok: true, player_id: playerId }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
