-- Rename players table to agents
-- This migration renames the players table to agents to better reflect the new role system

-- Rename the table
ALTER TABLE players RENAME TO agents;

-- Update any indexes, constraints, or policies that reference the old table name
-- (Note: Most constraints and policies will automatically follow the table rename,
-- but we should check if any need manual updates)

-- Add a comment to the renamed table
COMMENT ON TABLE agents IS 'Agent profiles for users who participate in climate action missions and activities.';
