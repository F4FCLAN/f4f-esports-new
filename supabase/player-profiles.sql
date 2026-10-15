-- F4F Esports player profile setup
-- Verify public.players.id is UUID before running this script.

create table if not exists public.player_profiles (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null unique references public.players(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  bio text not null default '',
  tiktok_url text,
  show_stats boolean not null default true,
  win_rate numeric(5,2),
  headshot_pct numeric(5,2),
  kd numeric(6,2),
  acs integer,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_win_rate_range check (win_rate is null or (win_rate >= 0 and win_rate <= 100)),
  constraint profile_hs_range check (headshot_pct is null or (headshot_pct >= 0 and headshot_pct <= 100)),
  constraint profile_kd_range check (kd is null or (kd >= 0 and kd <= 10)),
  constraint profile_acs_range check (acs is null or (acs >= 0 and acs <= 2000))
);

alter table public.player_profiles enable row level security;
alter table public.players enable row level security;

-- Profile rows contain private user_id mapping, so only the linked player and admins can read/update them.
drop policy if exists "player can read own profile" on public.player_profiles;
create policy "player can read own profile" on public.player_profiles
for select to authenticated
using (user_id = auth.uid() or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "player can update own profile" on public.player_profiles;
create policy "player can update own profile" on public.player_profiles
for update to authenticated
using (user_id = auth.uid() or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check (user_id = auth.uid() or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "admin can manage profiles" on public.player_profiles;
create policy "admin can manage profiles" on public.player_profiles
for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Public-safe profile endpoint: never returns user_id, and hides numeric stats when show_stats=false.
create or replace function public.get_public_player_profile(p_player_id uuid)
returns table (
  player_id uuid,
  bio text,
  tiktok_url text,
  show_stats boolean,
  win_rate numeric,
  headshot_pct numeric,
  kd numeric,
  acs integer,
  avatar_url text
)
language sql
security definer
set search_path = public
as $$
  select
    pp.player_id,
    pp.bio,
    pp.tiktok_url,
    pp.show_stats,
    case when pp.show_stats then pp.win_rate else null end,
    case when pp.show_stats then pp.headshot_pct else null end,
    case when pp.show_stats then pp.kd else null end,
    case when pp.show_stats then pp.acs else null end,
    pp.avatar_url
  from public.player_profiles pp
  where pp.player_id = p_player_id;
$$;

revoke all on function public.get_public_player_profile(uuid) from public;
grant execute on function public.get_public_player_profile(uuid) to anon, authenticated;

-- A linked player may update only their own public nick/rank.
drop policy if exists "player can update linked roster row" on public.players;
create policy "player can update linked roster row" on public.players
for update to authenticated
using (exists (select 1 from public.player_profiles pp where pp.player_id = players.id and pp.user_id = auth.uid()))
with check (exists (select 1 from public.player_profiles pp where pp.player_id = players.id and pp.user_id = auth.uid()));

drop policy if exists "admin can manage players" on public.players;
create policy "admin can manage players" on public.players
for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Existing public roster reads still need a SELECT policy if one is not already configured.
drop policy if exists "public can read active players" on public.players;
create policy "public can read active players" on public.players
for select to anon, authenticated
using (active = true or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Profile images use player-avatars/profiles/<auth.uid()>/<filename>.
drop policy if exists "players upload own profile images" on storage.objects;
create policy "players upload own profile images" on storage.objects
for insert to authenticated
with check (bucket_id = 'player-avatars' and (storage.foldername(name))[1] = 'profiles' and (storage.foldername(name))[2] = auth.uid()::text);

drop policy if exists "players update own profile images" on storage.objects;
create policy "players update own profile images" on storage.objects
for update to authenticated
using (bucket_id = 'player-avatars' and (storage.foldername(name))[1] = 'profiles' and (storage.foldername(name))[2] = auth.uid()::text)
with check (bucket_id = 'player-avatars' and (storage.foldername(name))[1] = 'profiles' and (storage.foldername(name))[2] = auth.uid()::text);

drop policy if exists "players delete own profile images" on storage.objects;
create policy "players delete own profile images" on storage.objects
for delete to authenticated
using (bucket_id = 'player-avatars' and (storage.foldername(name))[1] = 'profiles' and (storage.foldername(name))[2] = auth.uid()::text);
