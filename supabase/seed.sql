-- Complete CIN Admin Creation Script
-- This script creates a fully functional CIN admin that can sign in and manage the system
-- Replace the password and email as needed

DO $$
DECLARE
    -- Generated UUID for the CIN admin
    cin_admin_uuid UUID := 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
    
    -- CIN Admin Details (customize these values)
    admin_email TEXT := 'cinadmin1@climateintel.org';
    admin_password TEXT := 'CinAdmin2025!SecurePass';
    admin_full_name TEXT := 'CIN System Administrator';
    admin_phone TEXT := '+1-555-0199';
    admin_address TEXT := '123 Climate Action Ave, Green City, CA 90210';
    
    -- CIN Organization Details
    cin_org_id UUID := '00000000-1111-2222-3333-444444444444';
    cin_org_name TEXT := 'The Climate Intelligence Network';
    cin_org_description TEXT := 'Global network coordinating climate action through technology and community engagement.';
    cin_org_website TEXT := 'https://climateintelligence.network';
    cin_org_email TEXT := 'contact@climateintelligence.network';
    
    -- Internal variables
    encrypted_password TEXT;
    password_salt TEXT;
BEGIN
    -- Generate proper bcrypt hash (Supabase compatible)
    password_salt := gen_salt('bf', 10);  -- bcrypt with cost 10
    encrypted_password := crypt(admin_password, password_salt);
    
    RAISE NOTICE '=== CIN ADMIN CREATION SCRIPT ===';
    RAISE NOTICE 'Creating CIN Organization and Admin with the following details:';
    RAISE NOTICE 'Organization: %', cin_org_name;
    RAISE NOTICE 'Admin UUID: %', cin_admin_uuid;
    RAISE NOTICE 'Admin Email: %', admin_email;
    RAISE NOTICE 'Admin Name: %', admin_full_name;
    RAISE NOTICE '';
    
    -- Check if user already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE id = cin_admin_uuid OR email = admin_email) THEN
        RAISE EXCEPTION 'User with UUID % or email % already exists!', cin_admin_uuid, admin_email;
    END IF;
    
    -- Check if CIN organization already exists
    IF EXISTS (SELECT 1 FROM public.organizations WHERE id = cin_org_id OR name = cin_org_name) THEN
        RAISE EXCEPTION 'Organization with UUID % or name % already exists!', cin_org_id, cin_org_name;
    END IF;
    
    -- Step 1: Create user in auth.users table
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        role,
        aud,
        confirmation_token,
        email_change_token_new,
        recovery_token,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin,
        last_sign_in_at,
        phone,
        phone_confirmed_at,
        phone_change,
        phone_change_token,
        email_change,
        email_change_token_current,
        email_change_confirm_status,
        banned_until,
        reauthentication_token,
        reauthentication_sent_at,
        is_sso_user,
        deleted_at
    ) VALUES (
        cin_admin_uuid,                                    -- id
        '00000000-0000-0000-0000-000000000000',           -- instance_id (default)
        admin_email,                                       -- email
        encrypted_password,                                -- encrypted_password
        NOW(),                                            -- email_confirmed_at
        NOW(),                                            -- created_at
        NOW(),                                            -- updated_at
        'authenticated',                                   -- role
        'authenticated',                                   -- aud
        '',                                               -- confirmation_token
        '',                                               -- email_change_token_new
        '',                                               -- recovery_token
        '{"provider": "email", "providers": ["email"]}',  -- raw_app_meta_data
        '{}',                                             -- raw_user_meta_data (empty to skip trigger)
        FALSE,                                            -- is_super_admin
        NULL,                                             -- last_sign_in_at
        NULL,                                             -- phone
        NULL,                                             -- phone_confirmed_at
        '',                                               -- phone_change
        '',                                               -- phone_change_token
        '',                                               -- email_change
        '',                                               -- email_change_token_current
        0,                                                -- email_change_confirm_status
        NULL,                                             -- banned_until
        '',                                               -- reauthentication_token
        NULL,                                             -- reauthentication_sent_at
        FALSE,                                            -- is_sso_user
        NULL                                              -- deleted_at
    );
    
    RAISE NOTICE '✅ Step 1: Created auth.users record';
    
    -- Step 2: Create The Climate Intelligence Network organization
    INSERT INTO public.organizations (
        id,
        name,
        description,
        website,
        address,
        contact_email,
        contact_phone,
        created_at,
        updated_at
    ) VALUES (
        cin_org_id,
        cin_org_name,
        cin_org_description,
        cin_org_website,
        admin_address,
        cin_org_email,
        admin_phone,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 2: Created CIN organization';
    
    -- Step 3: Create admin profile
    INSERT INTO public.admins (
        id,
        full_name,
        email,
        phone,
        address,
        active_organization_id,
        created_at,
        updated_at
    ) VALUES (
        cin_admin_uuid,
        admin_full_name,
        admin_email,
        admin_phone,
        admin_address,
        cin_org_id,              -- Set CIN organization as active
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 3: Created admin profile';
    
    -- Step 4: Create admin membership to CIN organization
    INSERT INTO public.admin_memberships (
        admin_id,
        organization_id,
        status,
        created_at,
        updated_at
    ) VALUES (
        cin_admin_uuid,
        cin_org_id,
        'active',                -- CIN admins are always active
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 4: Created admin membership to CIN organization';
    
    -- Step 5: Assign global CIN admin role
    INSERT INTO public.user_roles (
        user_id,
        role,
        organization_id,
        created_at,
        updated_at
    ) VALUES (
        cin_admin_uuid,
        'cin_admin',
        NULL,                    -- Global role (not organization-specific)
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 5: Assigned global CIN admin role';
    
    -- Step 6: Also assign org_admin role for CIN organization
    INSERT INTO public.user_roles (
        user_id,
        role,
        organization_id,
        created_at,
        updated_at
    ) VALUES (
        cin_admin_uuid,
        'org_admin',
        cin_org_id,              -- Org admin role for CIN organization
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 6: Assigned org_admin role for CIN organization';
    
    -- Step 7: Create auth.identities record (required for email login)
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        cin_admin_uuid,
        jsonb_build_object(
            'sub', cin_admin_uuid::text,
            'email', admin_email,
            'email_verified', true,
            'phone_verified', false
        ),
        'email',
        cin_admin_uuid::text,  -- provider_id is required
        NULL,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 7: Created identity record';
    
    -- Step 8: Grant all organization permission types to CIN organization
    INSERT INTO public.organization_permissions (
        organization_id,
        permission_type,
        status,
        requested_by,
        reviewed_by,
        reviewed_at,
        created_at,
        updated_at
    ) VALUES 
    (
        cin_org_id,
        'mobilizing_partners',
        'approved',              -- Pre-approved for CIN organization
        cin_admin_uuid,          -- Requested by CIN admin
        cin_admin_uuid,          -- Auto-approved by CIN admin
        NOW(),
        NOW(),
        NOW()
    ),
    (
        cin_org_id,
        'mission_partners',
        'approved',              -- Pre-approved for CIN organization
        cin_admin_uuid,          -- Requested by CIN admin
        cin_admin_uuid,          -- Auto-approved by CIN admin
        NOW(),
        NOW(),
        NOW()
    ),
    (
        cin_org_id,
        'reward_partners',
        'approved',              -- Pre-approved for CIN organization
        cin_admin_uuid,          -- Requested by CIN admin
        cin_admin_uuid,          -- Auto-approved by CIN admin
        NOW(),
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 8: Granted all organization permissions to CIN organization';
    
    -- Final verification
    RAISE NOTICE '';
    RAISE NOTICE '🎉 CIN ORGANIZATION & ADMIN CREATED SUCCESSFULLY! 🎉';
    RAISE NOTICE '';
    RAISE NOTICE '🏢 Organization Details:';
    RAISE NOTICE '   Name: %', cin_org_name;
    RAISE NOTICE '   ID: %', cin_org_id;
    RAISE NOTICE '   Website: %', cin_org_website;
    RAISE NOTICE '   Contact: %', cin_org_email;
    RAISE NOTICE '';
    RAISE NOTICE '� Admin Login Details:';
    RAISE NOTICE '   Email: %', admin_email;
    RAISE NOTICE '   Password: %', admin_password;
    RAISE NOTICE '   UUID: %', cin_admin_uuid;
    RAISE NOTICE '';
    RAISE NOTICE '🔑 Permissions: Global CIN Administrator + CIN Org Admin';
    RAISE NOTICE '   - Can approve organizations globally';
    RAISE NOTICE '   - Can manage all CIN admins globally';
    RAISE NOTICE '   - Can manage all organizations globally';
    RAISE NOTICE '   - Can create/manage missions and rewards globally';
    RAISE NOTICE '   - Admin of The Climate Intelligence Network organization';
    RAISE NOTICE '';
    RAISE NOTICE '🏢 CIN Organization Privileges:';
    RAISE NOTICE '   - Mobilizing Partners (can mobilize partner organizations)';
    RAISE NOTICE '   - Mission Partners (can create and manage missions)';
    RAISE NOTICE '   - Reward Partners (can create and manage rewards)';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT: Store the password securely!';
    RAISE NOTICE '';
    
    -- Verify the creation worked
    IF NOT EXISTS (
        SELECT 1 FROM auth.users au
        JOIN public.admins a ON au.id = a.id
        JOIN public.user_roles ur ON au.id = ur.user_id
        WHERE au.id = cin_admin_uuid
        AND au.email = admin_email
        AND ur.role = 'cin_admin'
        AND ur.organization_id IS NULL
    ) THEN
        RAISE EXCEPTION 'CIN Admin creation verification failed!';
    END IF;
    
    RAISE NOTICE '✅ Verification: All records created correctly';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error creating CIN Admin: %', SQLERRM;
        RAISE;
END $$;
