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

The Climate Intelligence Network uses a role-based permission system with three main user types and organization-level privileges.

### User Roles

1. **`agent`** - Regular users who participate in missions and earn rewards
2. **`admin`** - Organization administrators who manage their organization's activities

### Organization Privilege Types

Organizations can request and be granted different privileges:

- **`mobilizing_partners`** - Can mobilize and coordinate partner organizations
- **`mission_partners`** - Can create and manage climate action missions
- **`reward_partners`** - Can create and manage reward redemption programs
- **`cin_administrators`** - Can manage the global CIN system (special privilege for CIN organization)
- **`reward_partners`** - Can create and distribute rewards for mission completion

## Organization Signup and Activation Flow

### 1. New Organization Signup

When a new organization wants to join the network, they sign up with the following payload:

```javascript
const { error } = await supabase.auth.signUp({
  email: 'admin@neworg.com',
  password: 'securepassword123',
  options: {
    data: {
      user_type: 'admin',                    // Creates an admin
      full_name: 'John Doe',                 
      phone: '+1-555-0123',
      address: '123 Main St, City, State',
      organization_name: 'New Organization Name',  // Creates new org
      permission_types: 'mobilizing_partners,mission_partners,reward_partners'  // Requested privileges
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
5. Assigns the user an `admin` role for that organization

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

// Approve all requested privileges for an organization
const { data: result } = await supabase.rpc('approve_organization_privileges', {
  target_organization_id: 'org-uuid-here'
})

// Approve only specific privileges
const { data: result } = await supabase.rpc('approve_organization_privileges', {
  target_organization_id: 'org-uuid-here',
  privilege_types: ['mobilizing_partners', 'mission_partners']
})

// Reject privileges
const { data: result } = await supabase.rpc('reject_organization_privileges', {
  target_organization_id: 'org-uuid-here',
  privilege_types: ['reward_partners'],
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

3. **CIN Organization Privileges** (Pre-approved)
   - `mobilizing_partners` - Can mobilize partner organizations
   - `mission_partners` - Can create missions
   - `reward_partners` - Can create rewards

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
   - Creates core tables: `organizations`, `agents`, `admins`, `admin_memberships`
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
   - Handles both agent and admin creation flows
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
   - `approve_organization_privileges()` - Approve organization privileges
   - `reject_organization_privileges()` - Reject organization requests  
   - `get_pending_organization_approvals()` - List pending approvals for CIN admin dashboard

## Database Schema Key Tables

- **`organizations`** - Organization details
- **`admins`** - Organization administrator profiles  
- **`agents`** - Agent profiles
- **`admin_memberships`** - Links admins to organizations with status
- **`user_roles`** - Assigns roles to users (globally or per-organization)
- **`organization_permissions`** - Tracks requested/approved privileges per organization
- **`role_permissions`** - Defines what each role can do

## Automated User Processing

### Signup Trigger (`handle_new_user`)

The system automatically processes new user signups based on the `raw_user_meta_data` provided:

**For Agents** (default when no `user_type` specified):

- Creates agent profile
- Assigns global `agent` role
- No organization restrictions

**For Admins** (`user_type: 'admin'`):

- Creates admin profile
- Creates or joins organization
- Requests organization permissions
- Assigns `admin` role for that organization
- Status depends on organization approval state

**Security Features**:

- CIN admins cannot be created via public signup (dashboard only)
- Input validation for organization names and permission types
- Prevents unauthorized role escalation

### JWT Auth Hook (`custom_access_token_hook`)

Automatically adds user context to JWT tokens:

- User roles (global and organization-scoped)
- Organization memberships and privileges
- Active organization ID
- Used for client-side authorization and RLS policies

### JWT Token Examples

The `custom_access_token_hook` adds custom claims to JWT tokens. Here's what the tokens look like for different user scenarios:

#### 1. Regular Agent (Global Role)

```json
{
  "aud": "authenticated",
  "exp": 1721851200,
  "iat": 1721847600,
  "iss": "https://your-project.supabase.co/auth/v1",
  "sub": "550e8400-e29b-41d4-a716-446655440001",
  "email": "agent@example.com",
  "user_roles": [
    {
      "role": "agent",
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
      "role": "admin",
      "scope": "global"
    },
    {
      "role": "admin", 
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
      "privileges": [
        {"type": "mobilizing_partners", "status": "approved"},
        {"type": "mission_partners", "status": "approved"},
        {"type": "reward_partners", "status": "approved"}
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
      "role": "admin",
      "scope": "organization", 
      "organization_id": "987fcdeb-51a2-4b3c-9d4e-5f6789abcdef",
      "organization_name": "GreenTech Solutions"
    }
  ],
  "user_organizations": [],
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
      "role": "admin",
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
      "privileges": [
        {"type": "mobilizing_partners", "status": "approved"},
        {"type": "mission_partners", "status": "approved"},
        {"type": "reward_partners", "status": "rejected"}
      ]
    }
  ],
  "active_organization_id": "111a222b-333c-444d-555e-666f777g888h"
}
```

#### 5. Multi-Organization Admin

**Note**: This scenario is unlikely to happen in the MVP, but the system supports it for future scalability.

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
      "role": "admin",
      "scope": "organization",
      "organization_id": "aaa1111b-222c-333d-444e-555f666g777h",
      "organization_name": "Climate Consultants"
    },
    {
      "role": "admin", 
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
      "privileges": [
        {"type": "mobilizing_partners", "status": "approved"},
        {"type": "mission_partners", "status": "approved"}
      ]
    },
    {
      "id": "bbb2222c-333d-444e-555f-666g777h888i",
      "name": "Green Solutions Inc",
      "membership_status": "active",
      "privileges": [
        {"type": "mobilizing_partners", "status": "approved"}
      ]
    }
  ],
  "active_organization_id": "aaa1111b-222c-333d-444e-555f666g777h"
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

// Get organization privileges
const getOrgPrivileges = (orgId) => {
  const org = userOrganizations.find(o => o.id === orgId)
  return org?.privileges || []
}

// Check if organization has specific approved privilege
const hasApprovedPrivilege = (orgId, privilegeType) => {
  const privileges = getOrgPrivileges(orgId)
  return privileges.some(priv =>
    priv.type === privilegeType && priv.status === 'approved'
  )
}
```

## Membership Status Behavior Deep Dive

Understanding when `admin_memberships.status` changes from `'pending'` to `'active'` is crucial for JWT token behavior and organization access.

### When Membership Status Becomes `'active'`

#### 1. **During Initial Signup** (Immediate `'active'`)

**SQL Logic from `handle_new_user()` trigger:**

```sql
-- From: supabase/migrations/20250703054413_create_signup_trigger.sql
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
```

**Scenarios for immediate `'active'` status:**
- **Joining existing organization**: User provides `organization_id` in signup metadata
- **Creating new org with pre-approved privileges**: Rare edge case where organization already exists with approved privileges

#### 2. **During CIN Admin Approval** (Pending → Active)

**SQL Logic from `approve_organization_permissions()` function:**

```sql
-- From: supabase/migrations/20250715000000_add_organization_approval_functions.sql
-- First, approve the organization permissions
update public.organization_permissions
set 
  status = 'approved',
  reviewed_by = reviewer_id,
  reviewed_at = now(),
  updated_at = now()
where organization_id = target_organization_id
  and status = 'pending'
  and (permission_types is null or permission_type = any(permission_types));

get diagnostics approved_count = row_count;

-- CRITICAL: If ANY permissions were approved, activate the membership
if approved_count > 0 then
  update public.admin_memberships
  set 
    status = 'active',
    updated_at = now()
  where organization_id = target_organization_id
    and status = 'pending';
end if;
```

**Key Point**: As soon as ANY privilege gets approved, membership becomes `'active'`!

### JWT Auth Hook Filtering

**SQL Logic from `custom_access_token_hook()` function:**

```sql
-- From: supabase/migrations/20250703055000_create_auth_hook.sql
-- Only organizations with 'active' membership appear in JWT
for org_record in 
  select 
    o.id, 
    o.name,
    am.status as membership_status,
    array_agg(
      jsonb_build_object(
        'type', op.permission_type,
        'status', op.status
      )
    ) filter (where op.permission_type is not null) as privileges
  from public.admin_memberships am
  join public.organizations o on am.organization_id = o.id
  left join public.organization_permissions op on op.organization_id = o.id
  where am.admin_id = (event->>'user_id')::uuid
    and am.status = 'active'  -- ⭐ CRITICAL FILTER
  group by o.id, o.name, am.status
loop
  -- Organization gets added to user_organizations array
end loop;
```

### Practical Examples

#### Example 1: Partial Approval Makes Membership Active

```javascript
// CIN admin approves only one privilege
const { data: result } = await supabase.rpc('approve_organization_privileges', {
  target_organization_id: 'org-uuid',
  privilege_types: ['mobilizing_partners']  // Only approve this one
})
```

**Database state after approval:**
```sql
-- admin_memberships table
admin_id: user-uuid
organization_id: org-uuid  
status: 'active'  -- ✅ Changed from 'pending' to 'active'

-- organization_permissions table
org-uuid | mobilizing_partners | approved  -- ✅ Approved
org-uuid | mission_partners    | pending   -- ❌ Still pending
org-uuid | reward_partners     | pending   -- ❌ Still pending
```

**Resulting JWT token:**
```json
{
  "user_organizations": [
    {
      "id": "org-uuid",
      "name": "Organization Name", 
      "membership_status": "active",
      "privileges": [
        {"type": "mobilizing_partners", "status": "approved"},
        {"type": "mission_partners", "status": "pending"},
        {"type": "reward_partners", "status": "pending"}
      ]
    }
  ]
}
```

#### Example 2: No Approvals = Still Pending

```javascript
// CIN admin only rejects privileges
const { data: result } = await supabase.rpc('reject_organization_privileges', {
  target_organization_id: 'org-uuid',
  privilege_types: ['mission_partners']
})
```

**Database state after rejection:**
```sql
-- admin_memberships table
admin_id: user-uuid
organization_id: org-uuid  
status: 'pending'  -- ❌ Still pending (no approvals happened)

-- organization_permissions table  
org-uuid | mobilizing_partners | pending   -- ❌ Still pending
org-uuid | mission_partners    | rejected  -- ❌ Rejected
org-uuid | reward_partners     | pending   -- ❌ Still pending
```

**Resulting JWT token:**
```json
{
  "user_organizations": [],  // ❌ Empty because membership still pending
  "active_organization_id": "org-uuid"  // ✅ Still set from admins table
}
```

### Client-Side Detection Patterns

```javascript
// Detect different organization states
const { data: { user } } = await supabase.auth.getUser()
const userOrganizations = user?.user_metadata?.user_organizations || []
const activeOrgId = user?.user_metadata?.active_organization_id

// Organization is fully pending (no approvals yet)
const isFullyPending = !userOrganizations.length && activeOrgId

// Organization has partial approvals  
const hasPartialApprovals = userOrganizations.some(org =>
  org.privileges.some(priv => priv.status === 'pending') &&
  org.privileges.some(priv => priv.status === 'approved')
)

// Organization has rejections
const hasRejections = userOrganizations.some(org =>
  org.privileges.some(priv => priv.status === 'rejected')
)

// Organization is fully approved
const isFullyApproved = userOrganizations.some(org =>
  org.privileges.every(priv => priv.status === 'approved')
)

// Check specific privilege
const hasApprovedPrivilege = (orgId, privilegeType) => {
  const org = userOrganizations.find(o => o.id === orgId)
  return org?.privileges.some(priv => 
    priv.type === privilegeType && priv.status === 'approved'
  ) || false
}
```

### Summary: The Key Rule

> **Any approved privilege = Active membership = Organization appears in JWT**

This design ensures:
1. **Security**: Users can't access organization features until at least something is approved
2. **Flexibility**: Organizations can start with basic permissions and request more later
3. **Transparency**: JWT clearly shows what privileges are approved/pending/rejected