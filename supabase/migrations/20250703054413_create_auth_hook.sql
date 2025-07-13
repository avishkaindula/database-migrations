-- Create the auth hook function
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
  declare
    claims jsonb;
    user_roles_array jsonb := '[]'::jsonb;
    user_organizations_array jsonb := '[]'::jsonb;
    role_record record;
    org_record record;
  begin
    claims := event->'claims';

    -- Fetch all user roles and build array
    for role_record in 
      select role from public.user_roles where user_id = (event->>'user_id')::uuid
    loop
      user_roles_array := user_roles_array || to_jsonb(role_record.role);
    end loop;

    -- Fetch user organizations (if user is an admin)
    for org_record in 
      select o.id, o.name 
      from public.admin_orgs ao
      join public.organizations o on ao.organization_id = o.id
      where ao.admin_id = (event->>'user_id')::uuid
    loop
      user_organizations_array := user_organizations_array || jsonb_build_object(
        'id', org_record.id,
        'name', org_record.name
      );
    end loop;

    -- Set the claims
    if jsonb_array_length(user_roles_array) > 0 then
      claims := jsonb_set(claims, '{user_roles}', user_roles_array);
    else
      claims := jsonb_set(claims, '{user_roles}', '[]'::jsonb);
    end if;

    -- Set organization claims
    if jsonb_array_length(user_organizations_array) > 0 then
      claims := jsonb_set(claims, '{user_organizations}', user_organizations_array);
    else
      claims := jsonb_set(claims, '{user_organizations}', '[]'::jsonb);
    end if;

    -- Update the 'claims' object in the original event
    event := jsonb_set(event, '{claims}', claims);

    -- Return the modified event
    return event;
  end;
$$;

grant usage on schema public to supabase_auth_admin;

grant execute
  on function public.custom_access_token_hook
  to supabase_auth_admin;

revoke execute
  on function public.custom_access_token_hook
  from authenticated, anon, public;

grant all
  on table public.user_roles
to supabase_auth_admin;

grant all
  on table public.admin_orgs
to supabase_auth_admin;

grant all
  on table public.organizations
to supabase_auth_admin;

revoke all
  on table public.user_roles
  from authenticated, anon, public;

revoke all
  on table public.admin_orgs
  from authenticated, anon, public;

revoke all
  on table public.organizations
  from authenticated, anon, public;

create policy "Allow auth admin to read user roles" ON public.user_roles
as permissive for select
to supabase_auth_admin
using (true);

create policy "Allow auth admin to read admin orgs" ON public.admin_orgs
as permissive for select
to supabase_auth_admin
using (true);

create policy "Allow auth admin to read organizations" ON public.organizations
as permissive for select
to supabase_auth_admin
using (true);