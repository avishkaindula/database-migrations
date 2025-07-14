# Climate Intelligence Network - Database Migrations

This repository contains the database schema and migrations for the Climate Intelligence Network (CIN) application, built with Supabase.

## Quick Setup

1. Copy .env.example to .env.local
2. Create a new OAuth Application in Github -> Settings -> Developer Settings
3. Put the client secret and client ID in the .env.local file
4. Run `npm i` or `pnpm i`
5. Run `npx supabase start` or `pnpm exec supabase start`
6. Run `npx supabase db reset` or `pnpm exec supabase db reset`

**Note**: The `db reset` command will automatically run all migrations and the `seed.sql` script, creating the initial CIN organization and first CIN admin.

## System Overview

The Climate Intelligence Network uses a role-based permission system with three main user types and organization-level capabilities.

### User Roles

1. **`player`** - Regular users who participate in missions and earn rewards
2. **`org_admin`** - Organization administrators who manage their organization's activities
3. **`cin_admin`** - Global system administrators who approve organizations and manage the entire network

### Organization Permission Types

Organizations can request and be granted different capabilities:

- **`player_org`** - Can have players join and manage player activities
- **`mission_creator`** - Can create and manage climate action missions
- **`reward_creator`** - Can create and distribute rewards for mission completion

## Organization Signup and Activation Flow

### 1. New Organization Signup

When a new organization wants to join the network, they sign up with the following payload:

```javascript
const { error } = await supabase.auth.signUp({
  email: 'admin@neworg.com',
  password: 'securepassword123',
  options: {
    data: {
      user_type: 'admin',                    // Creates an org_admin
      full_name: 'John Doe',                 
      phone: '+1-555-0123',
      address: '123 Main St, City, State',
      organization_name: 'New Organization Name',  // Creates new org
      permission_types: 'player_org,mission_creator,reward_creator'  // Requested permissions
    }
  }
})
```

### 2. What Happens During Signup

The `handle_new_user()` trigger automatically:

1. Creates a new organization entry
2. Creates an admin profile for the user
3. Links the admin to the organization with `status: 'pending'`
4. Creates organization permission requests with `status: 'pending'`
5. Assigns the user an `org_admin` role for that organization

### 3. Organization "Status" System

**Important**: Organizations don't have a direct status field. Instead, their "activation" is controlled through the `organization_permissions` table:

- **Pending Organization**: Has permissions with `status: 'pending'`
- **Active Organization**: Has permissions with `status: 'approved'`
- **Rejected Organization**: Has permissions with `status: 'rejected'`

### 4. CIN Admin Approval Process

CIN admins can approve organizations using helper functions:

```javascript
// Get all pending organization approvals
const { data: pending } = await supabase.rpc('get_pending_organization_approvals')

// Approve all requested permissions for an organization
const { data: result } = await supabase.rpc('approve_organization_permissions', {
  target_organization_id: 'org-uuid-here'
})

// Approve only specific permissions
const { data: result } = await supabase.rpc('approve_organization_permissions', {
  target_organization_id: 'org-uuid-here',
  permission_types: ['player_org', 'mission_creator']
})

// Reject permissions
const { data: result } = await supabase.rpc('reject_organization_permissions', {
  target_organization_id: 'org-uuid-here',
  permission_types: ['reward_creator'],
  rejection_reason: 'Insufficient documentation provided'
})
```

### 5. Adding Members to Existing Organizations

If someone wants to join an existing **active** organization, they can sign up with:

```javascript
const { error } = await supabase.auth.signUp({
  email: 'newmember@existingorg.com',
  password: 'securepassword123',
  options: {
    data: {
      user_type: 'admin',
      full_name: 'Jane Smith',
      organization_id: 'existing-org-uuid-here'  // Join existing org instead of creating new one
    }
  }
})
```

The system will automatically give them `status: 'active'` if the organization already has approved permissions.

## Initial Setup

The system starts with a CIN admin and CIN organization created via the seed script. This CIN admin can then approve new organizations as they sign up.

### Seed Script (`supabase/seed.sql`)

The seed script automatically creates:

1. **The Climate Intelligence Network Organization**
   - ID: `00000000-1111-2222-3333-444444444444`
   - Name: "The Climate Intelligence Network"
   - Website: <https://climateintelligence.network>
   - Contact: <contact@climateintelligence.network>

2. **First CIN Admin**
   - Email: `cinadmin1@climateintel.org`
   - Password: `CinAdmin2025!SecurePass`
   - UUID: `f47ac10b-58cc-4372-a567-0e02b2c3d479`
   - **Both Global CIN Admin and CIN Organization Admin roles**

3. **CIN Organization Permissions** (Pre-approved)
   - `player_org` - Can have players join
   - `mission_creator` - Can create missions
   - `reward_creator` - Can create rewards

**⚠️ Important**: Change the default credentials in `seed.sql` before deploying to production!

### Adding More CIN Admins

To create additional CIN admins, use the `create_new_cin_admin.sql` script:

1. Open the Supabase Dashboard → SQL Editor
2. Copy and paste the contents of `create_new_cin_admin.sql`
3. Customize the admin details in the `DECLARE` section:

   ```sql
   admin_email TEXT := 'neadmin@climateintel.org';        -- Change this
   admin_password TEXT := 'SecurePassword123!';           -- Change this  
   admin_full_name TEXT := 'New CIN Administrator';       -- Change this
   admin_phone TEXT := '+1-555-0199';                     -- Change this
   admin_address TEXT := '123 Admin Street, City, State'; -- Change this
   ```

4. Execute the script

This will create a new CIN admin with:

- Global CIN admin permissions (can approve organizations)
- CIN organization admin membership
- Proper authentication setup for immediate login

## Migration Files Overview

The database schema is built through these migration files (applied in order):

1. **`20250625011105_create_base_tables.sql`**
   - Creates core tables: `organizations`, `players`, `admins`, `admin_memberships`
   - Sets up avatar storage bucket and policies
   - No RLS policies yet (added later)

2. **`20250703053654_create_roles_system.sql`**
   - Creates custom types: `app_role`, `app_permission`, `organization_permission_type`
   - Creates role/permission tables: `user_roles`, `role_permissions`, `organization_permissions`
   - Defines authorization functions and role permissions mapping
   - Creates helper functions for permission checking

3. **`20250703054413_create_signup_trigger.sql`**
   - Creates `handle_new_user()` trigger function
   - Automatically processes new user signups based on metadata
   - Handles both player and admin creation flows
   - Prevents unauthorized CIN admin creation via public signup

4. **`20250703055000_create_auth_hook.sql`**
   - Creates JWT custom claims hook for Supabase Auth
   - Adds user roles and organization data to JWT tokens
   - Required for client-side authorization
   - Grants proper permissions to `supabase_auth_admin`

5. **`20250703060000_enable_rls_and_policies.sql`**
   - Enables Row Level Security on all tables
   - Creates comprehensive security policies
   - Adds performance indexes for common queries
   - Optimized policies to avoid multiple permissive rules

6. **`20250715000000_add_organization_approval_functions.sql`** (Helper functions)
   - `approve_organization_permissions()` - Approve organization capabilities
   - `reject_organization_permissions()` - Reject organization requests  
   - `get_pending_organization_approvals()` - List pending approvals for CIN admin dashboard

## Database Schema Key Tables

- **`organizations`** - Organization details
- **`admins`** - Organization administrator profiles  
- **`players`** - Player profiles
- **`admin_memberships`** - Links admins to organizations with status
- **`user_roles`** - Assigns roles to users (globally or per-organization)
- **`organization_permissions`** - Tracks requested/approved capabilities per organization
- **`role_permissions`** - Defines what each role can do

## Automated User Processing

### Signup Trigger (`handle_new_user`)

The system automatically processes new user signups based on the `raw_user_meta_data` provided:

**For Players** (default when no `user_type` specified):

- Creates player profile
- Assigns global `player` role
- No organization restrictions

**For Admins** (`user_type: 'admin'`):

- Creates admin profile
- Creates or joins organization
- Requests organization permissions
- Assigns `org_admin` role for that organization
- Status depends on organization approval state

**Security Features**:

- CIN admins cannot be created via public signup (dashboard only)
- Input validation for organization names and permission types
- Prevents unauthorized role escalation

### JWT Auth Hook (`custom_access_token_hook`)

Automatically adds user context to JWT tokens:

- User roles (global and organization-scoped)
- Organization memberships and capabilities
- Active organization ID
- Used for client-side authorization and RLS policies

### JWT Token Examples

The `custom_access_token_hook` adds custom claims to JWT tokens. Here's what the tokens look like for different user scenarios:

#### 1. Regular Player (Global Role)

```json
{
  "aud": "authenticated",
  "exp": 1721851200,
  "iat": 1721847600,
  "iss": "https://your-project.supabase.co/auth/v1",
  "sub": "550e8400-e29b-41d4-a716-446655440001",
  "email": "player@example.com",
  "user_roles": [
    {
      "role": "player",
      "scope": "global"
    }
  ],
  "user_organizations": [],
  "active_organization_id": null
}
```

#### 2. CIN Admin (Global + Organization Roles)

```json
{
  "aud": "authenticated",
  "exp": 1721851200,
  "iat": 1721847600,
  "iss": "https://your-project.supabase.co/auth/v1",
  "sub": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "email": "cinadmin1@climateintel.org",
  "user_roles": [
    {
      "role": "cin_admin",
      "scope": "global"
    },
    {
      "role": "org_admin", 
      "scope": "organization",
      "organization_id": "00000000-1111-2222-3333-444444444444",
      "organization_name": "The Climate Intelligence Network"
    }
  ],
  "user_organizations": [
    {
      "id": "00000000-1111-2222-3333-444444444444",
      "name": "The Climate Intelligence Network",
      "membership_status": "active",
      "capabilities": [
        {"type": "player_org", "status": "approved"},
        {"type": "mission_creator", "status": "approved"},
        {"type": "reward_creator", "status": "approved"}
      ]
    }
  ],
  "active_organization_id": "00000000-1111-2222-3333-444444444444"
}
```

#### 3. Organization Admin (Pending Approval)

```json
{
  "aud": "authenticated", 
  "exp": 1721851200,
  "iat": 1721847600,
  "iss": "https://your-project.supabase.co/auth/v1",
  "sub": "123e4567-e89b-12d3-a456-426614174001",
  "email": "admin@greentech.org",
  "user_roles": [
    {
      "role": "org_admin",
      "scope": "organization", 
      "organization_id": "987fcdeb-51a2-4b3c-9d4e-5f6789abcdef",
      "organization_name": "GreenTech Solutions"
    }
  ],
  "user_organizations": [
    {
      "id": "987fcdeb-51a2-4b3c-9d4e-5f6789abcdef",
      "name": "GreenTech Solutions",
      "membership_status": "active",
      "capabilities": [
        {"type": "player_org", "status": "pending"},
        {"type": "mission_creator", "status": "pending"}
      ]
    }
  ],
  "active_organization_id": "987fcdeb-51a2-4b3c-9d4e-5f6789abcdef"
}
```

#### 4. Organization Admin (Approved with Mixed Permissions)

```json
{
  "aud": "authenticated",
  "exp": 1721851200, 
  "iat": 1721847600,
  "iss": "https://your-project.supabase.co/auth/v1",
  "sub": "456e7890-e12c-34d5-b678-901234567890",
  "email": "admin@ecoalliance.org",
  "user_roles": [
    {
      "role": "org_admin",
      "scope": "organization",
      "organization_id": "111a222b-333c-444d-555e-666f777g888h", 
      "organization_name": "Eco Alliance"
    }
  ],
  "user_organizations": [
    {
      "id": "111a222b-333c-444d-555e-666f777g888h",
      "name": "Eco Alliance", 
      "membership_status": "active",
      "capabilities": [
        {"type": "player_org", "status": "approved"},
        {"type": "mission_creator", "status": "approved"},
        {"type": "reward_creator", "status": "rejected"}
      ]
    }
  ],
  "active_organization_id": "111a222b-333c-444d-555e-666f777g888h"
}
```

#### 5. Multi-Organization Admin

```json
{
  "aud": "authenticated",
  "exp": 1721851200,
  "iat": 1721847600, 
  "iss": "https://your-project.supabase.co/auth/v1",
  "sub": "789a012b-345c-678d-901e-234f567g890h",
  "email": "admin@consultant.com",
  "user_roles": [
    {
      "role": "org_admin",
      "scope": "organization",
      "organization_id": "aaa1111b-222c-333d-444e-555f666g777h",
      "organization_name": "Climate Consultants"
    },
    {
      "role": "org_admin", 
      "scope": "organization",
      "organization_id": "bbb2222c-333d-444e-555f-666g777h888i",
      "organization_name": "Green Solutions Inc"
    }
  ],
  "user_organizations": [
    {
      "id": "aaa1111b-222c-333d-444e-555f666g777h",
      "name": "Climate Consultants",
      "membership_status": "active", 
      "capabilities": [
        {"type": "player_org", "status": "approved"},
        {"type": "mission_creator", "status": "approved"}
      ]
    },
    {
      "id": "bbb2222c-333d-444e-555f-666g777h888i",
      "name": "Green Solutions Inc",
      "membership_status": "active",
      "capabilities": [
        {"type": "player_org", "status": "approved"}
      ]
    }
  ],
  "active_organization_id": "aaa1111b-222c-333d-444e-555f666g777h"
}
```

#### 6. New User (No Profile Created Yet)

```json
{
  "aud": "authenticated",
  "exp": 1721851200,
  "iat": 1721847600,
  "iss": "https://your-project.supabase.co/auth/v1", 
  "sub": "999z888y-777x-666w-555v-444u333t222s",
  "email": "newuser@example.com",
  "user_roles": [],
  "user_organizations": [],
  "active_organization_id": null
}
```

### Using JWT Claims in Client Applications

You can access these claims in your client application:

```javascript
// Get current user and token
const { data: { user } } = await supabase.auth.getUser()
const token = (await supabase.auth.getSession()).data.session?.access_token

// Decode token to access custom claims (or use supabase.auth.getUser())
const userRoles = user?.user_metadata?.user_roles || []
const userOrganizations = user?.user_metadata?.user_organizations || []
const activeOrgId = user?.user_metadata?.active_organization_id

// Check if user has specific role
const isCinAdmin = userRoles.some(role => 
  role.role === 'cin_admin' && role.scope === 'global'
)

// Check if user is admin of specific organization
const isOrgAdmin = (orgId) => userRoles.some(role =>
  role.role === 'org_admin' && 
  role.scope === 'organization' && 
  role.organization_id === orgId
)

// Get organization capabilities
const getOrgCapabilities = (orgId) => {
  const org = userOrganizations.find(o => o.id === orgId)
  return org?.capabilities || []
}

// Check if organization has specific approved capability
const hasApprovedCapability = (orgId, capabilityType) => {
  const capabilities = getOrgCapabilities(orgId)
  return capabilities.some(cap => 
    cap.type === capabilityType && cap.status === 'approved'
  )
}
```

## Organization Management Workflow

### 1. Organization Signup

```javascript
// New organization admin signs up
const { error } = await supabase.auth.signUp({
  email: 'admin@neworg.com',
  password: 'password123',
  options: {
    data: {
      user_type: 'admin',
      organization_name: 'New Organization',
      permission_types: 'player_org,mission_creator'
    }
  }
})
```

### 2. CIN Admin Reviews

```javascript
// Get pending approvals
const { data: pending } = await supabase.rpc('get_pending_organization_approvals')

// Approve organization
const { data: result } = await supabase.rpc('approve_organization_permissions', {
  target_organization_id: 'org-uuid'
})
```

### 3. Organization Becomes Active

- Organization permissions status changed to `'approved'`
- Admin membership status changed to `'active'`
- Organization can now perform approved activities
- Additional members can join with automatic `'active'` status

## Security Features

- Row Level Security (RLS) enabled on all tables
- CIN admins can only be created manually (not through public signup)
- Organization permissions must be approved by CIN admins
- Role-based access control with organization scoping
- Input validation and sanitization in triggers