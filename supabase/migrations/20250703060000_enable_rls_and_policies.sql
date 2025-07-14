-- Enable RLS and create all security policies
-- This migration enables Row Level Security on all tables and creates comprehensive policies
-- All dependencies (tables, roles, functions) are now available from previous migrations

-- Enable Row Level Security on all tables
alter table organizations enable row level security;
alter table players enable row level security;
alter table admins enable row level security;
alter table admin_memberships enable row level security;
alter table role_permissions enable row level security;
alter table user_roles enable row level security;
alter table organization_permissions enable row level security;

-- ======================
-- ORGANIZATIONS POLICIES
-- ======================

create policy "Organizations are viewable by everyone." on organizations
  for select using (true);

create policy "CIN admins and new admin users can create organizations." on organizations
  for insert with check (
    -- CIN admins can always create organizations
    exists (
      select 1 from public.user_roles 
      where user_id = (select auth.uid()) 
      and role = 'cin_admin'
      and organization_id is null
    ) or
    -- New admin users can create organizations during signup (no user_roles entry yet)
    (auth.role() = 'authenticated' and not exists (
      select 1 from public.user_roles where user_id = (select auth.uid())
    ))
  );

create policy "Org admins and CIN admins can update organizations." on organizations
  for update using (exists (
    select 1 from public.admin_memberships am
    join public.user_roles ur on am.admin_id = ur.user_id
    where am.organization_id = organizations.id
    and ur.user_id = (select auth.uid())
    and ur.role = 'org_admin'
    and ur.organization_id = organizations.id
  ) or exists (
    select 1 from public.user_roles 
    where user_id = (select auth.uid()) 
    and role = 'cin_admin'
    and organization_id is null
  ));

-- ===================
-- PLAYERS POLICIES
-- ===================

create policy "Player profiles are viewable by everyone." on players
  for select using (true);

create policy "Players can insert their own profile." on players
  for insert with check ((select auth.uid()) = id);

create policy "Players can update own profile." on players
  for update using ((select auth.uid()) = id);

-- =================
-- ADMINS POLICIES
-- =================

create policy "Admin profiles are viewable by everyone." on admins
  for select using (true);

create policy "Admins can insert their own profile." on admins
  for insert with check ((select auth.uid()) = id);

create policy "Admins can update own profile." on admins
  for update using ((select auth.uid()) = id);

-- ===========================
-- ADMIN MEMBERSHIPS POLICIES
-- ===========================

create policy "Admin memberships viewable by related users." on admin_memberships
  for select using (
    admin_id = (select auth.uid()) or
    exists (
      select 1 from public.user_roles 
      where user_id = (select auth.uid()) 
      and role = 'cin_admin'
      and organization_id is null
    )
  );

create policy "Admin memberships manageable by authorized users." on admin_memberships
  for all using (
    admin_id = (select auth.uid()) or
    exists (
      select 1 from public.user_roles 
      where user_id = (select auth.uid()) 
      and role = 'cin_admin'
      and organization_id is null
    )
  );

-- ===========================
-- ROLE PERMISSIONS POLICIES
-- ===========================

create policy "Role permissions are viewable by authenticated users." on role_permissions
  for select using (auth.role() = 'authenticated');

create policy "Only CIN admins can manage role permissions." on role_permissions
  for all using (exists (
    select 1 from public.user_roles ur
    where ur.user_id = (select auth.uid())
    and ur.role = 'cin_admin'
    and ur.organization_id is null
  ));

-- ===================
-- USER ROLES POLICIES
-- ===================

create policy "Users can view their own roles." on user_roles
  for select using (user_id = (select auth.uid()));

create policy "Only CIN admins can manage user roles." on user_roles
  for all using (exists (
    select 1 from public.user_roles ur
    where ur.user_id = (select auth.uid())
    and ur.role = 'cin_admin'
    and ur.organization_id is null
  ));

-- ====================================
-- ORGANIZATION PERMISSIONS POLICIES
-- ====================================

create policy "Users can view organization permissions." on organization_permissions
  for select using (
    -- Requesters can see their own requests
    requested_by = (select auth.uid()) or
    -- Org admins can see permissions for their organizations
    exists (
      select 1 from public.admin_memberships am
      join public.user_roles ur on am.admin_id = ur.user_id
      where am.organization_id = organization_permissions.organization_id
        and ur.user_id = (select auth.uid())
        and ur.role = 'org_admin'
        and am.status = 'active'
    ) or
    -- CIN admins can see all
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
      and ur.role = 'cin_admin'
      and ur.organization_id is null
    )
  );

create policy "Org admins request, CIN admins manage permissions." on organization_permissions
  for all using (
    -- Org admins can manage permissions for their organizations
    exists (
      select 1 from public.admin_memberships am
      join public.user_roles ur on am.admin_id = ur.user_id
      where am.organization_id = organization_permissions.organization_id
        and ur.user_id = (select auth.uid())
        and ur.role = 'org_admin'
        and am.status = 'active'
    ) or
    -- CIN admins can manage all permissions
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
      and ur.role = 'cin_admin'
      and ur.organization_id is null
    )
  );
