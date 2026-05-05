# POKÉSTOCK INTEL

Private Pokémon card restock intelligence dashboard built with React, Vite, Tailwind, Framer Motion, Notion, and Google Maps.

This is meant to be used as a custom website. Notion is only the hidden database in the background, so you and your buddy do not need to use the Notion page directly.

## Local Setup

```bash
npm install
cp .env.example .env
npm run dev
```

Open `http://127.0.0.1:5173/`.

## Environment

```bash
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_GOOGLE_MAPS_API_KEY=
VITE_DATA_BACKEND=notion

NOTION_API_KEY=
ADMIN_USERNAME=admin
ADMIN_PASSWORD=ilovepokemon!
ADMIN_SESSION_SECRET=
NOTION_STORES_DATA_SOURCE_ID=36cc1686-d59e-4f34-a39a-d01f32a76169
NOTION_RESTOCK_LOGS_DATA_SOURCE_ID=4aa22836-ee97-4d7b-b9ed-c123ed8fb262
NOTION_INTEL_NOTES_DATA_SOURCE_ID=9546d7f1-1d93-41bf-9aa0-8a52954a52a5
NOTION_INVENTORY_DATA_SOURCE_ID=ae2b04f9-c641-4d3c-a6cb-e3662489937f
```

Without these values, the app runs in local demo mode using browser storage.

## Notion Mode

The Notion workspace has already been created here:

https://www.notion.so/3576147e9367813bb782eff02111f58b

Created data sources:

- Stores: `36cc1686-d59e-4f34-a39a-d01f32a76169`
- Restock Logs: `4aa22836-ee97-4d7b-b9ed-c123ed8fb262`
- Intel Notes: `9546d7f1-1d93-41bf-9aa0-8a52954a52a5`
- Inventory: `ae2b04f9-c641-4d3c-a6cb-e3662489937f`

To run the deployed website against Notion, set:

```bash
VITE_DATA_BACKEND=notion
NOTION_API_KEY=secret_from_notion_integration
ADMIN_USERNAME=admin
ADMIN_PASSWORD=ilovepokemon!
ADMIN_SESSION_SECRET=random_long_secret_for_signed_sessions
```

Important: `NOTION_API_KEY` must be a server-only environment variable. Do not prefix it with `VITE_`.
`ADMIN_PASSWORD` and `ADMIN_SESSION_SECRET` are server-only too. The browser receives a signed session token after login.

In Notion, share the POKÉSTOCK INTEL page/databases with your Notion integration under `Add connections`.

## Google Maps

Create a Google Cloud API key with Maps JavaScript API enabled, then put it in `VITE_GOOGLE_MAPS_API_KEY`.

Recommended key restrictions:

- Application restriction: HTTP referrers
- Local referrer: `http://127.0.0.1:5173/*`
- Production referrer: your deployed domain
- API restriction: Maps JavaScript API

The app uses:

- Real Google map tiles
- Store markers
- Marker info cards
- Visualization heatmap layer
- Fallback demo map when no key is configured

## Supabase

Run `supabase/schema.sql` in your Supabase SQL editor.

Then add your Supabase project URL and anon key to `.env`. The schema enables row level security and restricts reads/writes to approved member emails only.

Private launch flow:

1. In Supabase Auth, create or invite accounts for you and your buddy.
2. In the SQL editor, add those emails to `app_members`.

```sql
insert into public.app_members (email, role) values
  ('you@example.com', 'owner'),
  ('buddy@example.com', 'member')
on conflict (email) do update set role = excluded.role;
```

The app supports password sign-in and magic links. If an email is not in `app_members`, Supabase policies block all store, note, and restock data.

## Deploy

Vercel is the quickest path:

1. Push this folder to a GitHub repository.
2. Import the repo in Vercel.
3. Set the project root to `pokestock-intel`.
4. Set the framework preset to Vite.
5. Add the three environment variables above.
6. Deploy.

After deployment, add the production URL to your Google Maps API key referrer restrictions.

## Published Website Login

Use the deployed website URL, not the Notion public page.

Default login:

- Name: `admin`
- Password: `ilovepokemon!`

After login, the website can read, add, and delete stores, restock logs, intel notes, and inventory items. Notion stays behind the scenes as storage.
