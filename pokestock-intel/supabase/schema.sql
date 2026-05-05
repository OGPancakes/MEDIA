create extension if not exists "pgcrypto";

create table if not exists public.app_members (
  email text primary key,
  role text not null default 'member' check (role in ('owner', 'member')),
  created_at timestamptz not null default now()
);

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  city text not null,
  state text not null,
  latitude double precision not null,
  longitude double precision not null,
  notes_summary text,
  confidence_score integer not null default 50 check (confidence_score between 0 and 100),
  created_at timestamptz not null default now()
);

create table if not exists public.restock_logs (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  date date not null,
  time time not null,
  stock_type text not null,
  sellout_speed_minutes integer,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.intel_notes (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  note text not null,
  source_type text not null check (source_type in ('employee', 'observation', 'rumor')),
  created_at timestamptz not null default now()
);

create or replace function public.is_app_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_members
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

alter table public.app_members enable row level security;
alter table public.stores enable row level security;
alter table public.restock_logs enable row level security;
alter table public.intel_notes enable row level security;

drop policy if exists "members can read own membership" on public.app_members;
drop policy if exists "private member stores" on public.stores;
drop policy if exists "private member restock logs" on public.restock_logs;
drop policy if exists "private member intel notes" on public.intel_notes;
drop policy if exists "private authenticated stores" on public.stores;
drop policy if exists "private authenticated restock logs" on public.restock_logs;
drop policy if exists "private authenticated intel notes" on public.intel_notes;

create policy "members can read own membership" on public.app_members
  for select using (lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));

create policy "private authenticated stores" on public.stores
  for all using (public.is_app_member()) with check (public.is_app_member());

create policy "private authenticated restock logs" on public.restock_logs
  for all using (public.is_app_member()) with check (public.is_app_member());

create policy "private authenticated intel notes" on public.intel_notes
  for all using (public.is_app_member()) with check (public.is_app_member());

create index if not exists stores_location_idx on public.stores (latitude, longitude);
create index if not exists restock_logs_store_date_idx on public.restock_logs (store_id, date desc);
create index if not exists intel_notes_store_created_idx on public.intel_notes (store_id, created_at desc);

-- Add allowed users after creating Supabase Auth accounts:
-- insert into public.app_members (email, role) values
--   ('you@example.com', 'owner'),
--   ('buddy@example.com', 'member')
-- on conflict (email) do update set role = excluded.role;
