-- Create a table for public profiles
CREATE TABLE profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  full_name text,
  avatar_url text,
  website text,
  email text,
  phone text,
  address text,
  organization_name text,
  userRole text
);
-- Set up Row Level Security (RLS)
-- See https://supabase.com/docs/guides/auth/row-level-security for more details.
alter table profiles
  enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check ((select auth.uid()) = id);

create policy "Users can update own profile." on profiles
  for update using ((select auth.uid()) = id);

-- This trigger automatically creates a profile entry when a new user signs up via Supabase Auth.
-- See https://supabase.com/docs/guides/auth/managing-user-data#using-triggers for more details.
create function public.handle_new_user()
returns trigger
set search_path = ''
as $$
declare
  user_type text;
begin
  -- Get user type from metadata
  user_role := new.raw_user_meta_data->>'user_role';
  
  -- Insert profile with all relevant fields
  insert into public.profiles (
    id, 
    full_name, 
    avatar_url, 
    email, 
    phone, 
    address, 
    organization_name, 
    userRole
  )
  values (
    new.id, 
    new.raw_user_meta_data->>'full_name', 
    new.raw_user_meta_data->>'avatar_url', 
    new.email,
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'organization_name',
    user_role
  );
  
  -- Assign roles based on metadata
  if user_type = 'org_admin_pending' then
    insert into public.user_roles (user_id, role) values (new.id, 'org_admin_pending');
  elsif user_type = 'cin_admin' then
    insert into public.user_roles (user_id, role) values (new.id, 'cin_admin');
  elsif user_type = 'super_admin' then
    insert into public.user_roles (user_id, role) values (new.id, 'super_admin');
  else
    -- Default role for all other users
    insert into public.user_roles (user_id, role) values (new.id, 'user');
  end if;
  
  return new;
end;
$$ language plpgsql security definer;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Set up Storage!
insert into storage.buckets (id, name)
  values ('avatars', 'avatars');

-- Set up access controls for storage.
-- See https://supabase.com/docs/guides/storage#policy-examples for more details.
create policy "Avatar images are publicly accessible." on storage.objects
  for select using (bucket_id = 'avatars');

create policy "Anyone can upload an avatar." on storage.objects
  for insert with check (bucket_id = 'avatars');