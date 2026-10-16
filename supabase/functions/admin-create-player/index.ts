import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), auth = req.headers.get("Authorization");
  if (!url || !serviceKey || !auth) return json({ error: "Sunucu ayarları eksik; Supabase secrets kontrol edilmeli." }, 500);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const token = auth.replace(/^Bearer\s+/i, "");
  const { data: caller, error: callerError } = await admin.auth.getUser(token);
  if (callerError || !caller.user || caller.user.app_metadata?.role !== "admin") return json({ error: "Bu işlem yalnızca yöneticiye açıktır." }, 403);
  let body: Record<string, unknown>; try { body = await req.json(); } catch { return json({ error: "Geçersiz JSON." }, 400); }
  const playerId = String(body.player_id || "");
  const username = String(body.username || "").trim().toLowerCase();
  const password = String(body.password || "");
  if (!playerId || !/^[a-z0-9._-]{3,24}$/.test(username) || password.length < 10) return json({ error: "Oyuncu, 3-24 karakterli kullanıcı adı ve en az 10 karakterli şifre gerekli." }, 400);
  const email = `${username}@players.f4f.local`;
  const { data: player, error: playerError } = await admin.from("players").select("id").eq("id", playerId).maybeSingle();
  if (playerError || !player) return json({ error: "Kadro oyuncusu bulunamadı." }, 404);
  const { data: created, error: createError } = await admin.auth.admin.createUser({ email, password, email_confirm: true, app_metadata: { role: "player", username } });
  if (createError || !created.user) return json({ error: createError?.message || "Hesap oluşturulamadı. Kullanıcı adı daha önce alınmış olabilir." }, 400);
  const { error: profileError } = await admin.from("player_profiles").insert({ player_id: playerId, user_id: created.user.id, show_stats: true });
  if (profileError) { await admin.auth.admin.deleteUser(created.user.id); return json({ error: profileError.message }, 400); }
  return json({ ok: true, player_id: playerId, username });
});
