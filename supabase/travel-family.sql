-- TRAVEL FAMIGLIA — eseguire una sola volta nel Supabase SQL Editor
create table if not exists public.travel_families (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'La mia famiglia',
  invite_code text not null unique,
  shared_trips jsonb not null default '[]'::jsonb,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.travel_family_members (
  family_id uuid not null references public.travel_families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (family_id,user_id)
);
alter table public.travel_families enable row level security;
alter table public.travel_family_members enable row level security;
drop policy if exists "family members can read their families" on public.travel_families;
create policy "family members can read their families" on public.travel_families
 for select to authenticated using (
  exists(select 1 from public.travel_family_members m where m.family_id=id and m.user_id=auth.uid())
 );
drop policy if exists "family members can update shared trips" on public.travel_families;
create policy "family members can update shared trips" on public.travel_families
 for update to authenticated using (
  exists(select 1 from public.travel_family_members m where m.family_id=id and m.user_id=auth.uid())
 ) with check (
  exists(select 1 from public.travel_family_members m where m.family_id=id and m.user_id=auth.uid())
 );
drop policy if exists "users can read own family memberships" on public.travel_family_members;
create policy "users can read own family memberships" on public.travel_family_members
 for select to authenticated using (user_id=auth.uid());
create or replace function public.create_travel_family(p_name text default 'La mia famiglia')
returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid; code text;
begin
 if auth.uid() is null then raise exception 'Devi prima accedere a TRAVEL.'; end if;
 code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
 insert into public.travel_families(name,invite_code,created_by)
 values(coalesce(nullif(trim(p_name),''),'La mia famiglia'),code,auth.uid())
 returning id into new_id;
 insert into public.travel_family_members(family_id,user_id,role) values(new_id,auth.uid(),'owner');
 return new_id;
end; $$;
create or replace function public.join_travel_family(p_code text)
returns uuid language plpgsql security definer set search_path=public as $$
declare found_id uuid;
begin
 if auth.uid() is null then raise exception 'Devi prima accedere a TRAVEL.'; end if;
 select id into found_id from public.travel_families where invite_code=upper(trim(p_code));
 if found_id is null then raise exception 'Codice famiglia non valido.'; end if;
 insert into public.travel_family_members(family_id,user_id,role)
 values(found_id,auth.uid(),'member') on conflict(family_id,user_id) do nothing;
 return found_id;
end; $$;
grant execute on function public.create_travel_family(text) to authenticated;
grant execute on function public.join_travel_family(text) to authenticated;
