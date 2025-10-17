-- Update the complete_mission_submission function to award points immediately upon completion
-- This replaces the existing function to award points/energy immediately when a mission is completed

CREATE OR REPLACE FUNCTION public.complete_mission_submission(
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
  v_already_awarded boolean;
BEGIN
  -- Get submission details (any status is ok - we'll check if already processed)
  SELECT * INTO v_submission
  FROM public.mission_submissions
  WHERE id = p_submission_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Submission not found';
  END IF;
  
  -- Check if rewards already awarded (avoid double processing)
  SELECT EXISTS(
    SELECT 1 FROM public.point_transactions 
    WHERE submission_id = p_submission_id
  ) INTO v_already_awarded;
  
  IF v_already_awarded THEN
    -- Already processed, just update review info if provided
    IF p_reviewed_by IS NOT NULL THEN
      UPDATE public.mission_submissions
      SET 
        reviewed_by = p_reviewed_by,
        review_notes = p_review_notes,
        review_score = p_review_score
      WHERE id = p_submission_id;
    END IF;
    RETURN;
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
  
  -- Update submission status to completed and set completed_at
  UPDATE public.mission_submissions
  SET 
    status = 'completed',
    completed_at = timezone('utc'::text, now()),
    reviewed_by = p_reviewed_by,
    review_notes = p_review_notes,
    review_score = p_review_score,
    updated_at = now()
  WHERE id = p_submission_id;
  
  -- Update agent's total points and energy
  UPDATE public.agents
  SET 
    points = v_new_points_balance,
    energy = v_new_energy_balance
  WHERE id = v_submission.agent_id;
  
END;
$$;

-- Create function to auto-complete mission when all evidence is submitted
-- This is called from the application when all guidance steps are completed
CREATE OR REPLACE FUNCTION public.auto_complete_mission_submission(
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
  IF v_all_completed THEN
    -- Call the completion function (it will check if already processed)
    BEGIN
      PERFORM public.complete_mission_submission(p_submission_id);
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object(
        'success', false, 
        'error', 'Error calling complete_mission_submission: ' || SQLERRM,
        'detail', SQLSTATE
      );
    END;
    
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
      'message', 'Mission not yet completed - not all steps have evidence',
      'submission_status', v_submission.status
    );
  END IF;
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false, 
    'error', SQLERRM,
    'detail', SQLSTATE
  );
END;
$$;
