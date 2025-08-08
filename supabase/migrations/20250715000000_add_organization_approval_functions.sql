-- Helper functions for organization approval and management

-- Function to approve organization privileges (for CIN admins)
create or replace function public.approve_organization_privileges(
  target_organization_id uuid,
  privilege_types text[] default null  -- If null, approves all pending privileges
)
returns jsonb as $$
declare
  approved_count int := 0;
  reviewer_id uuid;
  result jsonb;
begin
  -- Verify caller is CIN admin
  reviewer_id := auth.uid();
  if not exists (
    select 1 from public.user_roles ur 
    join public.organization_permissions op on ur.organization_id = op.organization_id
    where ur.user_id = reviewer_id 
    and ur.role = 'admin' 
    and op.permission_type = 'cin_administrators'
    and op.status = 'approved'
  ) then
    raise exception 'Only CIN admins can approve organization privileges';
  end if;
  
  -- Approve specified privileges or all pending ones
  update public.organization_permissions
  set 
    status = 'approved',
    reviewed_by = reviewer_id,
    reviewed_at = now(),
    updated_at = now()
  where organization_id = target_organization_id
    and status = 'pending'
    and (privilege_types is null or permission_type = any(privilege_types));
  
  get diagnostics approved_count = row_count;
  
  -- Also activate the admin membership if approving any privileges
  if approved_count > 0 then
    update public.admin_memberships
    set 
      status = 'active',
      updated_at = now()
    where organization_id = target_organization_id
      and status = 'pending';
  end if;
  
  -- Return result
  result := jsonb_build_object(
    'success', true,
    'approved_privileges_count', approved_count,
    'organization_id', target_organization_id
  );
  
  return result;
end;
$$ language plpgsql security definer set search_path = '';

-- Function to reject organization privileges
create or replace function public.reject_organization_privileges(
  target_organization_id uuid,
  privilege_types text[] default null,  -- If null, rejects all pending privileges
  rejection_reason text default null
)
returns jsonb as $$
declare
  rejected_count int := 0;
  reviewer_id uuid;
  result jsonb;
begin
  -- Verify caller is CIN admin
  reviewer_id := auth.uid();
  if not exists (
    select 1 from public.user_roles ur 
    join public.organization_permissions op on ur.organization_id = op.organization_id
    where ur.user_id = reviewer_id 
    and ur.role = 'admin' 
    and op.permission_type = 'cin_administrators'
    and op.status = 'approved'
  ) then
    raise exception 'Only CIN admins can reject organization privileges';
  end if;
  
  -- Reject specified privileges or all pending ones
  update public.organization_permissions
  set 
    status = 'rejected',
    reviewed_by = reviewer_id,
    reviewed_at = now(),
    updated_at = now()
  where organization_id = target_organization_id
    and status = 'pending'
    and (privilege_types is null or permission_type = any(privilege_types));
  
  get diagnostics rejected_count = row_count;
  
  -- Return result
  result := jsonb_build_object(
    'success', true,
    'rejected_privileges_count', rejected_count,
    'organization_id', target_organization_id,
    'reason', rejection_reason
  );
  
  return result;
end;
$$ language plpgsql security definer set search_path = '';

-- Function to get pending organization approvals (for CIN admin dashboard)
create or replace function public.get_pending_organization_approvals()
returns table (
  organization_id uuid,
  organization_name text,
  contact_email text,
  admin_name text,
  admin_email text,
  requested_privileges jsonb,
  created_at timestamptz
) as $$
begin
  return query
  select 
    o.id as organization_id,
    o.name as organization_name,
    o.contact_email,
    a.full_name as admin_name,
    a.email as admin_email,
    jsonb_agg(
      jsonb_build_object(
        'privilege_type', op.permission_type,
        'requested_at', op.created_at
      )
    ) as requested_privileges,
    min(op.created_at) as created_at
  from public.organizations o
  join public.organization_permissions op on o.id = op.organization_id
  join public.admins a on op.requested_by = a.id
  where op.status = 'pending'
  group by o.id, o.name, o.contact_email, a.full_name, a.email
  order by created_at desc;
end;
$$ language plpgsql security definer set search_path = '';

-- Grant execute permissions to authenticated users (with RLS)
grant execute on function public.approve_organization_privileges to authenticated;
grant execute on function public.reject_organization_privileges to authenticated;
grant execute on function public.get_pending_organization_approvals to authenticated;
