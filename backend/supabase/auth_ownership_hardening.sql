begin;

-- Flutter accesses application data only through FastAPI. Keep direct Data API
-- access fail-closed even for authenticated anonymous Supabase users.
alter table public.scan_histories enable row level security;
alter table public.purchases enable row level security;
alter table public.products enable row level security;

revoke all privileges on table public.scan_histories from anon, authenticated;
revoke all privileges on table public.purchases from anon, authenticated;
revoke all privileges on table public.products from anon, authenticated;
revoke all privileges on table public.price_sources from anon, authenticated;
revoke all privileges on table public.price_observations from anon, authenticated;
revoke all privileges on table public.price_reference_stats from anon, authenticated;
revoke all privileges on table public.community_feed_v1 from anon, authenticated;

-- Storage writes are server-mediated as well. Public community images may still
-- be read through the public bucket URL, but client roles cannot mutate objects.
revoke insert, update, delete on table storage.objects from anon, authenticated;

-- The API scopes history reads and writes by the verified Supabase Auth user ID.
create index if not exists scan_histories_owner_created_idx
on public.scan_histories (client_user_id, created_at desc);

create index if not exists purchases_owner_created_idx
on public.purchases (client_user_id, created_at desc);

commit;
