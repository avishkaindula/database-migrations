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
    
    -- Internal variables
    encrypted_password TEXT;
    password_salt TEXT;
BEGIN
    -- Generate salt and encrypt password (Supabase compatible)
    password_salt := encode(gen_random_bytes(16), 'hex');
    encrypted_password := crypt(admin_password, password_salt);
    
    RAISE NOTICE '=== CIN ADMIN CREATION SCRIPT ===';
    RAISE NOTICE 'Creating CIN Admin with the following details:';
    RAISE NOTICE 'UUID: %', cin_admin_uuid;
    RAISE NOTICE 'Email: %', admin_email;
    RAISE NOTICE 'Full Name: %', admin_full_name;
    RAISE NOTICE '';
    
    -- Check if user already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE id = cin_admin_uuid OR email = admin_email) THEN
        RAISE EXCEPTION 'User with UUID % or email % already exists!', cin_admin_uuid, admin_email;
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
        cin_admin_uuid,
        admin_full_name,
        admin_email,
        admin_phone,
        admin_address,
        NULL,                    -- No organization for global CIN admin
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 2: Created admin profile';
    
    -- Step 3: Assign global CIN admin role
    INSERT INTO public.user_roles (
        user_id,
        role,
        organization_id,
        created_at,
        updated_at
    ) VALUES (
        cin_admin_uuid,
        'cin_admin',
        NULL,                    -- Global role (no organization)
        NOW(),
        NOW()
    );
    
    RAISE NOTICE '✅ Step 3: Assigned CIN admin role';
    
    -- Step 4: Create auth.identities record (required for email login)
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
    
    RAISE NOTICE '✅ Step 4: Created identity record';
    
    -- Final verification
    RAISE NOTICE '';
    RAISE NOTICE '🎉 CIN ADMIN CREATED SUCCESSFULLY! 🎉';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Login Details:';
    RAISE NOTICE '   Email: %', admin_email;
    RAISE NOTICE '   Password: %', admin_password;
    RAISE NOTICE '   UUID: %', cin_admin_uuid;
    RAISE NOTICE '';
    RAISE NOTICE '🔑 Permissions: Global CIN Administrator';
    RAISE NOTICE '   - Can approve organizations';
    RAISE NOTICE '   - Can manage all CIN admins';
    RAISE NOTICE '   - Can manage all organizations';
    RAISE NOTICE '   - Can create/manage missions and rewards';
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
