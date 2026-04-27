create extension if not exists pgcrypto;
create schema if not exists private;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.touch_parent_chart()
returns trigger
language plpgsql
as $$
declare
  target_chart uuid;
begin
  target_chart := coalesce(new.chart_id, old.chart_id);
  if target_chart is not null then
    update public.charts
    set updated_at = now()
    where id = target_chart;
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function private.current_user_email()
returns text
language sql
stable
as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

create table if not exists public.charts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chart_access (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  email text not null,
  role text not null check (role in ('viewer','editor')),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (chart_id, email),
  check (email = lower(email))
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  name text not null,
  color text not null,
  bg text not null,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (chart_id, name)
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  chart_id uuid not null references public.charts(id) on delete cascade,
  task text not null,
  description text not null default '',
  outputs text not null default '',
  project text not null,
  start_date date not null,
  end_date date not null,
  delivery boolean not null default false,
  done boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_date <= end_date)
);

create index if not exists charts_owner_idx on public.charts(owner_id);
create index if not exists chart_access_chart_email_idx on public.chart_access(chart_id, email);
create index if not exists projects_chart_position_idx on public.projects(chart_id, position);
create index if not exists tasks_chart_dates_idx on public.tasks(chart_id, start_date, end_date);

create or replace function private.is_chart_owner(target_chart uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists(
    select 1
    from public.charts
    where id = target_chart
      and owner_id = (select auth.uid())
  )
$$;

create or replace function private.is_chart_shared_with_current_user(target_chart uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists(
    select 1
    from public.chart_access
    where chart_id = target_chart
      and email = private.current_user_email()
  )
$$;

create or replace function private.can_view_chart(target_chart uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select private.is_chart_owner(target_chart)
      or private.is_chart_shared_with_current_user(target_chart)
$$;

create or replace function private.can_edit_chart(target_chart uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select private.is_chart_owner(target_chart)
      or exists(
        select 1
        from public.chart_access
        where chart_id = target_chart
          and email = private.current_user_email()
          and role = 'editor'
      )
$$;

drop trigger if exists charts_set_updated_at on public.charts;
create trigger charts_set_updated_at
before update on public.charts
for each row
execute function public.set_updated_at();

drop trigger if exists projects_set_updated_at on public.projects;
create trigger projects_set_updated_at
before update on public.projects
for each row
execute function public.set_updated_at();

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at
before update on public.tasks
for each row
execute function public.set_updated_at();

drop trigger if exists projects_touch_chart_after_change on public.projects;
create trigger projects_touch_chart_after_change
after insert or update or delete on public.projects
for each row
execute function public.touch_parent_chart();

drop trigger if exists tasks_touch_chart_after_change on public.tasks;
create trigger tasks_touch_chart_after_change
after insert or update or delete on public.tasks
for each row
execute function public.touch_parent_chart();

drop trigger if exists chart_access_touch_chart_after_change on public.chart_access;
create trigger chart_access_touch_chart_after_change
after insert or update or delete on public.chart_access
for each row
execute function public.touch_parent_chart();

alter table public.charts enable row level security;
alter table public.chart_access enable row level security;
alter table public.projects enable row level security;
alter table public.tasks enable row level security;

drop policy if exists "charts_select_visible" on public.charts;
create policy "charts_select_visible"
on public.charts
for select
to authenticated
using (private.can_view_chart(id));

drop policy if exists "charts_insert_owner" on public.charts;
create policy "charts_insert_owner"
on public.charts
for insert
to authenticated
with check (owner_id = (select auth.uid()));

drop policy if exists "charts_update_owner" on public.charts;
create policy "charts_update_owner"
on public.charts
for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

drop policy if exists "charts_delete_owner" on public.charts;
create policy "charts_delete_owner"
on public.charts
for delete
to authenticated
using (owner_id = (select auth.uid()));

drop policy if exists "chart_access_select_owner_or_self" on public.chart_access;
create policy "chart_access_select_owner_or_self"
on public.chart_access
for select
to authenticated
using (
  private.is_chart_owner(chart_id)
  or email = private.current_user_email()
);

drop policy if exists "chart_access_insert_owner" on public.chart_access;
create policy "chart_access_insert_owner"
on public.chart_access
for insert
to authenticated
with check (
  private.is_chart_owner(chart_id)
  and created_by = (select auth.uid())
);

drop policy if exists "chart_access_update_owner" on public.chart_access;
create policy "chart_access_update_owner"
on public.chart_access
for update
to authenticated
using (private.is_chart_owner(chart_id))
with check (private.is_chart_owner(chart_id));

drop policy if exists "chart_access_delete_owner" on public.chart_access;
create policy "chart_access_delete_owner"
on public.chart_access
for delete
to authenticated
using (private.is_chart_owner(chart_id));

drop policy if exists "projects_select_visible" on public.projects;
create policy "projects_select_visible"
on public.projects
for select
to authenticated
using (private.can_view_chart(chart_id));

drop policy if exists "projects_insert_editors" on public.projects;
create policy "projects_insert_editors"
on public.projects
for insert
to authenticated
with check (private.can_edit_chart(chart_id));

drop policy if exists "projects_update_editors" on public.projects;
create policy "projects_update_editors"
on public.projects
for update
to authenticated
using (private.can_edit_chart(chart_id))
with check (private.can_edit_chart(chart_id));

drop policy if exists "projects_delete_editors" on public.projects;
create policy "projects_delete_editors"
on public.projects
for delete
to authenticated
using (private.can_edit_chart(chart_id));

drop policy if exists "tasks_select_visible" on public.tasks;
create policy "tasks_select_visible"
on public.tasks
for select
to authenticated
using (private.can_view_chart(chart_id));

drop policy if exists "tasks_insert_editors" on public.tasks;
create policy "tasks_insert_editors"
on public.tasks
for insert
to authenticated
with check (private.can_edit_chart(chart_id));

drop policy if exists "tasks_update_editors" on public.tasks;
create policy "tasks_update_editors"
on public.tasks
for update
to authenticated
using (private.can_edit_chart(chart_id))
with check (private.can_edit_chart(chart_id));

drop policy if exists "tasks_delete_editors" on public.tasks;
create policy "tasks_delete_editors"
on public.tasks
for delete
to authenticated
using (private.can_edit_chart(chart_id));
