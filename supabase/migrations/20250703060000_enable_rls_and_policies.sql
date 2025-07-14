-- Enable RLS and create all security policies
-- This migration enables Row Level Security on all tables and creates comprehensive policies
-- All dependencies (tables, roles, functions) are now available from previous migrations
-- Policies are performance-optimized to avoid multiple permissive policies and auth function re-evaluation

-- Enable Row Level Security on all tables
alter table organizations enable row level security;
alter table players enable row level security;
alter table admins enable row level security;
alter table admin_memberships enable row level security;
alter table role_permissions enable row level security;
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
    -- CIN admins can always create organizations (optimized auth function caching)
    exists (
      select 1 from public.user_roles 
      where user_id = (select auth.uid()) 
      and role = 'cin_admin'
      and organization_id is null
    ) or
    -- New admin users can create organizations during signup (no user_roles entry yet)
    ((select auth.role()) = 'authenticated' and not exists (
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

-- Single consolidated policy for admin memberships (eliminates multiple permissive policies)
create policy "Admin memberships policy" on admin_memberships
  for all using (
    -- Admin can access their own memberships
    admin_id = (select auth.uid()) or
    -- CIN admins can access all memberships
    exists (
      select 1 from public.user_roles 
      where user_id = (select auth.uid()) 
      and role = 'cin_admin'
      and organization_id is null
    )
  ) with check (
    -- Admin can modify their own memberships  
    admin_id = (select auth.uid()) or
    -- CIN admins can modify all memberships
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

-- Single consolidated policy for role permissions (eliminates multiple permissive policies)
create policy "Role permissions policy" on role_permissions
  for all using (
    -- Authenticated users can view role permissions (optimized auth function caching)
    (select auth.role()) = 'authenticated'
  ) with check (
    -- Only CIN admins can modify role permissions
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
      and ur.role = 'cin_admin'
      and ur.organization_id is null
    )
  );

-- ===================
-- USER ROLES POLICIES
-- ===================

-- Single consolidated policy for user roles (eliminates multiple permissive policies)
create policy "User roles policy" on user_roles
  for all using (
    -- Users can view their own roles
    user_id = (select auth.uid()) or
    -- CIN admins can view all roles
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
      and ur.role = 'cin_admin'
      and ur.organization_id is null
    )
  ) with check (
    -- Only CIN admins can modify user roles
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
      and ur.role = 'cin_admin'
      and ur.organization_id is null
    )
  );

-- ====================================
-- ORGANIZATION PERMISSIONS POLICIES
-- ====================================

-- Single consolidated policy for organization permissions (eliminates multiple permissive policies)
create policy "Organization permissions policy" on organization_permissions
  for all using (
    -- User who requested the permission can access it
    requested_by = (select auth.uid()) or
    -- Org admins can access permissions for their organization
    exists (
      select 1 from public.admin_memberships am
      join public.user_roles ur on am.admin_id = ur.user_id
      where am.organization_id = organization_permissions.organization_id
        and ur.user_id = (select auth.uid())
        and ur.role = 'org_admin'
        and am.status = 'active'
    ) or
    -- CIN admins can access all permissions
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
      and ur.role = 'cin_admin'
      and ur.organization_id is null
    )
  ) with check (
    -- Org admins can modify permissions for their organization
    exists (
      select 1 from public.admin_memberships am
      join public.user_roles ur on am.admin_id = ur.user_id
      where am.organization_id = organization_permissions.organization_id
        and ur.user_id = (select auth.uid())
        and ur.role = 'org_admin'
        and am.status = 'active'
    ) or
    -- CIN admins can modify all permissions
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = (select auth.uid())
      and ur.role = 'cin_admin'
      and ur.organization_id is null
    )
  );
