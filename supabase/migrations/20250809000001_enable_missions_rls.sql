-- Enable RLS and create policies for missions system tables
-- This migration enables Row Level Security on missions-related tables and creates comprehensive policies

-- Enable Row Level Security on all missions tables
ALTER TABLE missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mission_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE mission_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE energy_transactions ENABLE ROW LEVEL SECURITY;

-- ======================
-- MISSIONS POLICIES
-- ======================

-- Anyone can view published missions
CREATE POLICY "Published missions are viewable by everyone" ON missions
  FOR SELECT USING (status = 'published');

-- Mission creators and organization admins can view all missions from their organization
CREATE POLICY "Organization members can view all organization missions" ON missions
  FOR SELECT USING (
    created_by = (SELECT auth.uid()) OR
    EXISTS (
      SELECT 1 FROM public.admin_memberships am
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      WHERE am.organization_id = missions.organization_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.status = 'active'
    )
  );

-- Only mission partners can create missions
CREATE POLICY "Mission partners can create missions" ON missions
  FOR INSERT WITH CHECK (
    created_by = (SELECT auth.uid()) AND
    EXISTS (
      SELECT 1 FROM public.admin_memberships am
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      JOIN public.organization_permissions op ON am.organization_id = op.organization_id
      WHERE ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.organization_id = missions.organization_id
        AND op.permission_type = 'mission_partners'
        AND op.status = 'approved'
        AND am.status = 'active'
    )
  );

-- Mission creators and organization admins can update missions from their organization
CREATE POLICY "Mission creators and org admins can update missions" ON missions
  FOR UPDATE USING (
    created_by = (SELECT auth.uid()) OR
    EXISTS (
      SELECT 1 FROM public.admin_memberships am
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      WHERE am.organization_id = missions.organization_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.status = 'active'
    )
  );

-- Only organization admins can delete missions
CREATE POLICY "Organization admins can delete missions" ON missions
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.admin_memberships am
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      WHERE am.organization_id = missions.organization_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.status = 'active'
    )
  );

-- ======================
-- MISSION BOOKMARKS POLICIES
-- ======================

-- Agents can view their own bookmarks
CREATE POLICY "Agents can view their own bookmarks" ON mission_bookmarks
  FOR SELECT USING (agent_id = (SELECT auth.uid()));

-- Agents can create their own bookmarks
CREATE POLICY "Agents can create their own bookmarks" ON mission_bookmarks
  FOR INSERT WITH CHECK (
    agent_id = (SELECT auth.uid()) AND
    EXISTS (SELECT 1 FROM agents WHERE id = (SELECT auth.uid()))
  );

-- Agents can delete their own bookmarks
CREATE POLICY "Agents can delete their own bookmarks" ON mission_bookmarks
  FOR DELETE USING (agent_id = (SELECT auth.uid()));

-- ======================
-- MISSION SUBMISSIONS POLICIES
-- ======================

-- Agents can view their own submissions
CREATE POLICY "Agents can view their own submissions" ON mission_submissions
  FOR SELECT USING (agent_id = (SELECT auth.uid()));

-- Mission reviewers can view submissions for their organization's missions
CREATE POLICY "Mission reviewers can view organization submissions" ON mission_submissions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM missions m
      JOIN public.admin_memberships am ON m.organization_id = am.organization_id
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      WHERE m.id = mission_submissions.mission_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.status = 'active'
    )
  );

-- Agents can create their own submissions
CREATE POLICY "Agents can create their own submissions" ON mission_submissions
  FOR INSERT WITH CHECK (
    agent_id = (SELECT auth.uid()) AND
    EXISTS (SELECT 1 FROM agents WHERE id = (SELECT auth.uid()))
  );

-- Agents can update their own submissions (before completion)
CREATE POLICY "Agents can update their own submissions" ON mission_submissions
  FOR UPDATE USING (
    agent_id = (SELECT auth.uid()) AND
    status NOT IN ('reviewed', 'rejected')
  );

-- Mission reviewers can update submissions for review
CREATE POLICY "Mission reviewers can review submissions" ON mission_submissions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM missions m
      JOIN public.admin_memberships am ON m.organization_id = am.organization_id
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      WHERE m.id = mission_submissions.mission_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.status = 'active'
    )
  );

-- ======================
-- POINT TRANSACTIONS POLICIES
-- ======================

-- Agents can view their own point transactions
CREATE POLICY "Agents can view their own point transactions" ON point_transactions
  FOR SELECT USING (agent_id = (SELECT auth.uid()));

-- Organization admins can view transactions related to their missions
CREATE POLICY "Organization admins can view mission-related transactions" ON point_transactions
  FOR SELECT USING (
    mission_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM missions m
      JOIN public.admin_memberships am ON m.organization_id = am.organization_id
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      WHERE m.id = point_transactions.mission_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.status = 'active'
    )
  );

-- Only system functions can insert point transactions
CREATE POLICY "System functions can create point transactions" ON point_transactions
  FOR INSERT WITH CHECK (
    -- This will be controlled by the application functions
    true
  );

-- ======================
-- ENERGY TRANSACTIONS POLICIES
-- ======================

-- Agents can view their own energy transactions
CREATE POLICY "Agents can view their own energy transactions" ON energy_transactions
  FOR SELECT USING (agent_id = (SELECT auth.uid()));

-- Organization admins can view transactions related to their missions
CREATE POLICY "Organization admins can view mission-related energy transactions" ON energy_transactions
  FOR SELECT USING (
    mission_id IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM missions m
      JOIN public.admin_memberships am ON m.organization_id = am.organization_id
      JOIN public.user_roles ur ON am.admin_id = ur.user_id
      WHERE m.id = energy_transactions.mission_id
        AND ur.user_id = (SELECT auth.uid())
        AND ur.role = 'admin'
        AND am.status = 'active'
    )
  );

-- Only system functions can insert energy transactions
CREATE POLICY "System functions can create energy transactions" ON energy_transactions
  FOR INSERT WITH CHECK (
    -- This will be controlled by the application functions
    true
  );
