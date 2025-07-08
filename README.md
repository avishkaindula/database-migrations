# database-migrations

## Steps

1. Copy .env.example to .env.local
2. Create a new OAuth Application in Github -> Settings -> Developer Settings
3. Put the client secret and client ID in the .env.local file
3. run ``` npm i ``` or ``` pnpm i ```
4. run ``` npx supabase start ``` or ``` pnpm exec supabase start ```
5. run ``` npx supabase db reset``` or ```pnpm exec supabase db reset```