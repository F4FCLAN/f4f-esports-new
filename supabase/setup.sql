-- F4F Esports - idempotent setup/migration for the existing project.
-- Run in Supabase SQL Editor. Keep RLS enabled; never put service-role keys in the website.
create extension if not exists pgcrypto;

create table if not exists public.players (
 id uuid primary key default gen_random_uuid(), nick text not null, rank text not null default 'Ascendant',
 avatar_url text, active boolean not null default true, sort_order integer not null default 0, created_at timestamptz not null default now()
);
alter table public.players add column if not exists nick text;
alter table public.players add column if not exists rank text default 'Ascendant';
alter table public.players add column if not exists avatar_url text;
alter table public.players add column if not exists active boolean not null default true;
alter table public.players add column if not exists sort_order integer not null default 0;
alter table public.players add column if not exists created_at timestamptz not null default now();

create table if not exists public.player_profiles (
 id uuid primary key default gen_random_uuid(), player_id uuid not null unique references public.players(id) on delete cascade,
 user_id uuid not null unique references auth.users(id) on delete cascade, bio text not null default '', tiktok_url text,
 show_stats boolean not null default true, win_rate numeric(5,2), headshot_pct numeric(5,2), kd numeric(6,2), acs integer,
 avatar_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.player_profiles add column if not exists bio text not null default '';
alter table public.player_profiles add column if not exists tiktok_url text;
alter table public.player_profiles add column if not exists show_stats boolean not null default true;
alter table public.player_profiles add column if not exists win_rate numeric(5,2);
alter table public.player_profiles add column if not exists headshot_pct numeric(5,2);
alter table public.player_profiles add column if not exists kd numeric(6,2);
alter table public.player_profiles add column if not exists acs integer;
alter table public.player_profiles add column if not exists avatar_url text;
alter table public.player_profiles add column if not exists updated_at timestamptz not null default now();

create table if not exists public.join_applications (
 id uuid primary key default gen_random_uuid(), tracking_code text unique not null, game_nick text not null, full_name text not null,
 age integer not null, rank text not null, introduction text default '', status text not null default 'pending', created_at timestamptz not null default now()
);
alter table public.join_applications add column if not exists tracking_code text;
alter table public.join_applications add column if not exists game_nick text;
alter table public.join_applications add column if not exists full_name text;
alter table public.join_applications add column if not exists age integer;
alter table public.join_applications add column if not exists rank text;
alter table public.join_applications add column if not exists introduction text default '';
alter table public.join_applications add column if not exists status text not null default 'pending';
alter table public.join_applications add column if not exists created_at timestamptz not null default now();

create table if not exists public.match_requests (
 id uuid primary key default gen_random_uuid(), tracking_code text unique not null, rival_clan text not null, contact text not null,
 rank_one text not null, rank_two text not null, match_date date not null, match_time text not null default '20:00', note text default '',
 status text not null default 'pending', requested_at timestamptz not null default now(), created_at timestamptz not null default now()
);
alter table public.match_requests add column if not exists tracking_code text;
alter table public.match_requests add column if not exists rival_clan text;
alter table public.match_requests add column if not exists contact text;
alter table public.match_requests add column if not exists rank_one text;
alter table public.match_requests add column if not exists rank_two text;
alter table public.match_requests add column if not exists match_date date;
alter table public.match_requests add column if not exists match_time text default '20:00';
alter table public.match_requests add column if not exists note text default '';
alter table public.match_requests add column if not exists status text not null default 'pending';
alter table public.match_requests add column if not exists requested_at timestamptz not null default now();
alter table public.match_requests add column if not exists created_at timestamptz not null default now();

create table if not exists public.matches (
 id uuid primary key default gen_random_uuid(), opponent text not null, score text not null, match_date date not null,
 result text not null, created_at timestamptz not null default now()
);
alter table public.matches add column if not exists opponent text;
alter table public.matches add column if not exists score text;
alter table public.matches add column if not exists match_date date;
alter table public.matches add column if not exists result text;
alter table public.matches add column if not exists created_at timestamptz not null default now();

alter table public.players enable row level security;
alter table public.player_profiles enable row level security;
alter table public.join_applications enable row level security;
alter table public.match_requests enable row level security;
alter table public.matches enable row level security;

-- Remove any policies from previous prototypes on these five application tables.
-- This prevents an older permissive policy from accidentally overriding this setup.
do $$
declare pol record;
begin
  for pol in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname='public'
      and tablename in ('players','player_profiles','join_applications','match_requests','matches')
  loop
    execute format('drop policy if exists %I on %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  end loop;
end $$;

-- Explicit API grants; row-level security below decides which rows each role may use.
grant select on public.players to anon, authenticated;
grant insert, update, delete on public.players to authenticated;
grant select, insert, update, delete on public.player_profiles to authenticated;
grant insert on public.join_applications to anon, authenticated;
grant select, update, delete on public.join_applications to authenticated;
grant insert on public.match_requests to anon, authenticated;
grant select, update, delete on public.match_requests to authenticated;
grant select on public.matches to anon, authenticated;
grant insert, update, delete on public.matches to authenticated;

-- Public roster reads only active players; admins can manage the roster; linked player can edit their own nick/rank/avatar.
drop policy if exists "F4F public active roster" on public.players;
create policy "F4F public active roster" on public.players for select to anon, authenticated using (active = true or (auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "F4F admin manages roster" on public.players;
create policy "F4F admin manages roster" on public.players for all to authenticated using ((auth.jwt()->'app_metadata'->>'role')='admin') with check ((auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "F4F player updates own roster row" on public.players;
create policy "F4F player updates own roster row" on public.players for update to authenticated using (exists(select 1 from public.player_profiles pp where pp.player_id=players.id and pp.user_id=auth.uid())) with check (exists(select 1 from public.player_profiles pp where pp.player_id=players.id and pp.user_id=auth.uid()));

-- Profile mapping user_id is private. Public sees only safe fields through RPC below.
drop policy if exists "F4F player reads own profile" on public.player_profiles;
create policy "F4F player reads own profile" on public.player_profiles for select to authenticated using (user_id=auth.uid() or (auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "F4F player updates own profile" on public.player_profiles;
create policy "F4F player updates own profile" on public.player_profiles for update to authenticated using (user_id=auth.uid() or (auth.jwt()->'app_metadata'->>'role')='admin') with check (user_id=auth.uid() or (auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "F4F admin manages profiles" on public.player_profiles;
create policy "F4F admin manages profiles" on public.player_profiles for all to authenticated using ((auth.jwt()->'app_metadata'->>'role')='admin') with check ((auth.jwt()->'app_metadata'->>'role')='admin');

-- Public can submit forms, but only admins can read or change application/request records.
drop policy if exists "F4F public submits applications" on public.join_applications;
create policy "F4F public submits applications" on public.join_applications for insert to anon, authenticated with check (status='pending');
drop policy if exists "F4F admin manages applications" on public.join_applications;
create policy "F4F admin manages applications" on public.join_applications for all to authenticated using ((auth.jwt()->'app_metadata'->>'role')='admin') with check ((auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "F4F public submits match requests" on public.match_requests;
create policy "F4F public submits match requests" on public.match_requests for insert to anon, authenticated with check (status='pending');
drop policy if exists "F4F admin manages match requests" on public.match_requests;
create policy "F4F admin manages match requests" on public.match_requests for all to authenticated using ((auth.jwt()->'app_metadata'->>'role')='admin') with check ((auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "F4F public reads match history" on public.matches;
create policy "F4F public reads match history" on public.matches for select to anon, authenticated using (true);
drop policy if exists "F4F admin manages match history" on public.matches;
create policy "F4F admin manages match history" on public.matches for all to authenticated using ((auth.jwt()->'app_metadata'->>'role')='admin') with check ((auth.jwt()->'app_metadata'->>'role')='admin');

drop function if exists public.get_public_player_profile(uuid);
create function public.get_public_player_profile(p_player_id uuid)
returns table(player_id uuid,bio text,tiktok_url text,show_stats boolean,win_rate numeric,headshot_pct numeric,kd numeric,acs integer,avatar_url text)
language sql stable security definer set search_path=public as $$
 select pp.player_id,pp.bio,pp.tiktok_url,pp.show_stats,
 case when pp.show_stats then pp.win_rate else null end,
 case when pp.show_stats then pp.headshot_pct else null end,
 case when pp.show_stats then pp.kd else null end,
 case when pp.show_stats then pp.acs else null end,pp.avatar_url
 from public.player_profiles pp join public.players p on p.id=pp.player_id where pp.player_id=p_player_id and p.active=true;
$$;
revoke all on function public.get_public_player_profile(uuid) from public;
grant execute on function public.get_public_player_profile(uuid) to anon,authenticated;

drop function if exists public.lookup_tracking_status(text);
create function public.lookup_tracking_status(p_tracking_code text)
returns table(record_type text,status text,match_date date,match_time text)
language sql stable security definer set search_path=public as $$
 select 'application'::text,a.status,null::date,null::text from public.join_applications a where upper(a.tracking_code)=upper(p_tracking_code)
 union all
 select 'match'::text,m.status,m.match_date,m.match_time from public.match_requests m where upper(m.tracking_code)=upper(p_tracking_code)
 limit 1;
$$;
revoke all on function public.lookup_tracking_status(text) from public;
grant execute on function public.lookup_tracking_status(text) to anon,authenticated;


-- Prevent a player from taking over a different roster/profile link or changing admin-controlled roster flags.
create or replace function public.f4f_protect_player_links()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(auth.jwt()->'app_metadata'->>'role','') <> 'admin' then
    if new.player_id is distinct from old.player_id or new.user_id is distinct from old.user_id then
      raise exception 'Oyuncu hesap bağlantısı yalnızca yönetici tarafından değiştirilebilir.';
    end if;
  end if;
  new.updated_at = now();
  return new;
end; $$;
drop trigger if exists f4f_protect_player_links on public.player_profiles;
create trigger f4f_protect_player_links before update on public.player_profiles
for each row execute function public.f4f_protect_player_links();

create or replace function public.f4f_protect_roster_fields()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(auth.jwt()->'app_metadata'->>'role','') <> 'admin' then
    if new.active is distinct from old.active or new.sort_order is distinct from old.sort_order then
      raise exception 'Kadro durumu ve sıralaması yalnızca yönetici tarafından değiştirilebilir.';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists f4f_protect_roster_fields on public.players;
create trigger f4f_protect_roster_fields before update on public.players
for each row execute function public.f4f_protect_roster_fields();

-- Public avatars bucket; players may upload only inside profiles/<their auth uid>/.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('player-avatars','player-avatars',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=true;
drop policy if exists "F4F public reads avatars" on storage.objects;
create policy "F4F public reads avatars" on storage.objects for select to anon,authenticated using (bucket_id='player-avatars');
drop policy if exists "F4F player uploads own avatar" on storage.objects;
create policy "F4F player uploads own avatar" on storage.objects for insert to authenticated with check (bucket_id='player-avatars' and (storage.foldername(name))[1]='profiles' and (storage.foldername(name))[2]=auth.uid()::text);
drop policy if exists "F4F player updates own avatar" on storage.objects;
create policy "F4F player updates own avatar" on storage.objects for update to authenticated using (bucket_id='player-avatars' and (storage.foldername(name))[1]='profiles' and (storage.foldername(name))[2]=auth.uid()::text) with check (bucket_id='player-avatars' and (storage.foldername(name))[1]='profiles' and (storage.foldername(name))[2]=auth.uid()::text);
