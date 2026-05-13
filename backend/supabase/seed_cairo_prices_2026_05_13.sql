-- Cairo base price seed for TruePrice MVP
-- Generated from scripts/generate_price_seed_sql.py
-- Target schema: products, price_sources, price_observations, price_reference_stats, exchange_rates.
-- Region: cairo; reference window: 30 days; seed batch: cairo_mvp_augmented_2026_05_13.
begin;

insert into products (code, name, default_unit, is_active)
values
  ('apple', 'Apple', 'kg', true),
  ('avocado', 'Avocado', 'kg', true),
  ('banana', 'Banana', 'kg', true),
  ('blueberry', 'Blueberry', 'kg', true),
  ('cherry', 'Cherry', 'kg', true),
  ('cherry_tomato', 'Cherry Tomato', 'kg', true),
  ('dates', 'Dates', 'kg', true),
  ('fruit', 'Fruit', 'kg', true),
  ('grape', 'Grape', 'kg', true),
  ('grapefruit', 'Grapefruit', 'kg', true),
  ('guava', 'Guava', 'kg', true),
  ('kiwi', 'Kiwi', 'kg', true),
  ('lemon', 'Lemon', 'kg', true),
  ('mandarin', 'Mandarin', 'kg', true),
  ('mango', 'Mango', 'kg', true),
  ('orange', 'Orange', 'kg', true),
  ('peach', 'Peach', 'kg', true),
  ('pineapple', 'Pineapple', 'pcs', true),
  ('plum', 'Plum', 'kg', true),
  ('pomegranate', 'Pomegranate', 'kg', true),
  ('rockmelon', 'Cantaloupe', 'kg', true),
  ('strawberry', 'Strawberry', 'kg', true),
  ('tomato', 'Tomato', 'kg', true),
  ('watermelon', 'Watermelon', 'kg', true),
  ('camel_doll', 'Camel Doll', 'pcs', true)
on conflict (code) do update set
  name = excluded.name,
  default_unit = excluded.default_unit,
  is_active = excluded.is_active,
  updated_at = now();


insert into price_sources (source_type, name, url, weight, is_active)
values
  ('web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'https://akhbarelyom.com/news/VideoDisplay/4820176/1/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D9%81%D8%A7%D9%83%D9%87%D8%A9-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-13-%D9%85%D8%A7%D9%8A%D9%88-%D9%81%D9%8A-', 0.5, true),
  ('web', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'https://akhbarelyom.com/news/VideoDisplay/4820173/1/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D8%AE%D8%B6%D8%B1%D9%88%D8%A7%D8%AA-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-13-%D9%85%D8%A7%D9%8A%D9%88-%D9%81%D9%8A', 0.5, true),
  ('web', 'Masrawy Obour market 2026-05-13', 'https://www.masrawy.com/news/news_economy/details/2026/5/13/2987317/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D8%AE%D8%B6%D8%B1%D9%88%D8%A7%D8%AA-%D9%88%D8%A7%D9%84%D9%81%D8%A7%D9%83%D9%87%D8%A9-%D9%81%D9%8A-%D8%B3%D9%88%D9%82-%D8%A7%D9%84%D8%B9%D8%A8%D9%88%D8%B1-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-%D8%A7%D8%B1%D8%AA%D9%81%D8%A7%D8%B9-%D8%A7%D9%84%D8%B7%D9%85%D8%A7%D8%B7%D9%85', 0.5, true),
  ('manual_seed', 'Cairo retail adjustment from Obour wholesale', null, 0.3, true),
  ('web', 'Carrefour Egypt online retail', 'https://www.carrefouregypt.com/mafegy/en/c/FEGY1660000', 0.5, true),
  ('web', 'Talabat Mart Egypt online retail', 'https://www.talabat.com/egypt/talabat-mart', 0.5, true),
  ('web', 'Noon Egypt souvenir retail', 'https://www.noon.com/egypt-en/', 0.5, true),
  ('web', 'Diwan Egypt / PAF Dolls camel retail', 'https://diwanegypt.com/product/camel-doll/', 0.5, true),
  ('government', 'CAPMAS April 2026 CPI context', 'https://www.cbe.org.eg/en/news-publications/news/2026/04/09/14/47/cpi-press-release-march-2026', 0.8, true),
  ('manual_seed', 'MVP sparse-price completion', null, 0.3, true)
on conflict (source_type, name) do update set
  url = excluded.url,
  weight = excluded.weight,
  is_active = excluded.is_active;


insert into price_observations (
  id,
  product_id,
  source_id,
  region_code,
  currency,
  unit,
  quantity,
  total_price_egp,
  unit_price_egp,
  observed_at,
  status,
  confidence_score,
  raw_payload
)
select
  seed_rows.id,
  products.id,
  price_sources.id,
  seed_rows.region_code,
  seed_rows.currency,
  seed_rows.unit,
  seed_rows.quantity,
  seed_rows.total_price_egp,
  seed_rows.unit_price_egp,
  seed_rows.observed_at,
  seed_rows.status,
  seed_rows.confidence_score,
  seed_rows.raw_payload
from (
  values
  ('63fcf840-f303-549e-9b09-8519f3a247ed'::uuid, 'tomato', 'web', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 12.5, 12.5, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الطماطم wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour vegetable wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('55b610ea-4e9c-528b-9994-d99774370d98'::uuid, 'tomato', 'web', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 22.5, 22.5, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الطماطم wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour vegetable wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('275684dc-4072-50c5-9c0a-b88e48d678ec'::uuid, 'tomato', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 18.5, 18.5, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "tomato retail-adjusted low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('fad34cf3-33c1-55b3-8446-bc7e5486169c'::uuid, 'tomato', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 25.0, 25.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.82, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "tomato Masrawy high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('32cc9e75-396d-53db-8b81-3ba41c05993d'::uuid, 'tomato', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 18.75, 37.5, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Balady Tomatoes 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('0f22e5a9-a094-5e64-b47b-311ecfd041b9'::uuid, 'tomato', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 1, 99.99, 99.99, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Grade A Tomato 1 kg", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('259369d4-642f-5c00-97c4-9d26746579cd'::uuid, 'tomato', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 1, 19.95, 19.95, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Khodar.Com Tomato 1kg", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('2c5b2961-266c-5c27-9729-02aca4a0ce24'::uuid, 'cherry_tomato', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.25, 71.95, 287.8, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Mafa Cherry Tomato 250g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('5b08faa5-d1a3-5859-8f96-4e795dc44ee0'::uuid, 'cherry_tomato', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 60.99, 121.98, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Cherry Tomato 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('b08a1a43-a131-5358-b41e-4833328a6f35'::uuid, 'cherry_tomato', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 70.0, 70.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.45, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "local cherry tomato manual retail seed", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('6eeee654-cc9a-5aa5-ae1b-5a903d374f81'::uuid, 'orange', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 10.0, 10.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "برتقال صيفي wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('3f030ee6-4304-5358-9f3d-4d633df815b5'::uuid, 'orange', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 20.0, 20.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "برتقال أبوسرة wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('96c3ba3a-dabd-5127-9c5e-7cd0f64113a2'::uuid, 'orange', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 17.0, 17.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "orange retail-adjusted mid", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('20bae1fd-3ecd-5483-928a-7b56d307dfaf'::uuid, 'orange', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 25.0, 25.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "orange retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('e389863d-f712-52d0-ac10-4b1f8c9fdf32'::uuid, 'lemon', 'web', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 17.0, 17.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الليمون wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour vegetable wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('bc162751-5fe8-51bd-a7c0-04b9cee60254'::uuid, 'lemon', 'web', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 33.0, 33.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الليمون wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour vegetable wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('0f39d8ca-2157-510e-942c-4ced62ba682e'::uuid, 'lemon', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 38.0, 38.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "lemon retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('74204426-94b3-5e54-b240-35d376586447'::uuid, 'lemon', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 28.75, 57.5, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Fresh Source Lemon 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('a047ada2-ed85-5d54-890b-5a5181095e66'::uuid, 'banana', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 25.0, 25.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.82, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "موز بلدي wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('a22af3f3-8de7-5108-90a0-c04933af22c9'::uuid, 'banana', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 35.0, 35.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "banana retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('ce81fa56-57ab-5c5b-ab2d-6f730a0cb28a'::uuid, 'banana', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 27.5, 55.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Balady Bananas 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('56d51d19-0291-5d0c-ab58-3b97b14978e8'::uuid, 'banana', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 1, 45.95, 45.95, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Fresh Source Local Banana 1kg", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('33eda375-b9f2-5add-8555-1c5bec9d869d'::uuid, 'banana', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 1, 130.95, 130.95, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Khodar.Com Imported Banana 1kg", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('08b5173b-e974-5657-b308-6b1b02505fb6'::uuid, 'apple', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 15.0, 15.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "تفاح مصرى wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('744c1c19-dcf7-5f4d-9803-43b79fd8665b'::uuid, 'apple', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 43.0, 43.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "تفاح مصرى wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('a86b0a03-1253-5639-af8a-fa7e385b9cf0'::uuid, 'apple', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 55.0, 110.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Royal Gala Apples 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('ab04e1e7-33ee-543a-913f-dbc8563c0e56'::uuid, 'apple', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 50.0, 100.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Golden Apple Medium 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('ee33cb78-83a9-5ed0-aeb0-416bf550eeda'::uuid, 'apple', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 1, 110.75, 110.75, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Fresh Source Red Apple Imported 1kg", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('74c85922-d081-5af9-b6af-3cf7623fc812'::uuid, 'grape', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 40.0, 40.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "العنب wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('5c54a7ca-5ebc-5a69-add6-d7e00e9e50e3'::uuid, 'grape', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 60.0, 60.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "العنب wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('0d664840-09b6-569a-983c-b908c78a2bec'::uuid, 'grape', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 65.0, 65.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "grape retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('1834b498-2173-5844-adb7-8a46e21418cc'::uuid, 'grape', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 35.0, 35.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.82, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "grape Masrawy low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('f5c62dfd-1bad-5c31-872b-5b282471e5ff'::uuid, 'guava', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 12.0, 12.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الجوافة wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('ba1148fd-850f-57d8-9a2b-41552588e409'::uuid, 'guava', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 34.0, 34.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الجوافة wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('f2ea619e-e360-5302-ae58-2d24982ecffd'::uuid, 'guava', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 39.0, 39.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "guava retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('1b02432a-4a47-5297-b124-6a99e27f7c93'::uuid, 'pomegranate', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 15.0, 15.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الرمان wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('2699d494-da9e-5385-b4c3-3e457414bc6b'::uuid, 'pomegranate', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 35.0, 35.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الرمان wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('cf30d121-a4bc-5a23-8f04-a6f9b4b2af55'::uuid, 'pomegranate', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 40.0, 40.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "pomegranate retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('97bc801e-1e2c-5caa-860a-0be0337a8baa'::uuid, 'strawberry', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 15.0, 15.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الفراولة wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('14f1bc9a-f68d-5130-bdab-f5eb57444045'::uuid, 'strawberry', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 25.0, 25.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الفراولة wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('e07352e0-916e-5197-9eca-2ace527bde7a'::uuid, 'strawberry', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 30.0, 30.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "strawberry retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('406c38df-e252-58a3-81da-df6260035e9a'::uuid, 'strawberry', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.45, 119.95, 266.56, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "My Very Strawberries 450g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('0ffe73f5-951e-5911-9a06-b11c145beda1'::uuid, 'rockmelon', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 9.0, 9.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الكانتلوب wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('f80778a3-bb94-5f2c-b7b1-9e8a21d23de1'::uuid, 'rockmelon', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 18.0, 18.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.82, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "cantaloupe Masrawy high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('9c941c09-1bb4-5344-b4ca-bfa6c898635e'::uuid, 'rockmelon', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 23.0, 23.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "cantaloupe retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('e3390ff6-d89d-5b0a-ae7c-2d7a5e3d3894'::uuid, 'rockmelon', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 2, 74.95, 37.48, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Fresh Source Cantaloupe 2kg", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('b5c957d1-186f-5e7d-a854-7c3e901106a5'::uuid, 'mango', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 20.0, 20.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "مانجو بلدية wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('a9fb0de5-aca1-58fb-8584-097f86cc1f8d'::uuid, 'mango', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 50.0, 50.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "مانجو زبدية wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('5464e369-3c2f-51e9-ab28-58f4bf7df712'::uuid, 'mango', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 55.0, 55.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "mango retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('59d6f081-cd0c-5778-928b-6ec6e4a7c91b'::uuid, 'peach', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 20.0, 20.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.82, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "خوخ بلدي wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('4c0c6505-d2fd-5ca4-9e26-8c637d99c483'::uuid, 'peach', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 40.0, 40.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.82, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "خوخ بلدي wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('0d672060-eff9-5631-acd3-c4ff8d309d39'::uuid, 'peach', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 22.5, 45.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Peach 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('4b03cf24-038c-51ed-acf6-9c504dbde7af'::uuid, 'watermelon', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 7.0, 7.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.68, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "watermelon normalized low from whole fruit", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('01362808-5e74-544f-85f2-82fcc5d8b043'::uuid, 'watermelon', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 10.0, 10.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.68, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "watermelon normalized mid from whole fruit", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('9d3c4717-2944-5c6d-821e-cd3e0b82b988'::uuid, 'watermelon', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 20.0, 20.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.62, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "watermelon retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('09c90854-bf68-5d27-bf87-b6f0ce66112f'::uuid, 'dates', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 24.0, 24.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.72, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "بلح ثلاجة wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('3fe04141-13f3-5fcb-92bc-fd4477a13d1e'::uuid, 'dates', 'web', 'Masrawy Obour market 2026-05-13', 'cairo', 'EGP', 'kg', 1, 30.0, 30.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.72, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "بلح ثلاجة wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Masrawy Obour market 2026-05-13", "source_type": "web"}'::jsonb),
  ('5d145326-789a-5ff0-9f26-3546b33733e3'::uuid, 'dates', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 35.0, 35.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.62, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "dates retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('7a820918-0740-5405-84fc-c3dee9bce22f'::uuid, 'grapefruit', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 9.0, 9.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الجريب فروت wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('585b5676-fda7-5f8e-8715-71a852193028'::uuid, 'grapefruit', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 15.0, 15.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "الجريب فروت wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('9598e771-f30b-5222-8b34-24836977545d'::uuid, 'grapefruit', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 20.0, 20.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "grapefruit retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('4719f114-123b-59d1-a841-b2da60942f4d'::uuid, 'mandarin', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 12.0, 12.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "اليوسفي wholesale low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('5d319afa-b10f-569f-b2c9-a205bc14761c'::uuid, 'mandarin', 'web', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'cairo', 'EGP', 'kg', 1, 22.0, 22.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.78, '{"city": "Cairo", "district": "Obour", "market_name": "Obour Wholesale Market", "original_status": "approved", "raw_product_name": "اليوسفي wholesale high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Akhbarelyom Obour fruit wholesale 2026-05-13", "source_type": "web"}'::jsonb),
  ('a0e71429-0160-50b5-9fc3-148cd2d9a948'::uuid, 'mandarin', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'kg', 1, 27.0, 27.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.66, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "mandarin retail-adjusted high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb),
  ('dd39d36d-dd4b-536c-8827-292222aaa33f'::uuid, 'avocado', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 99.95, 199.9, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Pico Avocado Ripe 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('153f2511-551d-56e8-8de2-dbc3f9b90c66'::uuid, 'avocado', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 124.95, 249.9, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Fresh Source Imported Avocado 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('7db5ab87-3fc0-506b-9f93-243bb91e5520'::uuid, 'avocado', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 115.0, 230.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Imported Avocado 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('138bc889-64d1-54ac-843a-ef7be0e44877'::uuid, 'kiwi', 'web', 'Carrefour Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 84.98, 169.96, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.84, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "Kiwi 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Carrefour Egypt online retail", "source_type": "web"}'::jsonb),
  ('8ec53c42-2fbe-531a-8eaa-98c79c083c11'::uuid, 'kiwi', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.25, 45.95, 183.8, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Khodar.Com Imported Kiwi 250g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('02b8aaca-1777-5f2d-865e-7d5f4d7148b3'::uuid, 'kiwi', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.5, 97.95, 195.9, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Fresh Source Imported Kiwi 500g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('b73dc921-cd37-5084-a457-356cdcf9812f'::uuid, 'blueberry', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.125, 144.95, 1159.6, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "My Very Blueberries 125g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('192b00d7-b528-593d-8eb8-01cf618103e9'::uuid, 'blueberry', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'kg', 0.125, 129.95, 1039.6, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.72, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Hygiene Blueberries 125g", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('a53262fa-8526-5a19-a87f-31b00be35853'::uuid, 'blueberry', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 0.125, 49.99, 399.92, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.42, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "legacy Carrefour blueberry punnet 125g seed", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('866c6d4c-9af3-552a-a2e8-6fd1ffd2d41d'::uuid, 'pineapple', 'web', 'Talabat Mart Egypt online retail', 'cairo', 'EGP', 'pcs', 1, 254.95, 254.95, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.76, '{"city": "Cairo", "district": "Nasr City", "market_name": "Nasr City Online Grocery", "original_status": "approved", "raw_product_name": "Khodar.Com Sweet Pineapple Pc", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Talabat Mart Egypt online retail", "source_type": "web"}'::jsonb),
  ('b651e44e-9391-5c0d-947b-1696b53ece98'::uuid, 'pineapple', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'pcs', 1, 180.0, 180.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.45, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "whole pineapple manual retail seed", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('138351af-6c7c-5642-a73c-4f3a403c6b54'::uuid, 'pineapple', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'pcs', 1, 220.0, 220.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.45, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "whole pineapple manual retail seed high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('570a0ab9-21a5-5ff7-9dcb-5e9e3b879209'::uuid, 'cherry', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 180.0, 180.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.42, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "imported cherry sparse retail seed low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('8227cb15-dd05-5645-9a31-c0a500ac68c1'::uuid, 'cherry', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 220.0, 220.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.42, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "imported cherry sparse retail seed mid", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('c02d98c0-453d-5dad-b8d4-56228f400ec6'::uuid, 'cherry', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 260.0, 260.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.42, '{"city": "Cairo", "district": "Maadi", "market_name": "Maadi Online Grocery", "original_status": "approved", "raw_product_name": "imported cherry sparse retail seed high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('beb26e05-0488-5f26-bcee-393cbd082ce3'::uuid, 'plum', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 180.0, 180.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.42, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "plum sparse retail seed low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('57663b54-857d-5455-944b-b2aad1911caa'::uuid, 'plum', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 190.0, 190.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.42, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "plum sparse retail seed mid", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('1e2fb190-a9c6-5895-93f1-f45a748be615'::uuid, 'plum', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 200.0, 200.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.42, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "plum sparse retail seed high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('c6617fcc-76ab-5f6d-bf74-8564e30c610c'::uuid, 'fruit', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 25.0, 25.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.4, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "generic fruit basket sparse seed low", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('5ac0d88e-7ac1-50f0-93a8-1593547e7d69'::uuid, 'fruit', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 55.0, 55.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.4, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "generic fruit basket sparse seed mid", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('0b6ef8a8-a0c7-5173-b967-96f071db707e'::uuid, 'fruit', 'manual_seed', 'MVP sparse-price completion', 'cairo', 'EGP', 'kg', 1, 90.0, 90.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.4, '{"city": "Cairo", "district": "Downtown Cairo", "market_name": "Downtown Cairo Retail Market", "original_status": "approved", "raw_product_name": "generic fruit basket sparse seed high", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "MVP sparse-price completion", "source_type": "manual_seed"}'::jsonb),
  ('c4fab931-8307-55fa-8855-e8eb676aba17'::uuid, 'camel_doll', 'web', 'Noon Egypt souvenir retail', 'cairo', 'EGP', 'pcs', 1, 684.0, 684.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.72, '{"city": "Cairo", "district": "Giza/Pyramids", "market_name": "Giza Pyramid Souvenir Market", "original_status": "approved", "raw_product_name": "Camel Fur Plush Toy souvenir", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Noon Egypt souvenir retail", "source_type": "web"}'::jsonb),
  ('05c84684-ceb3-59f7-bcc2-fc075d5248ef'::uuid, 'camel_doll', 'web', 'Diwan Egypt / PAF Dolls camel retail', 'cairo', 'EGP', 'pcs', 1, 1100.0, 1100.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.74, '{"city": "Cairo", "district": "Khan el-Khalili", "market_name": "Khan el-Khalili Souvenir Market", "original_status": "approved", "raw_product_name": "Camel Doll PAF Dolls", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Diwan Egypt / PAF Dolls camel retail", "source_type": "web"}'::jsonb),
  ('0439ce5f-b0b6-5d62-ae91-197d57118873'::uuid, 'camel_doll', 'web', 'Noon Egypt souvenir retail', 'cairo', 'EGP', 'pcs', 1, 319.0, 319.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.7, '{"city": "Cairo", "district": "Giza/Pyramids", "market_name": "Giza Pyramid Souvenir Market", "original_status": "approved", "raw_product_name": "Collecta Dromedary Camel figure", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Noon Egypt souvenir retail", "source_type": "web"}'::jsonb),
  ('08f6e0e5-e60e-55dd-8afe-dd95e8eb8177'::uuid, 'camel_doll', 'manual_seed', 'Cairo retail adjustment from Obour wholesale', 'cairo', 'EGP', 'pcs', 1, 250.0, 250.0, '2026-05-13T09:00:00+00:00'::timestamptz, 'accepted', 0.5, '{"city": "Cairo", "district": "Khan el-Khalili", "market_name": "Khan el-Khalili Souvenir Market", "original_status": "approved", "raw_product_name": "small bazaar camel souvenir manual seed", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_name": "Cairo retail adjustment from Obour wholesale", "source_type": "manual_seed"}'::jsonb)
) as seed_rows (
  id,
  product_code,
  source_type,
  source_name,
  region_code,
  currency,
  unit,
  quantity,
  total_price_egp,
  unit_price_egp,
  observed_at,
  status,
  confidence_score,
  raw_payload
)
join products on products.code = seed_rows.product_code
join price_sources
  on price_sources.source_type = seed_rows.source_type
 and price_sources.name = seed_rows.source_name
on conflict (id) do update set
  product_id = excluded.product_id,
  source_id = excluded.source_id,
  region_code = excluded.region_code,
  currency = excluded.currency,
  unit = excluded.unit,
  quantity = excluded.quantity,
  total_price_egp = excluded.total_price_egp,
  unit_price_egp = excluded.unit_price_egp,
  observed_at = excluded.observed_at,
  status = excluded.status,
  confidence_score = excluded.confidence_score,
  raw_payload = excluded.raw_payload;


insert into price_reference_stats (
  id,
  product_id,
  region_code,
  unit,
  window_days,
  stat_date,
  sample_count,
  weighted_avg_price_egp,
  median_price_egp,
  min_price_egp,
  max_price_egp,
  p25_price_egp,
  p75_price_egp,
  stddev_price_egp,
  source_mix
)
select
  seed_rows.id,
  products.id,
  seed_rows.region_code,
  seed_rows.unit,
  seed_rows.window_days,
  seed_rows.stat_date,
  seed_rows.sample_count,
  seed_rows.weighted_avg_price_egp,
  seed_rows.median_price_egp,
  seed_rows.min_price_egp,
  seed_rows.max_price_egp,
  seed_rows.p25_price_egp,
  seed_rows.p75_price_egp,
  seed_rows.stddev_price_egp,
  seed_rows.source_mix
from (
  values
  ('76769d90-01f5-5f76-aa4e-ce8da584796a'::uuid, 'tomato', 'cairo', 'kg', 30, '2026-05-13'::date, 7, 35.62, 22.5, 12.5, 99.99, 19.23, 31.25, 27.98, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 6}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('f0442f2c-0a94-5063-9cc2-ff0f01e8853a'::uuid, 'cherry_tomato', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 186.21, 121.98, 70.0, 287.8, 95.99, 204.89, 92.88, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('3b92dfc3-6d67-533a-a6f6-1ea8d3b3cfe3'::uuid, 'orange', 'cairo', 'kg', 30, '2026-05-13'::date, 4, 17.02, 18.5, 10.0, 25.0, 15.25, 21.25, 5.43, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 2, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('1d22b470-2efe-5e54-b5f2-69d4d1ef0b45'::uuid, 'lemon', 'cairo', 'kg', 30, '2026-05-13'::date, 4, 35.99, 35.5, 17.0, 57.5, 29.0, 42.88, 14.45, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('6e58c774-864f-5342-918e-d2a9bdc03331'::uuid, 'banana', 'cairo', 'kg', 30, '2026-05-13'::date, 5, 60.12, 45.95, 25.0, 130.95, 35.0, 55.0, 37.66, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 4}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('a8d34920-98c8-52d6-91b8-2c9c7e4dbef2'::uuid, 'apple', 'cairo', 'kg', 30, '2026-05-13'::date, 5, 76.45, 100.0, 15.0, 110.75, 43.0, 110.0, 39.37, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"web": 5}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('d3262fb8-c009-57ac-8b36-c0b317462d3f'::uuid, 'grape', 'cairo', 'kg', 30, '2026-05-13'::date, 4, 47.71, 50.0, 35.0, 65.0, 38.75, 61.25, 12.75, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('1aadda86-60e3-51c2-853b-9bf731c5ce16'::uuid, 'guava', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 26.24, 34.0, 12.0, 39.0, 23.0, 36.5, 11.73, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('49029cd5-d7f6-51dc-a6ad-1d1485a28d36'::uuid, 'pomegranate', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 28.04, 35.0, 15.0, 40.0, 25.0, 37.5, 10.8, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('2075bda3-a81a-5837-8a85-3306ae3d07c0'::uuid, 'strawberry', 'cairo', 'kg', 30, '2026-05-13'::date, 4, 90.45, 27.5, 15.0, 266.56, 22.5, 89.14, 105.46, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('58f9e96b-8856-5c81-ab7c-6648d0fd08fc'::uuid, 'rockmelon', 'cairo', 'kg', 30, '2026-05-13'::date, 4, 21.54, 20.5, 9.0, 37.48, 15.75, 26.62, 10.31, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('7a85fee4-90f4-53fd-85a8-c7d30b590124'::uuid, 'mango', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 39.05, 50.0, 20.0, 55.0, 35.0, 52.5, 15.46, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('7517ce32-f15d-56fd-b97f-cdab51bf7618'::uuid, 'peach', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 35.08, 40.0, 20.0, 45.0, 30.0, 42.5, 10.8, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('4ace94b8-c04b-538b-abb0-ffb18dc4153d'::uuid, 'watermelon', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 10.97, 10.0, 7.0, 20.0, 8.5, 15.0, 5.56, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('0d867c71-ab4e-57f5-93c7-65c777467a6b'::uuid, 'dates', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 28.64, 30.0, 24.0, 35.0, 27.0, 32.5, 4.5, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('10bc9e9d-31f2-5685-bb69-4df72d6fac58'::uuid, 'grapefruit', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 13.62, 15.0, 9.0, 20.0, 12.0, 17.5, 4.5, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('5ab70059-c6c1-5416-b4b7-4606b51694f1'::uuid, 'mandarin', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 19.02, 22.0, 12.0, 27.0, 17.0, 24.5, 6.24, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('58c53877-0748-5c82-ac8f-bfa86598856d'::uuid, 'avocado', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 226.72, 230.0, 199.9, 249.9, 214.95, 239.95, 20.55, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('d6f15345-8fe4-5e6d-a3d6-57e40f7df7d1'::uuid, 'kiwi', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 182.77, 183.8, 169.96, 195.9, 176.88, 189.85, 10.6, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('7e87575d-eee0-579b-88e2-d57bfbfa3919'::uuid, 'blueberry', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 999.18, 1039.6, 399.92, 1159.6, 719.76, 1099.6, 333.45, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 2}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('a58933a7-c09c-5f6c-a53c-ac39918e5d0a'::uuid, 'pineapple', 'cairo', 'pcs', 30, '2026-05-13'::date, 3, 232.12, 220.0, 180.0, 254.95, 200.0, 237.47, 30.62, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 2, "web": 1}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('6ef327df-5fa8-542e-aa91-30436f684145'::uuid, 'cherry', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 220.0, 220.0, 180.0, 260.0, 200.0, 240.0, 32.66, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('0b1abc90-f062-5166-a014-db19572ccbd5'::uuid, 'plum', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 190.0, 190.0, 180.0, 200.0, 185.0, 195.0, 8.16, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('bc16a798-311b-51f8-bcd9-f7613e7ee8da'::uuid, 'fruit', 'cairo', 'kg', 30, '2026-05-13'::date, 3, 56.67, 55.0, 25.0, 90.0, 40.0, 72.5, 26.56, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb),
  ('6885cb34-f67b-57d2-9cb1-ed400ff7b073'::uuid, 'camel_doll', 'cairo', 'pcs', 30, '2026-05-13'::date, 4, 652.35, 501.5, 250.0, 1100.0, 301.75, 788.0, 338.37, '{"scope": "cairo_overall", "seed_batch": "cairo_mvp_augmented_2026_05_13", "source_counts": {"manual_seed": 1, "web": 3}, "weight_policy": "source_weight * confidence_score"}'::jsonb)
) as seed_rows (
  id,
  product_code,
  region_code,
  unit,
  window_days,
  stat_date,
  sample_count,
  weighted_avg_price_egp,
  median_price_egp,
  min_price_egp,
  max_price_egp,
  p25_price_egp,
  p75_price_egp,
  stddev_price_egp,
  source_mix
)
join products on products.code = seed_rows.product_code
on conflict (product_id, region_code, unit, window_days, stat_date) do update set
  sample_count = excluded.sample_count,
  weighted_avg_price_egp = excluded.weighted_avg_price_egp,
  median_price_egp = excluded.median_price_egp,
  min_price_egp = excluded.min_price_egp,
  max_price_egp = excluded.max_price_egp,
  p25_price_egp = excluded.p25_price_egp,
  p75_price_egp = excluded.p75_price_egp,
  stddev_price_egp = excluded.stddev_price_egp,
  source_mix = excluded.source_mix;


insert into exchange_rates (base_currency, quote_currency, rate, as_of_date, source)
select 'EGP', 'KRW', 28.1348, '2026-05-13'::date, 'currencyrate.today EGP/KRW 2026-05-13 07:00 UTC'
where not exists (
  select 1 from exchange_rates
  where base_currency = 'EGP'
    and quote_currency = 'KRW'
    and as_of_date = '2026-05-13'::date
);

commit;
