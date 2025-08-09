-- Enable RLS and create all security policies
-- This migration enables Row Level Security on all tables and creates comprehensive policies
-- All dependencies (tables, roles, functions) are now available from previous migrations
-- Policies are performance-optimized to avoid multiple permissive policies and auth function re-evaluation

-- Enable Row Level Security on all tables
alter table organizations enable row level security;
-- Enable RLS
alter table agents enable row level security;
alter table admins enable row level security;
alter table admin_memberships enable row level security;
alter table user_roles enable row level security;
alter table organization_permissions enable row level security;

-- Add performance indexes for foreign keys
CREATE INDEX IF NOT EXISTS idx_admin_memberships_admin_id ON admin_memberships(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_memberships_organization_id ON admin_memberships(organization_id);
CREATE INDEX IF NOT EXISTS idx_admins_active_organization_id ON admins(active_organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_organization_id ON organization_permissions(organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_requested_by ON organization_permissions(requested_by);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_reviewed_by ON organization_permissions(reviewed_by);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_organization_id ON user_roles(organization_id);

-- Additional performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_user_roles_role_organization ON user_roles(role, organization_id);
CREATE INDEX IF NOT EXISTS idx_admin_memberships_status ON admin_memberships(status);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_status ON organization_permissions(status);

-- Compound indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_user_roles_lookup ON user_roles(user_id, role, organization_id);
CREATE INDEX IF NOT EXISTS idx_admin_memberships_lookup ON admin_memberships(admin_id, organization_id, status);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_lookup ON organization_permissions(organization_id, permission_type, status);

-- Partial indexes for active records only (better performance)
CREATE INDEX IF NOT EXISTS idx_admin_memberships_active ON admin_memberships(admin_id, organization_id) 
WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_organization_permissions_approved ON organization_permissions(organization_id, permission_type) 
WHERE status = 'approved';

-- ======================
-- ORGANIZATIONS POLICIES
-- ======================

create policy "Organizations are viewable by everyone." on organizations
  for select using (true);

create policy "CIN admins and new admin users can create organizations." on organizations
  for insert with check (
    -- CIN administrators can always create organizations (privilege-based check)
    exists (
      select 1 from public.user_roles ur
      join public.admin_memberships am on ur.user_id = am.admin_id
      join public.organization_permissions op on am.organization_id = op.organization_id
      where ur.user_id = (select auth.uid()) 
      and ur.role = 'admin'
      and op.permission_type = 'cin_administrators'
      and op.status = 'approved'
    ) or
    -- New admin users can create organizations during signup (no user_roles entry yet)
    ((select auth.role()) = 'authenticated' and not exists (
      select 1 from public.user_roles where user_id = (select auth.uid())
    ))
  );

create policy "Org admins and CIN administrators can update organizations." on organizations
  for update using (exists (
    select 1 from public.admin_memberships am
    join public.user_roles ur on am.admin_id = ur.user_id
    where am.organization_id = organizations.id
    and ur.user_id = (select auth.uid())
    and ur.role = 'admin'
  ) or exists (
    -- CIN administrators can update any organization
    select 1 from public.user_roles ur
    join public.admin_memberships am on ur.user_id = am.admin_id
    join public.organization_permissions op on am.organization_id = op.organization_id
    where ur.user_id = (select auth.uid()) 
    and ur.role = 'admin'
    and op.permission_type = 'cin_administrators'
    and op.status = 'approved'
  ));

-- ===================
-- AGENTS POLICIES
-- ===================

create policy "Agent profiles are viewable by everyone." on agents
  for select using (true);

create policy "Agents can insert their own profile." on agents
  for insert with check ((select auth.uid()) = id);

create policy "Agents can update own profile." on agents
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

-- Single consolidated policy for admin memberships (eliminates multiple permissive policies)
create policy "Admin memberships policy" on admin_memberships
  for all using (
    -- Admin can access their own memberships
    admin_id = (select auth.uid()) or
    -- CIN admins can access all memberships
    exists (
      select 1 from public.user_roles 
      where user_id = (select auth.uid()) 
      and role = 'admin'
      and organization_id is null
    )
  ) with check (
    -- Admin can modify their own memberships  
    admin_id = (select auth.uid()) or
    -- CIN admins can modify all memberships
    exists (
      select 1 from public.user_roles 
      where user_id = (select auth.uid()) 
      and role = 'admin'
      and organization_id is null
    )
  );

-- ===================
-- USER ROLES POLICIES  
-- ===================

-- Simple JWT-based policies without database lookups
create policy "Users can view own roles" on user_roles
  for select using (user_id = auth.uid());

create policy "Authenticated users can insert roles" on user_roles
  for insert with check (auth.role() = 'authenticated');

create policy "Users can update own roles" on user_roles
  for update using (user_id = auth.uid());

create policy "Users can delete own roles" on user_roles
  for delete using (user_id = auth.uid());

-- ===========================
-- ADMIN MEMBERSHIPS POLICIES
-- ===========================

-- Simple JWT-based policies without database lookups
create policy "Admins can view own memberships" on admin_memberships
  for select using (admin_id = auth.uid());

create policy "Authenticated users can insert memberships" on admin_memberships
  for insert with check (auth.role() = 'authenticated');

create policy "Admins can update own memberships" on admin_memberships
  for update using (admin_id = auth.uid());

create policy "Admins can delete own memberships" on admin_memberships
  for delete using (admin_id = auth.uid());

-- ====================================
-- ORGANIZATION PERMISSIONS POLICIES
-- ====================================

-- Simple JWT-based policies without database lookups
create policy "Users can view org permissions they requested" on organization_permissions
  for select using (requested_by = auth.uid());

create policy "Anyone can view approved org permissions" on organization_permissions
  for select using (status = 'approved');

create policy "Authenticated users can insert org permissions" on organization_permissions
  for insert with check (auth.role() = 'authenticated');

create policy "Users can update org permissions they requested" on organization_permissions
  for update using (requested_by = auth.uid());
