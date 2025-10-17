-- Update the complete_mission_submission function to award points immediately upon completion
-- This replaces the existing function to award points/energy immediately when a mission is completed

CREATE OR REPLACE FUNCTION complete_mission_submission(
  p_submission_id uuid,
  p_reviewed_by uuid DEFAULT NULL,
  p_review_notes text DEFAULT NULL,
  p_review_score integer DEFAULT NULL
)
RETURNS void 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_submission public.mission_submissions%ROWTYPE;
  v_mission public.missions%ROWTYPE;
  v_current_points integer;
  v_current_energy integer;
  v_new_points_balance integer;
  v_new_energy_balance integer;
BEGIN
  -- Get submission details
  SELECT * INTO v_submission
  FROM public.mission_submissions
  WHERE id = p_submission_id AND status = 'completed';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Submission not found or not in completed status';
  END IF;
  
  -- Check if already processed (avoid double processing)
  IF v_submission.status = 'reviewed' THEN
    RAISE EXCEPTION 'Submission already processed';
  END IF;
  
  -- Get mission details
  SELECT * INTO v_mission
  FROM public.missions
  WHERE id = v_submission.mission_id;
  
  -- Get current agent balances
  SELECT points, energy INTO v_current_points, v_current_energy
  FROM public.agents
  WHERE id = v_submission.agent_id;
  
  -- Calculate new balances
  v_new_points_balance := v_current_points + v_mission.points_awarded;
  v_new_energy_balance := v_current_energy + v_mission.energy_awarded;
  
  -- Create point transaction
  INSERT INTO public.point_transactions (
    agent_id, 
    mission_id, 
    submission_id,
    transaction_type,
    points_amount,
    description,
    balance_after,
    reference_type,
    reference_id
  ) VALUES (
    v_submission.agent_id,
    v_submission.mission_id,
    v_submission.id,
    'earned',
    v_mission.points_awarded,
    'Earned ' || v_mission.points_awarded || ' points for completing mission: ' || v_mission.title,
    v_new_points_balance,
    'mission_completion',
    v_submission.mission_id
  );
  
  -- Create energy transaction
  INSERT INTO public.energy_transactions (
    agent_id, 
    mission_id, 
    submission_id,
    transaction_type,
    energy_amount,
    description,
    balance_after,
    reference_type,
    reference_id
  ) VALUES (
    v_submission.agent_id,
    v_submission.mission_id,
    v_submission.id,
    'earned',
    v_mission.energy_awarded,
    'Earned ' || v_mission.energy_awarded || ' energy for completing mission: ' || v_mission.title,
    v_new_energy_balance,
    'mission_completion',
    v_submission.mission_id
  );
  
  -- Update submission status to reviewed (since we're auto-approving for now)
  UPDATE public.mission_submissions
  SET 
    status = 'reviewed',
    reviewed_by = p_reviewed_by,
    review_notes = COALESCE(p_review_notes, 'Auto-approved upon completion'),
    review_score = COALESCE(p_review_score, 5),
    updated_at = now()
  WHERE id = p_submission_id;
  
END;
$$;

-- Create function to auto-complete mission when all evidence is submitted
-- This is called from the application when all guidance steps are completed
CREATE OR REPLACE FUNCTION auto_complete_mission_submission(
  p_submission_id uuid
)
RETURNS json 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_submission public.mission_submissions%ROWTYPE;
  v_mission public.missions%ROWTYPE;
  v_guidance_steps jsonb;
  v_evidence jsonb;
  v_step jsonb;
  v_step_id text;
  v_all_completed boolean := true;
BEGIN
  -- Get submission details
  SELECT * INTO v_submission
  FROM public.mission_submissions
  WHERE id = p_submission_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Submission not found');
  END IF;
  
  -- Get mission details and guidance steps
  SELECT * INTO v_mission
  FROM public.missions
  WHERE id = v_submission.mission_id;
  
  v_guidance_steps := v_mission.guidance_steps;
  v_evidence := v_submission.guidance_evidence;
  
  -- Check if all guidance steps have evidence
  FOR v_step IN SELECT * FROM jsonb_array_elements(v_guidance_steps)
  LOOP
    v_step_id := v_step->>'id';
    
    -- Check if this step has evidence
    IF NOT (v_evidence ? v_step_id) OR jsonb_array_length(v_evidence->v_step_id) = 0 THEN
      v_all_completed := false;
      EXIT;
    END IF;
  END LOOP;
  
  -- If all steps completed, auto-complete and award points
  IF v_all_completed AND v_submission.status != 'reviewed' THEN
    -- Call the completion function (positional parameters work in PL/pgSQL)
    PERFORM complete_mission_submission(p_submission_id);
    
    RETURN json_build_object(
      'success', true, 
      'completed', true,
      'points_awarded', v_mission.points_awarded,
      'energy_awarded', v_mission.energy_awarded
    );
  ELSE
    RETURN json_build_object(
      'success', true, 
      'completed', false,
      'message', 'Mission not yet completed or already processed'
    );
  END IF;
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
