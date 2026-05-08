-- Public community feed view
-- Filter fields are pre-cached in community_posts for quick search.

create or replace view public.community_feed_v1 as
select
  cp.id,
  cp.purchase_id,
  cp.auth_user_id,
  cp.client_user_id,
  cp.product_id,
  cp.market_id,
  cp.product_name_cache as product_name,
  cp.store_name_cache as store_name,
  cp.location_cache as location_name,
  cp.price_egp,
  cp.image_path,
  cp.created_at
from public.community_posts cp
order by cp.created_at desc;
