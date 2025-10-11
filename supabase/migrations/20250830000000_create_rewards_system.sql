-- Create rewards table
CREATE TABLE IF NOT EXISTS public.rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('digital-badge', 'discount-voucher', 'educational-access', 'certificate', 'physical-item', 'experience')),
    category TEXT NOT NULL CHECK (category IN ('achievement', 'environmental', 'education', 'recognition', 'discount')),
    value TEXT NOT NULL, -- e.g., "$50 savings", "Recognition", "$99 course"
    points_cost INTEGER NOT NULL CHECK (points_cost > 0),
    availability TEXT NOT NULL CHECK (availability IN ('unlimited', 'limited')),
    quantity_available INTEGER, -- NULL for unlimited, positive integer for limited
    quantity_claimed INTEGER DEFAULT 0,
    image_url TEXT,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('active', 'draft', 'paused', 'expired')),
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    expiry_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create reward_redemptions table
CREATE TABLE IF NOT EXISTS public.reward_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reward_id UUID NOT NULL REFERENCES public.rewards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'fulfilled')),
    points_spent INTEGER NOT NULL,
    redemption_notes TEXT, -- User's notes or additional info
    review_notes TEXT, -- Admin's review notes
    reviewed_by UUID REFERENCES auth.users(id),
    reviewed_at TIMESTAMPTZ,
    fulfilled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb,
    UNIQUE(reward_id, user_id, created_at) -- Prevent duplicate redemptions
);

-- Create indexes for better query performance
CREATE INDEX idx_rewards_status ON public.rewards(status);
CREATE INDEX idx_rewards_category ON public.rewards(category);
CREATE INDEX idx_rewards_type ON public.rewards(type);
CREATE INDEX idx_rewards_organization ON public.rewards(organization_id);
CREATE INDEX idx_rewards_created_by ON public.rewards(created_by);
CREATE INDEX idx_reward_redemptions_user ON public.reward_redemptions(user_id);
CREATE INDEX idx_reward_redemptions_reward ON public.reward_redemptions(reward_id);
CREATE INDEX idx_reward_redemptions_status ON public.reward_redemptions(status);

-- Enable RLS
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_redemptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for rewards table
-- Anyone authenticated can view active rewards
CREATE POLICY "Anyone can view active rewards"
    ON public.rewards
    FOR SELECT
    TO authenticated
    USING (status = 'active');

-- Authenticated users can create rewards (adjust based on your auth logic)
CREATE POLICY "Authenticated users can create rewards"
    ON public.rewards
    FOR INSERT
    TO authenticated
    WITH CHECK (created_by = auth.uid());

-- Users can update rewards they created
CREATE POLICY "Users can update their rewards"
    ON public.rewards
    FOR UPDATE
    TO authenticated
    USING (created_by = auth.uid());

-- Users can delete rewards they created
CREATE POLICY "Users can delete their rewards"
    ON public.rewards
    FOR DELETE
    TO authenticated
    USING (created_by = auth.uid());

-- RLS Policies for reward_redemptions table
-- Users can view their own redemptions
CREATE POLICY "Users can view their own redemptions"
    ON public.reward_redemptions
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Allow viewing redemptions for rewards you created
CREATE POLICY "Reward creators can view redemptions"
    ON public.reward_redemptions
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.rewards r
            WHERE r.id = reward_redemptions.reward_id
            AND r.created_by = auth.uid()
        )
    );

-- Users can create redemption requests
CREATE POLICY "Users can create redemption requests"
    ON public.reward_redemptions
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Reward creators can update redemption status
CREATE POLICY "Reward creators can update redemptions"
    ON public.reward_redemptions
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.rewards r
            WHERE r.id = reward_redemptions.reward_id
            AND r.created_by = auth.uid()
        )
    );

-- Function to check if user has enough points
CREATE OR REPLACE FUNCTION check_user_points_for_redemption(
    p_user_id UUID,
    p_points_cost INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_points INTEGER;
BEGIN
    -- Calculate user's current points from point_transactions
    -- Note: agents.id IS the user_id (references auth.users)
    SELECT COALESCE(SUM(points_amount), 0)
    INTO v_user_points
    FROM public.point_transactions
    WHERE agent_id = p_user_id
    AND transaction_type IN ('earned', 'bonus');
    
    -- Subtract points already spent on redemptions
    SELECT v_user_points - COALESCE(SUM(points_spent), 0)
    INTO v_user_points
    FROM public.reward_redemptions
    WHERE user_id = p_user_id
    AND status IN ('approved', 'fulfilled');
    
    RETURN v_user_points >= p_points_cost;
END;
$$;

-- Function to handle reward redemption
CREATE OR REPLACE FUNCTION redeem_reward(
    p_reward_id UUID,
    p_redemption_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_points_cost INTEGER;
    v_quantity_available INTEGER;
    v_redemption_id UUID;
    v_agent_profile_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated';
    END IF;
    
    -- Get agent profile id
    SELECT id INTO v_agent_profile_id
    FROM public.agent_profiles
    WHERE user_id = v_user_id;
    
    -- Get reward details
    SELECT points_cost, quantity_available
    INTO v_points_cost, v_quantity_available
    FROM public.rewards
    WHERE id = p_reward_id
    AND status = 'active';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reward not found or not active';
    END IF;
    
    -- Check if limited quantity is available
    IF v_quantity_available IS NOT NULL THEN
        IF v_quantity_available <= 0 THEN
            RAISE EXCEPTION 'Reward is out of stock';
        END IF;
    END IF;
    
    -- Check if user has enough points
    IF NOT check_user_points_for_redemption(v_user_id, v_points_cost) THEN
        RAISE EXCEPTION 'Insufficient points';
    END IF;
    
    -- Create redemption request
    INSERT INTO public.reward_redemptions (
        reward_id,
        user_id,
        agent_profile_id,
        points_spent,
        redemption_notes,
        status
    ) VALUES (
        p_reward_id,
        v_user_id,
        v_agent_profile_id,
        v_points_cost,
        p_redemption_notes,
        'pending'
    )
    RETURNING id INTO v_redemption_id;
    
    -- Update reward quantity if limited
    IF v_quantity_available IS NOT NULL THEN
        UPDATE public.rewards
        SET quantity_available = quantity_available - 1,
            quantity_claimed = quantity_claimed + 1,
            updated_at = NOW()
        WHERE id = p_reward_id;
    ELSE
        UPDATE public.rewards
        SET quantity_claimed = quantity_claimed + 1,
            updated_at = NOW()
        WHERE id = p_reward_id;
    END IF;
    
    RETURN v_redemption_id;
END;
$$;

-- Function to approve/reject redemption
CREATE OR REPLACE FUNCTION review_redemption(
    p_redemption_id UUID,
    p_status TEXT,
    p_review_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_reviewer_id UUID;
    v_is_admin BOOLEAN;
    v_reward_id UUID;
    v_old_status TEXT;
BEGIN
    v_reviewer_id := auth.uid();
    
    -- Check if user is admin
    SELECT EXISTS (
        SELECT 1 FROM public.agent_profiles
        WHERE user_id = v_reviewer_id
        AND role IN ('cin_admin', 'organization_admin')
    ) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Only admins can review redemptions';
    END IF;
    
    -- Validate status
    IF p_status NOT IN ('approved', 'rejected', 'fulfilled') THEN
        RAISE EXCEPTION 'Invalid status';
    END IF;
    
    -- Get current redemption details
    SELECT reward_id, status
    INTO v_reward_id, v_old_status
    FROM public.reward_redemptions
    WHERE id = p_redemption_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption not found';
    END IF;
    
    -- Update redemption status
    UPDATE public.reward_redemptions
    SET status = p_status,
        review_notes = p_review_notes,
        reviewed_by = v_reviewer_id,
        reviewed_at = NOW(),
        fulfilled_at = CASE WHEN p_status = 'fulfilled' THEN NOW() ELSE NULL END,
        updated_at = NOW()
    WHERE id = p_redemption_id;
    
    -- If rejected, return the quantity to reward
    IF p_status = 'rejected' AND v_old_status = 'pending' THEN
        UPDATE public.rewards
        SET quantity_available = CASE 
                WHEN quantity_available IS NOT NULL 
                THEN quantity_available + 1 
                ELSE NULL 
            END,
            quantity_claimed = quantity_claimed - 1,
            updated_at = NOW()
        WHERE id = v_reward_id;
    END IF;
    
    RETURN TRUE;
END;
$$;

-- Function to get user's available points
CREATE OR REPLACE FUNCTION get_user_available_points(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_earned_points INTEGER;
    v_spent_points INTEGER;
BEGIN
    -- Calculate earned points from point_transactions
    -- Note: agents.id IS the user_id (references auth.users)
    SELECT COALESCE(SUM(points_amount), 0)
    INTO v_earned_points
    FROM public.point_transactions
    WHERE agent_id = p_user_id
    AND transaction_type IN ('earned', 'bonus');
    
    -- Calculate spent points from approved/fulfilled redemptions
    SELECT COALESCE(SUM(points_spent), 0)
    INTO v_spent_points
    FROM public.reward_redemptions
    WHERE user_id = p_user_id
    AND status IN ('approved', 'fulfilled');
    
    RETURN v_earned_points - v_spent_points;
END;
$$;

-- Create updated_at trigger for rewards
CREATE TRIGGER update_rewards_updated_at
    BEFORE UPDATE ON public.rewards
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Create updated_at trigger for reward_redemptions
CREATE TRIGGER update_reward_redemptions_updated_at
    BEFORE UPDATE ON public.reward_redemptions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.rewards TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.reward_redemptions TO authenticated;
GRANT EXECUTE ON FUNCTION check_user_points_for_redemption TO authenticated;
GRANT EXECUTE ON FUNCTION redeem_reward TO authenticated;
GRANT EXECUTE ON FUNCTION review_redemption TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_available_points TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE public.rewards IS 'Stores reward offerings that users can redeem with points';
COMMENT ON TABLE public.reward_redemptions IS 'Tracks user reward redemption requests and their approval status';
COMMENT ON FUNCTION redeem_reward IS 'Allows authenticated users to redeem rewards with their points';
COMMENT ON FUNCTION review_redemption IS 'Allows admins to approve/reject/fulfill redemption requests';
COMMENT ON FUNCTION get_user_available_points IS 'Calculates user''s available points for redemption';
