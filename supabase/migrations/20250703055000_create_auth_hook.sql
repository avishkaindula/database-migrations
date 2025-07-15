-- Create the auth hook function
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
  declare
    claims jsonb;
    user_roles_array jsonb := '[]'::jsonb;
    user_organizations_array jsonb := '[]'::jsonb;
    active_org_id uuid;
    role_record record;
    org_record record;
  begin
    claims := event->'claims';

    -- Fetch all user roles with organization context
    for role_record in 
      select 
        ur.role,
        ur.organization_id,
        o.name as organization_name
      from public.user_roles ur
      left join public.organizations o on ur.organization_id = o.id
      where ur.user_id = (event->>'user_id')::uuid
    loop
      if role_record.organization_id is null then
        -- Global role (like player roles)
        user_roles_array := user_roles_array || jsonb_build_object(
          'role', role_record.role,
          'scope', 'global'
        );
      else
        -- Organization-scoped role
        user_roles_array := user_roles_array || jsonb_build_object(
          'role', role_record.role,
          'scope', 'organization',
          'organization_id', role_record.organization_id,
          'organization_name', role_record.organization_name
        );
      end if;
    end loop;

    -- Fetch user organizations with membership status and capabilities
    for org_record in 
      select 
        o.id, 
        o.name,
        am.status as membership_status,
        array_agg(
          jsonb_build_object(
            'type', op.permission_type,
            'status', op.status
          )
        ) filter (where op.permission_type is not null) as capabilities
      from public.admin_memberships am
      join public.organizations o on am.organization_id = o.id
      left join public.organization_permissions op on op.organization_id = o.id
      where am.admin_id = (event->>'user_id')::uuid
        and am.status = 'active'
      group by o.id, o.name, am.status
    loop
      user_organizations_array := user_organizations_array || jsonb_build_object(
        'id', org_record.id,
        'name', org_record.name,
        'membership_status', org_record.membership_status,
        'capabilities', case 
          when org_record.capabilities is null then '[]'::jsonb
          else to_jsonb(org_record.capabilities)
        end
      );
    end loop;

    -- Get active organization
    select active_organization_id into active_org_id
    from public.admins 
    where id = (event->>'user_id')::uuid;

    -- Set the claims
    claims := jsonb_set(claims, '{user_roles}', user_roles_array);
    claims := jsonb_set(claims, '{user_organizations}', user_organizations_array);
    
    if active_org_id is not null then
      claims := jsonb_set(claims, '{active_organization_id}', to_jsonb(active_org_id));
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
  on table public.admin_memberships
to supabase_auth_admin;

grant all
  on table public.organizations
to supabase_auth_admin;

grant all
  on table public.organization_permissions
to supabase_auth_admin;

grant all
  on table public.admins
to supabase_auth_admin;

revoke all
  on table public.user_roles
  from authenticated, anon, public;

revoke all
  on table public.admin_memberships
  from authenticated, anon, public;

revoke all
  on table public.organizations
  from authenticated, anon, public;

revoke all
  on table public.organization_permissions
  from authenticated, anon, public;

revoke all
  on table public.admins
  from authenticated, anon, public;

create policy "Allow auth admin to read user roles" ON public.user_roles
as permissive for select
to supabase_auth_admin
using (true);

create policy "Allow auth admin to read admin memberships" ON public.admin_memberships
as permissive for select
to supabase_auth_admin
using (true);

create policy "Allow auth admin to read organizations" ON public.organizations
as permissive for select
to supabase_auth_admin
using (true);

create policy "Allow auth admin to read organization permissions" ON public.organization_permissions
as permissive for select
to supabase_auth_admin
using (true);

create policy "Allow auth admin to read admins" ON public.admins
as permissive for select
to supabase_auth_admin
using (true);
