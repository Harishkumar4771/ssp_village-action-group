-- ---------------------------------------------------------------------------
-- Admin: Create User (database RPC used by the Flutter app)
--
-- HOW TO APPLY:
--   1. Open your Supabase Dashboard → SQL Editor
--   2. Paste this whole file and click RUN
--   (No Supabase CLI or credentials required.)
--
-- This function is SECURITY DEFINER: it runs as the function owner (postgres)
-- so it can write to auth.users. It is exposed to the public REST endpoint
-- `rpc('admin_create_user')` but only permits active admins to run it.
-- ---------------------------------------------------------------------------

create or replace function public.admin_create_user(
  p_username text,
  p_password text,
  p_full_name text,
  p_role text,
  p_village_id uuid
)
returns json
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_caller_role text;
  v_caller_active boolean;
  v_username text;
  v_email text;
  v_user_id uuid;
begin
  -- Only an active admin can create users.
  select role, active
    into v_caller_role, v_caller_active
    from public.profiles
   where id = auth.uid();

  if v_caller_role is distinct from 'admin' or coalesce(v_caller_active, false) = false then
    raise exception 'Administrator access is required';
  end if;

  -- Normalize then validate inputs (mirrors the existing Flutter form rules).
  v_username := lower(trim(coalesce(p_username, '')));
  if v_username !~ '^[a-z0-9._-]{3,32}$' then
    raise exception 'Username must be 3-32 letters, numbers, dots, underscores, or hyphens';
  end if;
  if coalesce(p_password, '') = '' or length(p_password) < 12 then
    raise exception 'Password must be at least 12 characters';
  end if;
  if p_full_name is null or length(trim(p_full_name)) = 0 or length(p_full_name) > 120 then
    raise exception 'A valid full name is required';
  end if;
  if p_role is null or p_role not in ('leader', 'supervisor', 'admin') then
    raise exception 'Invalid role';
  end if;
  if p_village_id is null then
    raise exception 'An assigned village is required';
  end if;

  v_email := v_username || '@vagdmp.internal';

  -- Create the auth account (confirmed, no verification email).
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    v_email,
    crypt(p_password, gen_salt('bf')),
    now(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    jsonb_build_object('username', v_username, 'full_name', trim(p_full_name)),
    now(),
    now()
  )
  returning id into v_user_id;

  -- Create the profile row (used by the app for role/village/active).
  -- Upsert handles projects that already create an empty profile via a
  -- "handle_new_user" auth trigger.
  insert into public.profiles (id, username, full_name, role, village_id, active)
  values (v_user_id, v_username, trim(p_full_name), p_role, p_village_id, true)
  on conflict (id) do update
    set username   = excluded.username,
        full_name  = excluded.full_name,
        role       = excluded.role,
        village_id = excluded.village_id,
        active     = true;

  return jsonb_build_object('id', v_user_id, 'username', v_username);
exception
  when others then
    -- Roll back the auth user if the profile insert failed.
    begin
      if v_user_id is not null then
        delete from auth.users where id = v_user_id;
      end if;
    exception when others then null; end;
    raise;
end;
$$;

-- Allow the authenticated role to call it (the function re-checks admin role).
grant execute on function public.admin_create_user(text, text, text, text, uuid) to authenticated;