create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 1 and 20),
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.performances (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  title text not null,
  type text not null check (type in ('musical', 'play', 'dance', 'other')),
  event_date date not null,
  start_time time not null,
  venue text not null,
  note text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  performance_id uuid not null references public.performances(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  seat_note text,
  created_at timestamptz not null default now(),
  primary key (performance_id, user_id)
);

insert into public.groups (id, name, invite_code)
values ('00000000-0000-0000-0000-000000000001', '同场看剧群', 'TONGCHANG')
on conflict (id) do update set name = excluded.name;

create or replace function public.is_group_member(target_group uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = target_group and user_id = auth.uid()
  );
$$;

create or replace function public.shares_group(target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_user = auth.uid() or exists (
    select 1
    from public.group_members mine
    join public.group_members theirs on theirs.group_id = mine.group_id
    where mine.user_id = auth.uid() and theirs.user_id = target_user
  );
$$;

create or replace function public.join_group_by_code(invite text, display_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_group uuid;
begin
  if auth.uid() is null then raise exception '请先登录'; end if;
  if char_length(trim(display_name)) not between 1 and 20 then raise exception '昵称长度需要在 1 到 20 个字之间'; end if;

  select id into target_group from public.groups where upper(invite_code) = upper(trim(invite));
  if target_group is null then raise exception '邀请码不正确'; end if;

  insert into public.profiles (id, nickname)
  values (auth.uid(), trim(display_name))
  on conflict (id) do update set nickname = excluded.nickname;

  insert into public.group_members (group_id, user_id)
  values (target_group, auth.uid())
  on conflict do nothing;

  return target_group;
end;
$$;

revoke all on function public.join_group_by_code(text, text) from public;
grant execute on function public.join_group_by_code(text, text) to authenticated;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.shares_group(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.performances enable row level security;
alter table public.attendance enable row level security;

drop policy if exists profiles_select_group on public.profiles;
create policy profiles_select_group on public.profiles for select to authenticated using (public.shares_group(id));

drop policy if exists groups_select_member on public.groups;
create policy groups_select_member on public.groups for select to authenticated using (public.is_group_member(id));

drop policy if exists members_select_group on public.group_members;
create policy members_select_group on public.group_members for select to authenticated using (public.is_group_member(group_id));

drop policy if exists performances_select_group on public.performances;
create policy performances_select_group on public.performances for select to authenticated using (public.is_group_member(group_id));
drop policy if exists performances_insert_group on public.performances;
create policy performances_insert_group on public.performances for insert to authenticated with check (public.is_group_member(group_id) and created_by = auth.uid());
drop policy if exists performances_update_group on public.performances;
create policy performances_update_group on public.performances for update to authenticated using (public.is_group_member(group_id)) with check (public.is_group_member(group_id));
drop policy if exists performances_delete_group on public.performances;
create policy performances_delete_group on public.performances for delete to authenticated using (public.is_group_member(group_id));

drop policy if exists attendance_select_group on public.attendance;
create policy attendance_select_group on public.attendance for select to authenticated using (
  exists (select 1 from public.performances p where p.id = performance_id and public.is_group_member(p.group_id))
);
drop policy if exists attendance_insert_group on public.attendance;
create policy attendance_insert_group on public.attendance for insert to authenticated with check (
  exists (select 1 from public.performances p where p.id = performance_id and public.is_group_member(p.group_id))
  and public.shares_group(user_id)
);
drop policy if exists attendance_update_group on public.attendance;
create policy attendance_update_group on public.attendance for update to authenticated using (
  exists (select 1 from public.performances p where p.id = performance_id and public.is_group_member(p.group_id))
);
drop policy if exists attendance_delete_group on public.attendance;
create policy attendance_delete_group on public.attendance for delete to authenticated using (
  exists (select 1 from public.performances p where p.id = performance_id and public.is_group_member(p.group_id))
);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'performances') then
    alter publication supabase_realtime add table public.performances;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'attendance') then
    alter publication supabase_realtime add table public.attendance;
  end if;
end $$;

