-- Demo purchases to verify community feed + filters quickly.
-- Requires:
-- 1) products/markets seed applied first (0001_products_markets_seed.sql)
-- 2) schema migration 0002_supabase_feature_schema.sql

with product_ref as (
  select code, id
  from public.products
  where code in ('p001', 'p002', 'p003', 'p004', 'p005')
),
market_ref as (
  select name, id
  from public.markets
  where name in (
    'Khan el-Khalili Market',
    'Ataba Market',
    'Imbaba Market'
  )
)
insert into public.purchases (
  auth_user_id,
  client_user_id,
  product_id,
  market_id,
  product_name_override,
  store_name_override,
  location_override,
  unit,
  quantity,
  final_price_egp,
  detected_price_egp,
  image_path,
  created_at
)
values
  (
    null,
    'demo-user-a',
    (select id from product_ref where code = 'p001'),
    (select id from market_ref where name = 'Khan el-Khalili Market'),
    'Grapes',
    'Khan el-Khalili Market',
    'Old Cairo',
    'kg',
    1,
    64.00,
    60.00,
    null,
    now() - interval '3 hour'
  ),
  (
    null,
    'demo-user-b',
    (select id from product_ref where code = 'p002'),
    (select id from market_ref where name = 'Ataba Market'),
    'Tomatoes',
    'Ataba Market',
    'Downtown Cairo',
    'kg',
    1,
    13.50,
    14.00,
    null,
    now() - interval '2 hour'
  ),
  (
    null,
    'demo-user-c',
    (select id from product_ref where code = 'p003'),
    (select id from market_ref where name = 'Imbaba Market'),
    'Cucumbers',
    'Imbaba Market',
    'Imbaba',
    'kg',
    1,
    7.20,
    7.00,
    null,
    now() - interval '1 hour'
  ),
  (
    null,
    'demo-user-d',
    (select id from product_ref where code = 'p004'),
    (select id from market_ref where name = 'Khan el-Khalili Market'),
    'Pomegranate',
    'Khan el-Khalili Market',
    'Old Cairo',
    'pcs',
    1,
    44.00,
    43.00,
    null,
    now() - interval '30 minutes'
  ),
  (
    null,
    'demo-user-e',
    (select id from product_ref where code = 'p005'),
    (select id from market_ref where name = 'Ataba Market'),
    'Lemons',
    'Ataba Market',
    'Downtown Cairo',
    'pcs',
    5,
    19.00,
    18.00,
    null,
    now() - interval '10 minutes'
  );
