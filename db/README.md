# DB (Supabase/PostgreSQL)

## Scope
- Scan history (private)
- Confirmed purchases + auto community post
- Community feed filters (item/location/store)
- Aggregation/RPC for price reference
- Exchange-rate snapshot table

## Folder Guide
- `migrations`: schema DDL
- `rpc`: stored procedures (e.g., `get_price_reference`)
- `views`: reporting and feed views
- `seeds`: bootstrap data

## Migration Order
1. `migrations/0001_init.sql`
2. `migrations/0002_supabase_feature_schema.sql`

## Supabase Apply (Manual)
Run in Supabase SQL Editor (or Supabase CLI in your own environment):
- `0001_init.sql` -> `0002_supabase_feature_schema.sql`
- `rpc/get_price_reference.sql`
- `views/community_feed_v1.sql`
- optional seed: `seeds/0001_products_markets_seed.sql`
- optional demo feed seed: `seeds/0002_demo_purchases_seed.sql`

## Storage Convention (Community Images)
- bucket: `community-images` (created in migration, currently public for MVP)
- path format: `{auth_user_id_or_client_user_id}/{purchase_id}.jpg`
- store only path in DB (`image_path`), not binary bytes

## Notes
- `community_posts` is generated automatically when a `purchases` row is inserted.
- For current Flutter app compatibility, both `auth_user_id` and `client_user_id` are supported.
- RLS is enabled. For MVP testing without auth, anonymous insert policy is open for `purchases` + storage bucket object writes.
