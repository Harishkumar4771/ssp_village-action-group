-- Live issue notifications for active administrators and supervisors.
-- Apply with `supabase db push` before releasing this app update.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  issue_id uuid references public.issues(id) on delete cascade,
  event_type text not null check (event_type in ('issue_reported', 'issue_updated')),
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Support projects that already have the original, smaller notifications table.
alter table public.notifications
  add column if not exists issue_id uuid references public.issues(id) on delete cascade,
  add column if not exists event_type text;
update public.notifications
  set event_type = 'issue_reported'
  where event_type is null;
alter table public.notifications alter column event_type set not null;
alter table public.notifications drop constraint if exists notifications_event_type_check;
alter table public.notifications add constraint notifications_event_type_check
  check (event_type in ('issue_reported', 'issue_updated'));

create index if not exists notifications_user_created_at_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;
grant select, update on public.notifications to authenticated;

drop policy if exists "Users read their own notifications" on public.notifications;
create policy "Users read their own notifications"
  on public.notifications for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users mark their own notifications read" on public.notifications;
create policy "Users mark their own notifications read"
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.notify_admins_of_new_issue()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, issue_id, event_type, title, message)
  select profile.id, new.id, 'issue_reported', 'New issue reported',
    format('A new issue was reported: %s', new.title)
  from public.profiles profile
  where profile.role in ('admin', 'supervisor') and profile.active = true;
  return new;
end;
$$;

drop trigger if exists issues_notify_on_insert on public.issues;
create trigger issues_notify_on_insert after insert on public.issues
  for each row execute function public.notify_admins_of_new_issue();

create or replace function public.notify_admins_of_progress_update()
returns trigger language plpgsql security definer set search_path = public as $$
declare issue_title text;
begin
  select title into issue_title from public.issues where id = new.issue_id;
  insert into public.notifications (user_id, issue_id, event_type, title, message)
  select profile.id, new.issue_id, 'issue_updated', 'Issue progress updated',
    format('%s is now %s%% complete.', coalesce(issue_title, 'An issue'), new.progress_percentage)
  from public.profiles profile
  where profile.role in ('admin', 'supervisor') and profile.active = true;
  return new;
end;
$$;

drop trigger if exists progress_updates_notify_on_insert on public.progress_updates;
create trigger progress_updates_notify_on_insert after insert on public.progress_updates
  for each row execute function public.notify_admins_of_progress_update();

-- Required for the existing Flutter Realtime subscription.
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end;
$$;

-- Required for automatic issue-list and dashboard refreshes in Flutter.
do $$
begin
  alter publication supabase_realtime add table public.issues;
exception when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.progress_updates;
exception when duplicate_object then null;
end;
$$;
