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

-- Pure JWT-based policies using our helper functions
-- Anyone can view published missions
CREATE POLICY "Anyone can view published missions" ON missions
  FOR SELECT USING (status = 'published');

-- Authenticated users can view any mission
CREATE POLICY "Authenticated users can view missions" ON missions
  FOR SELECT USING (auth.role() = 'authenticated');

-- Only users with mission_partners privilege + admin role can create missions
CREATE POLICY "Mission partners can create missions" ON missions
  FOR INSERT WITH CHECK (can_create_missions());

-- Mission creators can update their own missions
CREATE POLICY "Mission creators can update their missions" ON missions
  FOR UPDATE USING (created_by = auth.uid());

-- Mission creators can delete their own missions OR CIN admins can delete any
CREATE POLICY "Mission creators and CIN admins can delete missions" ON missions
  FOR DELETE USING (created_by = auth.uid() OR is_cin_admin());

-- ======================
-- MISSION BOOKMARKS POLICIES
-- ======================

-- Agents can manage their own bookmarks
CREATE POLICY "Agents can view their own bookmarks" ON mission_bookmarks
  FOR SELECT USING (agent_id = auth.uid());

CREATE POLICY "Agents can create their own bookmarks" ON mission_bookmarks
  FOR INSERT WITH CHECK (agent_id = auth.uid());

CREATE POLICY "Agents can delete their own bookmarks" ON mission_bookmarks
  FOR DELETE USING (agent_id = auth.uid());

-- ======================
-- MISSION SUBMISSIONS POLICIES
-- ======================

-- Simple policies - authorization handled in application layer
CREATE POLICY "Agents can view their own submissions" ON mission_submissions
  FOR SELECT USING (agent_id = auth.uid());

CREATE POLICY "Authenticated users can view submissions" ON mission_submissions
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can create submissions" ON mission_submissions
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update their own submissions" ON mission_submissions
  FOR UPDATE USING (agent_id = auth.uid());

-- ======================
-- POINT TRANSACTIONS POLICIES
-- ======================

-- Simple policies - authorization handled in application layer
CREATE POLICY "Users can view their own point transactions" ON point_transactions
  FOR SELECT USING (agent_id = auth.uid());

CREATE POLICY "Authenticated users can view point transactions" ON point_transactions
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can create point transactions" ON point_transactions
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ======================
-- ENERGY TRANSACTIONS POLICIES
-- ======================

-- Simple policies - authorization handled in application layer
CREATE POLICY "Users can view their own energy transactions" ON energy_transactions
  FOR SELECT USING (agent_id = auth.uid());

CREATE POLICY "Authenticated users can view energy transactions" ON energy_transactions
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can create energy transactions" ON energy_transactions
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
