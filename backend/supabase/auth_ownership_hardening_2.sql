-- Follow-up to auth_ownership_hardening.sql: close the tables and policies it
-- missed. The API reaches Supabase with the service role, which bypasses RLS.
alter table public.markets enable row level security;

revoke all privileges on table public.markets from anon, authenticated;
revoke all privileges on table public.community_posts from anon, authenticated;
revoke all privileges on table public.exchange_rates from anon, authenticated;

drop policy if exists purchases_insert_anon_mvp on public.purchases;
drop policy if exists storage_community_images_insert_all on storage.objects;
drop policy if exists storage_community_images_update_all on storage.objects;
