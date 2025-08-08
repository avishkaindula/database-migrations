-- ========================================
-- CREATE NEW CIN ADMIN SCRIPT
-- ========================================
-- Copy and paste this script into the Supabase SQL Editor dashboard
-- Customize the admin details in the DECLARE section below

DO $$
DECLARE
    -- ============ CUSTOMIZE THESE VALUES ============
    -- Generated UUID for the new CIN admin (generate a new one each time)
    new_admin_uuid UUID := gen_random_uuid();
    
    -- New CIN Admin Details (CHANGE THESE VALUES)
    admin_email TEXT := 'cinadmin2@climateintel.org';           -- Change this email
    admin_password TEXT := 'NewCinAdmin2025!SecurePass';        -- Change this password
    admin_full_name TEXT := 'CIN Regional Administrator';       -- Change this name
    admin_phone TEXT := '+1-555-0299';                          -- Change this phone
    admin_address TEXT := '456 Climate Hub Blvd, Eco City, CA 90211'; -- Change this address
    -- ================================================
    
    -- CIN Organization Details (DO NOT CHANGE - references existing CIN org)
    cin_org_id UUID := '00000000-1111-2222-3333-444444444444';
    
    -- Internal variables
    encrypted_password TEXT;
    password_salt TEXT;
BEGIN
    RAISE NOTICE '=== CREATING NEW CIN ADMIN ===';
    RAISE NOTICE 'Admin Email: %', admin_email;
    RAISE NOTICE 'Admin UUID: %', new_admin_uuid;
    RAISE NOTICE 'Admin Name: %', admin_full_name;
    RAISE NOTICE '';
    
    -- Validation: Check if user already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE id = new_admin_uuid OR email = admin_email) THEN
        RAISE EXCEPTION 'User with UUID % or email % already exists!', new_admin_uuid, admin_email;
    END IF;
    
    -- Validation: Check if CIN organization exists
    IF NOT EXISTS (SELECT 1 FROM public.organizations WHERE id = cin_org_id) THEN
        RAISE EXCEPTION 'CIN organization with UUID % does not exist! Run the main seed script first.', cin_org_id;
    END IF;
    
    -- Generate salt and encrypt password (Supabase compatible)
    password_salt := encode(gen_random_bytes(16), 'hex');
    encrypted_password := crypt(admin_password, password_salt);
    
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
        new_admin_uuid,                                        -- id
        '00000000-0000-0000-0000-000000000000',               -- instance_id (default)
        admin_email,                                           -- email
        encrypted_password,                                    -- encrypted_password
        NOW(),                                                -- email_confirmed_at
        NOW(),                                                -- created_at
        NOW(),                                                -- updated_at
        'authenticated',                                       -- role
        'authenticated',                                       -- aud
        '',                                                   -- confirmation_token
        '',                                                   -- email_change_token_new
        '',                                                   -- recovery_token
        '{"provider": "email", "providers": ["email"]}',      -- raw_app_meta_data
        '{}',                                                 -- raw_user_meta_data (empty to skip trigger)
        FALSE,                                                -- is_super_admin
        NULL,                                                 -- last_sign_in_at
        NULL,                                                 -- phone
        NULL,                                                 -- phone_confirmed_at
        '',                                                   -- phone_change
        '',                                                   -- phone_change_token
        '',                                                   -- email_change
        '',                                                   -- email_change_token_current
        0,                                                    -- email_change_confirm_status
        NULL,                                                 -- banned_until
        '',                                                   -- reauthentication_token
        NULL,                                                 -- reauthentication_sent_at
        FALSE,                                                -- is_sso_user
        NULL                                                  -- deleted_at
    );
    
    RAISE NOTICE '✅ Step 1: Created auth.users record';
    
    -- Step 2: Create admin profile
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
        new_admin_uuid,
        admin_full_name,
        admin_email,
        admin_phone,
        admin_address,
        cin_org_id,              -- Set CIN organization as active
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 2: Created admin profile';
    
    -- Step 3: Create admin membership to CIN organization
    INSERT INTO public.admin_memberships (
        admin_id,
        organization_id,
        status,
        created_at,
        updated_at
    ) VALUES (
        new_admin_uuid,
        cin_org_id,
        'active',                -- CIN admins are always active
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 3: Created admin membership to CIN organization';
    
    -- Step 4: Assign admin role for CIN organization
    INSERT INTO public.user_roles (
        user_id,
        role,
        organization_id,
        created_at,
        updated_at
    ) VALUES (
        new_admin_uuid,
        'admin',
        cin_org_id,              -- Admin role for CIN organization
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 4: Assigned admin role for CIN organization';
    
    -- Step 5: Grant CIN administrators privilege
    INSERT INTO public.organization_permissions (
        organization_id,
        permission_type,
        status,
        requested_by,
        reviewed_by,
        reviewed_at,
        created_at,
        updated_at
    ) VALUES (
        cin_org_id,
        'cin_administrators',
        'approved',              -- Pre-approved for CIN organization
        new_admin_uuid,          -- Requested by new admin
        new_admin_uuid,          -- Auto-approved by new admin
        NOW(),
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 5: Granted CIN administrators privilege';
    
    -- Step 6: Create auth.identities record (required for email login)
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
        new_admin_uuid,
        jsonb_build_object(
            'sub', new_admin_uuid::text,
            'email', admin_email,
            'email_verified', true,
            'phone_verified', false
        ),
        'email',
        new_admin_uuid::text,  -- provider_id is required
        NULL,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 6: Created identity record';
    
    -- Final success message
    RAISE NOTICE '';
    RAISE NOTICE '🎉 NEW CIN ADMIN CREATED SUCCESSFULLY! 🎉';
    RAISE NOTICE '';
    RAISE NOTICE '👤 Admin Login Details:';
    RAISE NOTICE '   Email: %', admin_email;
    RAISE NOTICE '   Password: %', admin_password;
    RAISE NOTICE '   UUID: %', new_admin_uuid;
    RAISE NOTICE '   Name: %', admin_full_name;
    RAISE NOTICE '';
    RAISE NOTICE '🔑 Permissions: CIN Administrator with full privileges';
    RAISE NOTICE '   - Can approve organizations globally';
    RAISE NOTICE '   - Can manage all admins globally';
    RAISE NOTICE '   - Can manage all organizations globally';
    RAISE NOTICE '   - Can create/manage missions and rewards globally';
    RAISE NOTICE '   - Admin of The Climate Intelligence Network organization';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT: Store the login credentials securely!';
    RAISE NOTICE '';
    
    -- Verify the creation worked
    IF NOT EXISTS (
        SELECT 1 FROM auth.users au
        JOIN public.admins a ON au.id = a.id
        JOIN public.user_roles ur ON au.id = ur.user_id
        JOIN public.admin_memberships am ON au.id = am.admin_id
        JOIN public.organization_permissions op ON am.organization_id = op.organization_id
        WHERE au.id = new_admin_uuid
        AND au.email = admin_email
        AND ur.role = 'admin'
        AND ur.organization_id = cin_org_id
        AND op.permission_type = 'cin_administrators'
        AND op.status = 'approved'
    ) THEN
        RAISE EXCEPTION 'CIN Admin creation verification failed!';
    END IF;
    
    RAISE NOTICE '✅ Verification: New CIN admin created and verified successfully';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error creating CIN Admin: %', SQLERRM;
        RAISE;
END $$;
