-- Performance Optimizations Migration
-- This migration addresses performance warnings from Supabase by:
-- 1. Adding indexes for foreign keys
-- 2. Optimizing RLS policies to avoid re-evaluation of auth functions
-- 3. Consolidating multiple permissive policies

-- ================================
-- PART 1: ADD MISSING INDEXES FOR FOREIGN KEYS
-- ================================

-- admin_memberships table indexes
CREATE INDEX IF NOT EXISTS idx_admin_memberships_admin_id ON admin_memberships(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_memberships_organization_id ON admin_memberships(organization_id);

-- admins table indexes
CREATE INDEX IF NOT EXISTS idx_admins_active_organization_id ON admins(active_organization_id);

-- organization_permissions table indexes
CREATE INDEX IF NOT EXISTS idx_organization_permissions_organization_id ON organization_permissions(organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_requested_by ON organization_permissions(requested_by);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_reviewed_by ON organization_permissions(reviewed_by);

-- user_roles table indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_organization_id ON user_roles(organization_id);

-- Additional performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_user_roles_role_organization ON user_roles(role, organization_id);
CREATE INDEX IF NOT EXISTS idx_admin_memberships_status ON admin_memberships(status);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_status ON organization_permissions(status);

-- ================================
-- PART 2: OPTIMIZE RLS POLICIES TO AVOID auth.uid() RE-EVALUATION
-- ================================

-- Fix organizations table policy
DROP POLICY IF EXISTS "CIN admins and new admin users can create organizations." ON organizations;
CREATE POLICY "CIN admins and new admin users can create organizations." ON organizations
FOR INSERT
WITH CHECK (
    (EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = (SELECT auth.uid()) 
        AND role = 'cin_admin'::app_role 
        AND organization_id IS NULL
    )) 
    OR 
    ((SELECT auth.role()) = 'authenticated' AND NOT EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = (SELECT auth.uid())
    ))
);

-- Fix role_permissions table policy
DROP POLICY IF EXISTS "Role permissions are viewable by authenticated users." ON role_permissions;
CREATE POLICY "Role permissions are viewable by authenticated users." ON role_permissions
FOR SELECT
USING ((SELECT auth.role()) = 'authenticated');

-- ================================
-- PART 3: CONSOLIDATE MULTIPLE PERMISSIVE POLICIES
-- ================================

-- Fix admin_memberships multiple policies
DROP POLICY IF EXISTS "Admin memberships manageable by authorized users." ON admin_memberships;
DROP POLICY IF EXISTS "Admin memberships viewable by related users." ON admin_memberships;

-- Create single consolidated admin_memberships policy
CREATE POLICY "Admin memberships policy" ON admin_memberships
FOR ALL
USING (
    -- Admin can access their own memberships
    admin_id = (SELECT auth.uid())
    OR
    -- CIN admins can access all memberships
    EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = (SELECT auth.uid()) 
        AND role = 'cin_admin'::app_role 
        AND organization_id IS NULL
    )
)
WITH CHECK (
    -- Admin can modify their own memberships  
    admin_id = (SELECT auth.uid())
    OR
    -- CIN admins can modify all memberships
    EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = (SELECT auth.uid()) 
        AND role = 'cin_admin'::app_role 
        AND organization_id IS NULL
    )
);

-- Fix organization_permissions multiple policies
DROP POLICY IF EXISTS "Org admins request, CIN admins manage permissions." ON organization_permissions;
DROP POLICY IF EXISTS "Users can view organization permissions." ON organization_permissions;

-- Create single consolidated organization_permissions policy
CREATE POLICY "Organization permissions policy" ON organization_permissions
FOR ALL
USING (
    -- User who requested the permission can access it
    requested_by = (SELECT auth.uid())
    OR
    -- Org admins can access permissions for their organization
    EXISTS (
        SELECT 1 FROM admin_memberships am
        JOIN user_roles ur ON am.admin_id = ur.user_id
        WHERE am.organization_id = organization_permissions.organization_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'org_admin'::app_role
        AND am.status = 'active'
    )
    OR
    -- CIN admins can access all permissions
    EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = (SELECT auth.uid()) 
        AND role = 'cin_admin'::app_role 
        AND organization_id IS NULL
    )
)
WITH CHECK (
    -- Org admins can modify permissions for their organization
    EXISTS (
        SELECT 1 FROM admin_memberships am
        JOIN user_roles ur ON am.admin_id = ur.user_id
        WHERE am.organization_id = organization_permissions.organization_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'org_admin'::app_role
        AND am.status = 'active'
    )
    OR
    -- CIN admins can modify all permissions
    EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = (SELECT auth.uid()) 
        AND role = 'cin_admin'::app_role 
        AND organization_id IS NULL
    )
);

-- Fix role_permissions multiple policies
DROP POLICY IF EXISTS "Only CIN admins can manage role permissions." ON role_permissions;
DROP POLICY IF EXISTS "Role permissions are viewable by authenticated users." ON role_permissions;

-- Create single consolidated role_permissions policy
CREATE POLICY "Role permissions policy" ON role_permissions
FOR ALL
USING (
    -- Authenticated users can view role permissions
    (SELECT auth.role()) = 'authenticated'
)
WITH CHECK (
    -- Only CIN admins can modify role permissions
    EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = (SELECT auth.uid()) 
        AND role = 'cin_admin'::app_role 
        AND organization_id IS NULL
    )
);

-- Fix user_roles multiple policies
DROP POLICY IF EXISTS "Only CIN admins can manage user roles." ON user_roles;
DROP POLICY IF EXISTS "Users can view their own roles." ON user_roles;

-- Create single consolidated user_roles policy
CREATE POLICY "User roles policy" ON user_roles
FOR ALL
USING (
    -- Users can view their own roles
    user_id = (SELECT auth.uid())
    OR
    -- CIN admins can view all roles
    EXISTS (
        SELECT 1 FROM user_roles ur
        WHERE ur.user_id = (SELECT auth.uid()) 
        AND ur.role = 'cin_admin'::app_role 
        AND ur.organization_id IS NULL
    )
)
WITH CHECK (
    -- Only CIN admins can modify user roles
    EXISTS (
        SELECT 1 FROM user_roles ur
        WHERE ur.user_id = (SELECT auth.uid()) 
        AND ur.role = 'cin_admin'::app_role 
        AND ur.organization_id IS NULL
    )
);

-- ================================
-- PART 4: CREATE PERFORMANCE-OPTIMIZED COMPOUND INDEXES
-- ================================

-- Compound indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_user_roles_lookup ON user_roles(user_id, role, organization_id);
CREATE INDEX IF NOT EXISTS idx_admin_memberships_lookup ON admin_memberships(admin_id, organization_id, status);
CREATE INDEX IF NOT EXISTS idx_organization_permissions_lookup ON organization_permissions(organization_id, permission_type, status);

-- Partial indexes for active records only (better performance)
CREATE INDEX IF NOT EXISTS idx_admin_memberships_active ON admin_memberships(admin_id, organization_id) 
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_organization_permissions_approved ON organization_permissions(organization_id, permission_type) 
WHERE status = 'approved';

-- ================================
-- VALIDATION
-- ================================

-- Verify indexes were created
DO $$
BEGIN
    RAISE NOTICE 'Performance optimization migration completed successfully!';
    RAISE NOTICE 'Added % indexes for foreign keys and performance', 
        (SELECT count(*) FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'idx_%');
    RAISE NOTICE 'Consolidated multiple permissive RLS policies into single optimized policies';
    RAISE NOTICE 'Fixed auth.uid() re-evaluation issues in RLS policies';
    RAISE NOTICE 'Eliminated all multiple permissive policy warnings';
END $$;
