-- Price reference stats for scan price analysis screen.
-- Usage:
-- select * from public.get_price_reference(
--   p_product_id := '...uuid...',
--   p_market_id := null,
--   p_days := 30
-- );

create or replace function public.get_price_reference(
  p_product_id uuid,
  p_market_id uuid default null,
  p_days int default 30
)
returns table (
  avg_price_egp numeric,
  median_price_egp numeric,
  min_price_egp numeric,
  max_price_egp numeric,
  stddev_price_egp numeric,
  sample_count bigint
)
language sql
stable
as $$
  with base as (
    select final_price_egp
    from public.purchases
    where product_id = p_product_id
      and created_at >= (now() - make_interval(days => greatest(p_days, 1)))
      and (p_market_id is null or market_id = p_market_id)
  )
  select
    coalesce(avg(final_price_egp), 0)::numeric(12,2) as avg_price_egp,
    coalesce(percentile_cont(0.5) within group (order by final_price_egp), 0)::numeric(12,2) as median_price_egp,
    coalesce(min(final_price_egp), 0)::numeric(12,2) as min_price_egp,
    coalesce(max(final_price_egp), 0)::numeric(12,2) as max_price_egp,
    coalesce(stddev_samp(final_price_egp), 0)::numeric(12,2) as stddev_price_egp,
    count(*)::bigint as sample_count
  from base;
$$;
