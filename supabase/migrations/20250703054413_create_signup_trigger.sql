-- Create signup trigger function
-- This trigger automatically creates appropriate entries when a new user signs up via Supabase Auth.

create function public.handle_new_user()
returns trigger
set search_path = ''
as $$
declare
  user_type text;
  user_roles_array text[];
  role_item text;
  org_id uuid;
  org_name text;
begin
  -- Special case: If no metadata exists at all, this might be a dashboard-created user
  -- In this case, don't create any profile - let manual SQL handle CIN admin setup
  if new.raw_user_meta_data is null or new.raw_user_meta_data = '{}'::jsonb then
    -- No metadata means dashboard creation - skip automatic profile creation
    -- This allows manual CIN admin setup via SQL after user creation
    return new;
  end if;
  
  -- Get user type from metadata (defaults to "agent" for public signups)
  user_type := coalesce(new.raw_user_meta_data->>'user_type', 'agent');
  
  -- Note: If no user_type is provided, we default to "agent" for public signups
  
  -- Security: Validate user_type against allowed values
  if user_type not in ('agent', 'admin') then
    raise exception 'Invalid user_type: %. Only "agent" and "admin" are allowed.', user_type;
  end if;
  
  -- Security: Prevent unauthorized CIN administrator creation via public signup
  -- CIN administrators can only be created through the Supabase dashboard or by existing CIN admins
  if new.raw_user_meta_data ? 'has_cin_admin_privileges' and (new.raw_user_meta_data->>'has_cin_admin_privileges')::boolean = true then
    raise exception 'CIN administrator accounts cannot be created through public signup. Contact system administrator.';
  end if;
  
  if user_type = 'admin' then
    -- Insert into admins table
    insert into public.admins (
      id, 
      full_name, 
      avatar_url, 
      email, 
      phone, 
      address
    )
    values (
      new.id, 
      new.raw_user_meta_data->>'full_name', 
      new.raw_user_meta_data->>'avatar_url', 
      new.email,
      new.raw_user_meta_data->>'phone',
      new.raw_user_meta_data->>'address'
    );
    
    -- Handle organization creation or assignment
    org_id := (new.raw_user_meta_data->>'organization_id')::uuid;
    
    if org_id is null then
      -- Create new organization if no org_id provided
      org_name := new.raw_user_meta_data->>'organization_name';
      if org_name is not null then
        -- Security: Validate organization name length
        if length(trim(org_name)) < 2 then
          raise exception 'Organization name must be at least 2 characters long.';
        end if;
        if length(org_name) > 100 then
          raise exception 'Organization name cannot exceed 100 characters.';
        end if;
        
        insert into public.organizations (name, contact_email)
        values (trim(org_name), new.email)
        returning id into org_id;
      end if;
    end if;
    
    -- Link admin to organization if org_id exists
    if org_id is not null then
      insert into public.admin_memberships (admin_id, organization_id, status)
      values (new.id, org_id, 
        case 
          when (new.raw_user_meta_data->>'organization_id') is not null then 'active'
          when exists (
            select 1 from public.organization_permissions op
            where op.organization_id = org_id
              and op.permission_type in ('mobilizing_partners', 'mission_partners', 'reward_partners')
              and op.status = 'approved'
          ) then 'active'
          else 'pending' 
        end
      );
      
      -- Set active organization
      update public.admins 
      set active_organization_id = org_id 
      where id = new.id;
    end if;
    
    -- Handle multiple permission types for admin
    -- Default to requesting basic partner mobilization privilege
    user_roles_array := string_to_array(
      coalesce(new.raw_user_meta_data->>'permission_types', 'mobilizing_partners'), 
      ','
    );
    
    -- Create organization permission requests for each type
    foreach role_item in array user_roles_array
    loop
      -- Security: Validate permission type
      begin
        insert into public.organization_permissions (
          organization_id, 
          permission_type, 
          status,
          requested_by
        ) 
        values (
          org_id, 
          trim(role_item)::public.organization_permission_type,
          case when (new.raw_user_meta_data->>'organization_id') is not null then 'approved' else 'pending' end,
          new.id
        )
        on conflict (organization_id, permission_type) do nothing;
      exception
        when invalid_text_representation then
          raise exception 'Invalid permission type: %. Valid types are: mobilizing_partners, mission_partners, reward_partners', trim(role_item);
      end;
    end loop;
    
    -- Assign admin role to the user for this organization
    insert into public.user_roles (user_id, role, organization_id) 
    values (new.id, 'admin'::public.app_role, org_id);
    
  else
    -- Default case: create agent (for any user_type that's not 'admin' or when user_type is null)
    insert into public.agents (
      id, 
      full_name, 
      avatar_url, 
      email, 
      phone, 
      address
    )
    values (
      new.id, 
      new.raw_user_meta_data->>'full_name', 
      new.raw_user_meta_data->>'avatar_url', 
      new.email,
      new.raw_user_meta_data->>'phone',
      new.raw_user_meta_data->>'address'
    );
    
    -- Assign global agent role (no organization_id)
    insert into public.user_roles (user_id, role, organization_id)
    values (new.id, 'agent'::public.app_role, null);
    
  end if;
  
  return new;
end;
$$ language plpgsql security definer;

-- Create the trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
