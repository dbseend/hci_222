-- Cairo price seed for TruePrice MVP
-- Generated from scripts/generate_cairo_price_seed.py
-- Assumes the reviewed schema exists: price_sources, product_aliases, price_observations, daily_price_stats.
begin;

with source_rows (name, source_type, url, reliability_score) as (
  values
  ('Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'https://akhbarelyom.com/news/VideoDisplay/4820176/1/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D9%81%D8%A7%D9%83%D9%87%D8%A9-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-13-%D9%85%D8%A7%D9%8A%D9%88-%D9%81%D9%8A-', 0.78),
  ('Akhbarelyom Obour vegetable wholesale 2026-05-13', 'web_scrape', 'https://akhbarelyom.com/news/VideoDisplay/4820173/1/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D8%AE%D8%B6%D8%B1%D9%88%D8%A7%D8%AA-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-13-%D9%85%D8%A7%D9%8A%D9%88-%D9%81%D9%8A', 0.78),
  ('Masrawy Obour market 2026-05-13', 'web_scrape', 'https://www.masrawy.com/news/news_economy/details/2026/5/13/2987317/%D8%A3%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D8%AE%D8%B6%D8%B1%D9%88%D8%A7%D8%AA-%D9%88%D8%A7%D9%84%D9%81%D8%A7%D9%83%D9%87%D8%A9-%D9%81%D9%8A-%D8%B3%D9%88%D9%82-%D8%A7%D9%84%D8%B9%D8%A8%D9%88%D8%B1-%D8%A7%D9%84%D9%8A%D9%88%D9%85-%D8%A7%D9%84%D8%A3%D8%B1%D8%A8%D8%B9%D8%A7%D8%A1-%D8%A7%D8%B1%D8%AA%D9%81%D8%A7%D8%B9-%D8%A7%D9%84%D8%B7%D9%85%D8%A7%D8%B7%D9%85', 0.82),
  ('Cairo retail adjustment from Obour wholesale', 'manual_seed', null, 0.66),
  ('Carrefour Egypt online retail', 'web_scrape', 'https://www.carrefouregypt.com/mafegy/en/c/FEGY1660000', 0.84),
  ('Talabat Mart Egypt online retail', 'web_scrape', 'https://www.talabat.com/egypt/talabat-mart', 0.76),
  ('Noon Egypt souvenir retail', 'web_scrape', 'https://www.noon.com/egypt-en/', 0.72),
  ('Diwan Egypt / PAF Dolls camel retail', 'web_scrape', 'https://diwanegypt.com/product/camel-doll/', 0.74),
  ('CAPMAS April 2026 CPI context', 'government', 'https://www.cbe.org.eg/en/news-publications/news/2026/04/09/14/47/cpi-press-release-march-2026', 0.9),
  ('MVP sparse-price completion', 'manual_seed', null, 0.45)
)
insert into price_sources (name, source_type, url, reliability_score)
select sr.name, sr.source_type, sr.url, sr.reliability_score
from source_rows sr
where not exists (
  select 1 from price_sources ps where ps.name = sr.name
);

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
on conflict (code) do update set name = excluded.name, default_unit = excluded.default_unit, is_active = true, updated_at = now();

with alias_rows (product_code, alias, locale, source) as (
  values
  ('apple', 'apple', 'en', 'product_catalog'),
  ('apple', 'apples', 'en', 'product_catalog'),
  ('apple', 'golden apple', 'en', 'product_catalog'),
  ('apple', 'green apple', 'en', 'product_catalog'),
  ('apple', 'red apple', 'en', 'product_catalog'),
  ('apple', 'royal gala apple', 'en', 'product_catalog'),
  ('apple', 'تفاح', 'ar', 'seed_2026_05_13'),
  ('apple', 'تفاح مصري', 'ar', 'seed_2026_05_13'),
  ('apple', 'تفاح مستورد', 'ar', 'seed_2026_05_13'),
  ('avocado', 'avocado', 'en', 'product_catalog'),
  ('avocado', 'avocados', 'en', 'product_catalog'),
  ('avocado', 'imported avocado', 'en', 'product_catalog'),
  ('avocado', 'أفوكادو', 'ar', 'seed_2026_05_13'),
  ('banana', 'banana', 'en', 'product_catalog'),
  ('banana', 'bananas', 'en', 'product_catalog'),
  ('banana', 'balady banana', 'en', 'product_catalog'),
  ('banana', 'imported banana', 'en', 'product_catalog'),
  ('banana', 'موز', 'ar', 'seed_2026_05_13'),
  ('banana', 'موز بلدي', 'ar', 'seed_2026_05_13'),
  ('banana', 'موز مستورد', 'ar', 'seed_2026_05_13'),
  ('blueberry', 'blueberry', 'en', 'product_catalog'),
  ('blueberry', 'blueberries', 'en', 'product_catalog'),
  ('blueberry', 'blueberry punnet', 'en', 'product_catalog'),
  ('blueberry', 'توت أزرق', 'ar', 'seed_2026_05_13'),
  ('blueberry', 'بلوبيري', 'ar', 'seed_2026_05_13'),
  ('cherry', 'cherry', 'en', 'product_catalog'),
  ('cherry', 'cherries', 'en', 'product_catalog'),
  ('cherry_tomato', 'cherry tomato', 'en', 'product_catalog'),
  ('cherry_tomato', 'cherry tomatoes', 'en', 'product_catalog'),
  ('cherry_tomato', 'grape tomato', 'en', 'product_catalog'),
  ('cherry_tomato', 'grape tomatoes', 'en', 'product_catalog'),
  ('cherry_tomato', 'طماطم شيري', 'ar', 'seed_2026_05_13'),
  ('dates', 'dates', 'en', 'product_catalog'),
  ('dates', 'fresh dates', 'en', 'product_catalog'),
  ('dates', 'zaghloul dates', 'en', 'product_catalog'),
  ('dates', 'medjool dates', 'en', 'product_catalog'),
  ('dates', 'بلح', 'ar', 'seed_2026_05_13'),
  ('dates', 'تمر', 'ar', 'seed_2026_05_13'),
  ('fruit', 'fruit', 'en', 'product_catalog'),
  ('fruit', 'fruits', 'en', 'product_catalog'),
  ('fruit', 'mixed fruit', 'en', 'product_catalog'),
  ('grape', 'grape', 'en', 'product_catalog'),
  ('grape', 'grapes', 'en', 'product_catalog'),
  ('grape', 'red grape', 'en', 'product_catalog'),
  ('grape', 'red grapes', 'en', 'product_catalog'),
  ('grape', 'white grape', 'en', 'product_catalog'),
  ('grape', 'white grapes', 'en', 'product_catalog'),
  ('grape', 'black grape', 'en', 'product_catalog'),
  ('grape', 'black grapes', 'en', 'product_catalog'),
  ('grape', 'عنب', 'ar', 'seed_2026_05_13'),
  ('grape', 'عنب أحمر', 'ar', 'seed_2026_05_13'),
  ('grape', 'عنب بناتي', 'ar', 'seed_2026_05_13'),
  ('grapefruit', 'grapefruit', 'en', 'product_catalog'),
  ('grapefruit', 'grapefruits', 'en', 'product_catalog'),
  ('grapefruit', 'pink grapefruit', 'en', 'product_catalog'),
  ('grapefruit', 'جريب فروت', 'ar', 'seed_2026_05_13'),
  ('guava', 'guava', 'en', 'product_catalog'),
  ('guava', 'guavas', 'en', 'product_catalog'),
  ('guava', 'جوافة', 'ar', 'seed_2026_05_13'),
  ('kiwi', 'kiwi', 'en', 'product_catalog'),
  ('kiwi', 'kiwis', 'en', 'product_catalog'),
  ('kiwi', 'kiwi fruit', 'en', 'product_catalog'),
  ('kiwi', 'كيوي', 'ar', 'seed_2026_05_13'),
  ('lemon', 'lemon', 'en', 'product_catalog'),
  ('lemon', 'lemons', 'en', 'product_catalog'),
  ('lemon', 'balady lemon', 'en', 'product_catalog'),
  ('lemon', 'adalia lemon', 'en', 'product_catalog'),
  ('lemon', 'ليمون', 'ar', 'seed_2026_05_13'),
  ('lemon', 'ليمون بلدي', 'ar', 'seed_2026_05_13'),
  ('mandarin', 'mandarin', 'en', 'product_catalog'),
  ('mandarin', 'mandarins', 'en', 'product_catalog'),
  ('mandarin', 'tangerine', 'en', 'product_catalog'),
  ('mandarin', 'tangerines', 'en', 'product_catalog'),
  ('mandarin', 'clementine', 'en', 'product_catalog'),
  ('mandarin', 'clementines', 'en', 'product_catalog'),
  ('mandarin', 'يوسفي', 'ar', 'seed_2026_05_13'),
  ('mango', 'mango', 'en', 'product_catalog'),
  ('mango', 'mangoes', 'en', 'product_catalog'),
  ('mango', 'zebda mango', 'en', 'product_catalog'),
  ('mango', 'balady mango', 'en', 'product_catalog'),
  ('mango', 'sedika mango', 'en', 'product_catalog'),
  ('mango', 'مانجو', 'ar', 'seed_2026_05_13'),
  ('mango', 'مانجو بلدي', 'ar', 'seed_2026_05_13'),
  ('mango', 'مانجو زبدية', 'ar', 'seed_2026_05_13'),
  ('orange', 'orange', 'en', 'product_catalog'),
  ('orange', 'oranges', 'en', 'product_catalog'),
  ('orange', 'navel orange', 'en', 'product_catalog'),
  ('orange', 'summer orange', 'en', 'product_catalog'),
  ('orange', 'juice orange', 'en', 'product_catalog'),
  ('orange', 'برتقال', 'ar', 'seed_2026_05_13'),
  ('orange', 'برتقال صيفي', 'ar', 'seed_2026_05_13'),
  ('orange', 'برتقال أبو سرة', 'ar', 'seed_2026_05_13'),
  ('peach', 'peach', 'en', 'product_catalog'),
  ('peach', 'peaches', 'en', 'product_catalog'),
  ('peach', 'balady peach', 'en', 'product_catalog'),
  ('peach', 'sokari peach', 'en', 'product_catalog'),
  ('peach', 'خوخ', 'ar', 'seed_2026_05_13'),
  ('pineapple', 'pineapple', 'en', 'product_catalog'),
  ('pineapple', 'pineapples', 'en', 'product_catalog'),
  ('pineapple', 'whole pineapple', 'en', 'product_catalog'),
  ('pineapple', 'أناناس', 'ar', 'seed_2026_05_13'),
  ('plum', 'plum', 'en', 'product_catalog'),
  ('plum', 'plums', 'en', 'product_catalog'),
  ('plum', 'red plum', 'en', 'product_catalog'),
  ('plum', 'hollywood plum', 'en', 'product_catalog'),
  ('pomegranate', 'pomegranate', 'en', 'product_catalog'),
  ('pomegranate', 'pomegranates', 'en', 'product_catalog'),
  ('pomegranate', 'رمان', 'ar', 'seed_2026_05_13'),
  ('rockmelon', 'rockmelon', 'en', 'product_catalog'),
  ('rockmelon', 'melon', 'en', 'product_catalog'),
  ('rockmelon', 'cantaloupe', 'en', 'product_catalog'),
  ('rockmelon', 'sweet melon', 'en', 'product_catalog'),
  ('rockmelon', 'كنتالوب', 'ar', 'seed_2026_05_13'),
  ('rockmelon', 'شمام', 'ar', 'seed_2026_05_13'),
  ('strawberry', 'strawberry', 'en', 'product_catalog'),
  ('strawberry', 'strawberries', 'en', 'product_catalog'),
  ('strawberry', 'فراولة', 'ar', 'seed_2026_05_13'),
  ('tomato', 'tomato', 'en', 'product_catalog'),
  ('tomato', 'tomatoes', 'en', 'product_catalog'),
  ('tomato', 'tomatoes_single', 'en', 'product_catalog'),
  ('tomato', 'balady tomato', 'en', 'product_catalog'),
  ('tomato', 'طماطم', 'ar', 'seed_2026_05_13'),
  ('tomato', 'بندورة', 'ar', 'seed_2026_05_13'),
  ('watermelon', 'watermelon', 'en', 'product_catalog'),
  ('watermelon', 'watermelons', 'en', 'product_catalog'),
  ('watermelon', 'بطيخ', 'ar', 'seed_2026_05_13'),
  ('camel_doll', 'camel doll', 'en', 'product_catalog'),
  ('camel_doll', 'camel souvenir', 'en', 'product_catalog'),
  ('camel_doll', 'camel ornament', 'en', 'product_catalog'),
  ('camel_doll', 'جمل لعبة', 'ar', 'seed_2026_05_13'),
  ('camel_doll', 'دمية جمل', 'ar', 'seed_2026_05_13'),
  ('camel_doll', 'تذكار جمل', 'ar', 'seed_2026_05_13')
)
insert into product_aliases (product_id, alias, locale, source)
select p.id, ar.alias, ar.locale, ar.source
from alias_rows ar
join products p on p.code = ar.product_code
on conflict (product_id, alias) do nothing;

insert into markets (name, company_name, country_code, city, district, lat, lng, is_active)
values
  ('Obour Wholesale Market', 'Obour Market', 'EG', 'Cairo', 'Obour', 30.229, 31.476, true),
  ('Downtown Cairo Retail Market', null, 'EG', 'Cairo', 'Downtown Cairo', 30.0444, 31.2357, true),
  ('Maadi Online Grocery', 'Online Grocery', 'EG', 'Cairo', 'Maadi', 29.9602, 31.2569, true),
  ('Nasr City Online Grocery', 'Online Grocery', 'EG', 'Cairo', 'Nasr City', 30.0561, 31.33, true),
  ('Khan el-Khalili Souvenir Market', null, 'EG', 'Cairo', 'Khan el-Khalili', 30.0478, 31.2625, true),
  ('Giza Pyramid Souvenir Market', null, 'EG', 'Cairo', 'Giza/Pyramids', 29.9792, 31.1342, true)
on conflict (name) do update set company_name = excluded.company_name, country_code = excluded.country_code, city = excluded.city, district = excluded.district, lat = excluded.lat, lng = excluded.lng, is_active = true, updated_at = now();

with observation_rows (product_code, market_name, source_name, source_type, city, district, unit, quantity, total_price_egp, observed_at, verification_status, confidence_score, raw_product_name, raw_payload) as (
  values
  ('tomato', 'Obour Wholesale Market', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 12.5, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الطماطم wholesale low', '{}'::jsonb),
  ('tomato', 'Obour Wholesale Market', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 22.5, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الطماطم wholesale high', '{}'::jsonb),
  ('tomato', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 18.5, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'tomato retail-adjusted low', '{}'::jsonb),
  ('tomato', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 25.0, '2026-05-13T09:00:00+00:00', 'approved', 0.82, 'tomato Masrawy high', '{}'::jsonb),
  ('tomato', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 18.75, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Balady Tomatoes 500g', '{}'::jsonb),
  ('tomato', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 1, 99.99, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Grade A Tomato 1 kg', '{}'::jsonb),
  ('tomato', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 1, 19.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Khodar.Com Tomato 1kg', '{}'::jsonb),
  ('cherry_tomato', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.25, 71.95, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Mafa Cherry Tomato 250g', '{}'::jsonb),
  ('cherry_tomato', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 60.99, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Cherry Tomato 500g', '{}'::jsonb),
  ('cherry_tomato', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 70.0, '2026-05-13T09:00:00+00:00', 'approved', 0.45, 'local cherry tomato manual retail seed', '{}'::jsonb),
  ('orange', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 10.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'برتقال صيفي wholesale low', '{}'::jsonb),
  ('orange', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 20.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'برتقال أبوسرة wholesale high', '{}'::jsonb),
  ('orange', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 17.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'orange retail-adjusted mid', '{}'::jsonb),
  ('orange', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 25.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'orange retail-adjusted high', '{}'::jsonb),
  ('lemon', 'Obour Wholesale Market', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 17.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الليمون wholesale low', '{}'::jsonb),
  ('lemon', 'Obour Wholesale Market', 'Akhbarelyom Obour vegetable wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 33.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الليمون wholesale high', '{}'::jsonb),
  ('lemon', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 38.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'lemon retail-adjusted high', '{}'::jsonb),
  ('lemon', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.5, 28.75, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Fresh Source Lemon 500g', '{}'::jsonb),
  ('banana', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 25.0, '2026-05-13T09:00:00+00:00', 'approved', 0.82, 'موز بلدي wholesale low', '{}'::jsonb),
  ('banana', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 35.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'banana retail-adjusted high', '{}'::jsonb),
  ('banana', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 27.5, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Balady Bananas 500g', '{}'::jsonb),
  ('banana', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 1, 45.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Fresh Source Local Banana 1kg', '{}'::jsonb),
  ('banana', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 1, 130.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Khodar.Com Imported Banana 1kg', '{}'::jsonb),
  ('apple', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 15.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'تفاح مصرى wholesale low', '{}'::jsonb),
  ('apple', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 43.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'تفاح مصرى wholesale high', '{}'::jsonb),
  ('apple', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 55.0, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Royal Gala Apples 500g', '{}'::jsonb),
  ('apple', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 50.0, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Golden Apple Medium 500g', '{}'::jsonb),
  ('apple', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 1, 110.75, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Fresh Source Red Apple Imported 1kg', '{}'::jsonb),
  ('grape', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 40.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'العنب wholesale low', '{}'::jsonb),
  ('grape', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 60.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'العنب wholesale high', '{}'::jsonb),
  ('grape', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 65.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'grape retail-adjusted high', '{}'::jsonb),
  ('grape', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 35.0, '2026-05-13T09:00:00+00:00', 'approved', 0.82, 'grape Masrawy low', '{}'::jsonb),
  ('guava', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 12.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الجوافة wholesale low', '{}'::jsonb),
  ('guava', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 34.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الجوافة wholesale high', '{}'::jsonb),
  ('guava', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 39.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'guava retail-adjusted high', '{}'::jsonb),
  ('pomegranate', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 15.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الرمان wholesale low', '{}'::jsonb),
  ('pomegranate', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 35.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الرمان wholesale high', '{}'::jsonb),
  ('pomegranate', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 40.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'pomegranate retail-adjusted high', '{}'::jsonb),
  ('strawberry', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 15.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الفراولة wholesale low', '{}'::jsonb),
  ('strawberry', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 25.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الفراولة wholesale high', '{}'::jsonb),
  ('strawberry', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 30.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'strawberry retail-adjusted high', '{}'::jsonb),
  ('strawberry', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.45, 119.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'My Very Strawberries 450g', '{}'::jsonb),
  ('rockmelon', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 9.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الكانتلوب wholesale low', '{}'::jsonb),
  ('rockmelon', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 18.0, '2026-05-13T09:00:00+00:00', 'approved', 0.82, 'cantaloupe Masrawy high', '{}'::jsonb),
  ('rockmelon', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 23.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'cantaloupe retail-adjusted high', '{}'::jsonb),
  ('rockmelon', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 2, 74.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Fresh Source Cantaloupe 2kg', '{}'::jsonb),
  ('mango', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 20.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'مانجو بلدية wholesale low', '{}'::jsonb),
  ('mango', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 50.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'مانجو زبدية wholesale high', '{}'::jsonb),
  ('mango', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 55.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'mango retail-adjusted high', '{}'::jsonb),
  ('peach', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 20.0, '2026-05-13T09:00:00+00:00', 'approved', 0.82, 'خوخ بلدي wholesale low', '{}'::jsonb),
  ('peach', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 40.0, '2026-05-13T09:00:00+00:00', 'approved', 0.82, 'خوخ بلدي wholesale high', '{}'::jsonb),
  ('peach', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 22.5, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Peach 500g', '{}'::jsonb),
  ('watermelon', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 7.0, '2026-05-13T09:00:00+00:00', 'approved', 0.68, 'watermelon normalized low from whole fruit', '{}'::jsonb),
  ('watermelon', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 10.0, '2026-05-13T09:00:00+00:00', 'approved', 0.68, 'watermelon normalized mid from whole fruit', '{}'::jsonb),
  ('watermelon', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 20.0, '2026-05-13T09:00:00+00:00', 'approved', 0.62, 'watermelon retail-adjusted high', '{}'::jsonb),
  ('dates', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 24.0, '2026-05-13T09:00:00+00:00', 'approved', 0.72, 'بلح ثلاجة wholesale low', '{}'::jsonb),
  ('dates', 'Obour Wholesale Market', 'Masrawy Obour market 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 30.0, '2026-05-13T09:00:00+00:00', 'approved', 0.72, 'بلح ثلاجة wholesale high', '{}'::jsonb),
  ('dates', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 35.0, '2026-05-13T09:00:00+00:00', 'approved', 0.62, 'dates retail-adjusted high', '{}'::jsonb),
  ('grapefruit', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 9.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الجريب فروت wholesale low', '{}'::jsonb),
  ('grapefruit', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 15.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'الجريب فروت wholesale high', '{}'::jsonb),
  ('grapefruit', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 20.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'grapefruit retail-adjusted high', '{}'::jsonb),
  ('mandarin', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 12.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'اليوسفي wholesale low', '{}'::jsonb),
  ('mandarin', 'Obour Wholesale Market', 'Akhbarelyom Obour fruit wholesale 2026-05-13', 'web_scrape', 'Cairo', 'Obour', 'kg', 1, 22.0, '2026-05-13T09:00:00+00:00', 'approved', 0.78, 'اليوسفي wholesale high', '{}'::jsonb),
  ('mandarin', 'Downtown Cairo Retail Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 27.0, '2026-05-13T09:00:00+00:00', 'approved', 0.66, 'mandarin retail-adjusted high', '{}'::jsonb),
  ('avocado', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.5, 99.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Pico Avocado Ripe 500g', '{}'::jsonb),
  ('avocado', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.5, 124.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Fresh Source Imported Avocado 500g', '{}'::jsonb),
  ('avocado', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 115.0, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Imported Avocado 500g', '{}'::jsonb),
  ('kiwi', 'Maadi Online Grocery', 'Carrefour Egypt online retail', 'web_scrape', 'Cairo', 'Maadi', 'kg', 0.5, 84.98, '2026-05-13T09:00:00+00:00', 'approved', 0.84, 'Kiwi 500g', '{}'::jsonb),
  ('kiwi', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.25, 45.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Khodar.Com Imported Kiwi 250g', '{}'::jsonb),
  ('kiwi', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.5, 97.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Fresh Source Imported Kiwi 500g', '{}'::jsonb),
  ('blueberry', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.125, 144.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'My Very Blueberries 125g', '{}'::jsonb),
  ('blueberry', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'kg', 0.125, 129.95, '2026-05-13T09:00:00+00:00', 'approved', 0.72, 'Hygiene Blueberries 125g', '{}'::jsonb),
  ('blueberry', 'Maadi Online Grocery', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Maadi', 'kg', 0.125, 49.99, '2026-05-13T09:00:00+00:00', 'approved', 0.42, 'legacy Carrefour blueberry punnet 125g seed', '{}'::jsonb),
  ('pineapple', 'Nasr City Online Grocery', 'Talabat Mart Egypt online retail', 'web_scrape', 'Cairo', 'Nasr City', 'pcs', 1, 254.95, '2026-05-13T09:00:00+00:00', 'approved', 0.76, 'Khodar.Com Sweet Pineapple Pc', '{}'::jsonb),
  ('pineapple', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'pcs', 1, 180.0, '2026-05-13T09:00:00+00:00', 'approved', 0.45, 'whole pineapple manual retail seed', '{}'::jsonb),
  ('pineapple', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'pcs', 1, 220.0, '2026-05-13T09:00:00+00:00', 'approved', 0.45, 'whole pineapple manual retail seed high', '{}'::jsonb),
  ('cherry', 'Maadi Online Grocery', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Maadi', 'kg', 1, 180.0, '2026-05-13T09:00:00+00:00', 'approved', 0.42, 'imported cherry sparse retail seed low', '{}'::jsonb),
  ('cherry', 'Maadi Online Grocery', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Maadi', 'kg', 1, 220.0, '2026-05-13T09:00:00+00:00', 'approved', 0.42, 'imported cherry sparse retail seed mid', '{}'::jsonb),
  ('cherry', 'Maadi Online Grocery', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Maadi', 'kg', 1, 260.0, '2026-05-13T09:00:00+00:00', 'approved', 0.42, 'imported cherry sparse retail seed high', '{}'::jsonb),
  ('plum', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 180.0, '2026-05-13T09:00:00+00:00', 'approved', 0.42, 'plum sparse retail seed low', '{}'::jsonb),
  ('plum', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 190.0, '2026-05-13T09:00:00+00:00', 'approved', 0.42, 'plum sparse retail seed mid', '{}'::jsonb),
  ('plum', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 200.0, '2026-05-13T09:00:00+00:00', 'approved', 0.42, 'plum sparse retail seed high', '{}'::jsonb),
  ('fruit', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 25.0, '2026-05-13T09:00:00+00:00', 'approved', 0.4, 'generic fruit basket sparse seed low', '{}'::jsonb),
  ('fruit', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 55.0, '2026-05-13T09:00:00+00:00', 'approved', 0.4, 'generic fruit basket sparse seed mid', '{}'::jsonb),
  ('fruit', 'Downtown Cairo Retail Market', 'MVP sparse-price completion', 'manual_seed', 'Cairo', 'Downtown Cairo', 'kg', 1, 90.0, '2026-05-13T09:00:00+00:00', 'approved', 0.4, 'generic fruit basket sparse seed high', '{}'::jsonb),
  ('camel_doll', 'Giza Pyramid Souvenir Market', 'Noon Egypt souvenir retail', 'web_scrape', 'Cairo', 'Giza/Pyramids', 'pcs', 1, 684.0, '2026-05-13T09:00:00+00:00', 'approved', 0.72, 'Camel Fur Plush Toy souvenir', '{}'::jsonb),
  ('camel_doll', 'Khan el-Khalili Souvenir Market', 'Diwan Egypt / PAF Dolls camel retail', 'web_scrape', 'Cairo', 'Khan el-Khalili', 'pcs', 1, 1100.0, '2026-05-13T09:00:00+00:00', 'approved', 0.74, 'Camel Doll PAF Dolls', '{}'::jsonb),
  ('camel_doll', 'Giza Pyramid Souvenir Market', 'Noon Egypt souvenir retail', 'web_scrape', 'Cairo', 'Giza/Pyramids', 'pcs', 1, 319.0, '2026-05-13T09:00:00+00:00', 'approved', 0.7, 'Collecta Dromedary Camel figure', '{}'::jsonb),
  ('camel_doll', 'Khan el-Khalili Souvenir Market', 'Cairo retail adjustment from Obour wholesale', 'manual_seed', 'Cairo', 'Khan el-Khalili', 'pcs', 1, 250.0, '2026-05-13T09:00:00+00:00', 'approved', 0.5, 'small bazaar camel souvenir manual seed', '{}'::jsonb)
)
insert into price_observations (product_id, market_id, source_id, source_type, city, district, unit, quantity, total_price_egp, observed_at, verification_status, confidence_score, raw_product_name, raw_payload)
select p.id, m.id, s.id, r.source_type, r.city, r.district, r.unit, r.quantity, r.total_price_egp, r.observed_at::timestamptz, r.verification_status, r.confidence_score, r.raw_product_name, r.raw_payload
from observation_rows r
join products p on p.code = r.product_code
left join markets m on m.name = r.market_name
left join (select distinct on (name) id, name from price_sources order by name, created_at asc) s on s.name = r.source_name
where not exists (
  select 1 from price_observations po
  where po.product_id = p.id
    and coalesce(po.market_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(m.id, '00000000-0000-0000-0000-000000000000'::uuid)
    and po.source_id = s.id
    and po.unit = r.unit
    and po.quantity = r.quantity
    and po.total_price_egp = r.total_price_egp
    and po.observed_at = r.observed_at::timestamptz
);

with stat_rows (stat_date, product_code, city, district, unit, currency, avg_price, median_price, min_price, max_price, stddev_price, p10_price, p90_price, sample_count, distribution) as (
  values
  ('2026-05-13', 'apple', 'Cairo', null, 'kg', 'EGP', 75.75, 100.0, 15.0, 110.75, 39.37, 15.0, 110.75, 5, '[{"bucket_end": 26.97, "bucket_start": 15.0, "count": 1}, {"bucket_end": 38.94, "bucket_start": 26.97, "count": 0}, {"bucket_end": 50.91, "bucket_start": 38.94, "count": 1}, {"bucket_end": 62.88, "bucket_start": 50.91, "count": 0}, {"bucket_end": 74.84, "bucket_start": 62.88, "count": 0}, {"bucket_end": 86.81, "bucket_start": 74.84, "count": 0}, {"bucket_end": 98.78, "bucket_start": 86.81, "count": 0}, {"bucket_end": 110.75, "bucket_start": 98.78, "count": 3}]'::jsonb),
  ('2026-05-13', 'avocado', 'Cairo', null, 'kg', 'EGP', 226.6, 230.0, 199.9, 249.9, 20.55, 199.9, 249.9, 3, '[{"bucket_end": 206.15, "bucket_start": 199.9, "count": 1}, {"bucket_end": 212.4, "bucket_start": 206.15, "count": 0}, {"bucket_end": 218.65, "bucket_start": 212.4, "count": 0}, {"bucket_end": 224.9, "bucket_start": 218.65, "count": 0}, {"bucket_end": 231.15, "bucket_start": 224.9, "count": 1}, {"bucket_end": 237.4, "bucket_start": 231.15, "count": 0}, {"bucket_end": 243.65, "bucket_start": 237.4, "count": 0}, {"bucket_end": 249.9, "bucket_start": 243.65, "count": 1}]'::jsonb),
  ('2026-05-13', 'banana', 'Cairo', null, 'kg', 'EGP', 58.38, 45.95, 25.0, 130.95, 37.66, 25.0, 130.95, 5, '[{"bucket_end": 38.24, "bucket_start": 25.0, "count": 2}, {"bucket_end": 51.49, "bucket_start": 38.24, "count": 1}, {"bucket_end": 64.73, "bucket_start": 51.49, "count": 1}, {"bucket_end": 77.97, "bucket_start": 64.73, "count": 0}, {"bucket_end": 91.22, "bucket_start": 77.97, "count": 0}, {"bucket_end": 104.46, "bucket_start": 91.22, "count": 0}, {"bucket_end": 117.71, "bucket_start": 104.46, "count": 0}, {"bucket_end": 130.95, "bucket_start": 117.71, "count": 1}]'::jsonb),
  ('2026-05-13', 'blueberry', 'Cairo', null, 'kg', 'EGP', 866.37, 1039.6, 399.92, 1159.6, 333.45, 399.92, 1159.6, 3, '[{"bucket_end": 494.88, "bucket_start": 399.92, "count": 1}, {"bucket_end": 589.84, "bucket_start": 494.88, "count": 0}, {"bucket_end": 684.8, "bucket_start": 589.84, "count": 0}, {"bucket_end": 779.76, "bucket_start": 684.8, "count": 0}, {"bucket_end": 874.72, "bucket_start": 779.76, "count": 0}, {"bucket_end": 969.68, "bucket_start": 874.72, "count": 0}, {"bucket_end": 1064.64, "bucket_start": 969.68, "count": 1}, {"bucket_end": 1159.6, "bucket_start": 1064.64, "count": 1}]'::jsonb),
  ('2026-05-13', 'camel_doll', 'Cairo', null, 'pcs', 'EGP', 588.25, 501.5, 250.0, 1100.0, 338.37, 250.0, 1100.0, 4, '[{"bucket_end": 356.25, "bucket_start": 250.0, "count": 2}, {"bucket_end": 462.5, "bucket_start": 356.25, "count": 0}, {"bucket_end": 568.75, "bucket_start": 462.5, "count": 0}, {"bucket_end": 675.0, "bucket_start": 568.75, "count": 0}, {"bucket_end": 781.25, "bucket_start": 675.0, "count": 1}, {"bucket_end": 887.5, "bucket_start": 781.25, "count": 0}, {"bucket_end": 993.75, "bucket_start": 887.5, "count": 0}, {"bucket_end": 1100.0, "bucket_start": 993.75, "count": 1}]'::jsonb),
  ('2026-05-13', 'cherry', 'Cairo', null, 'kg', 'EGP', 220.0, 220.0, 180.0, 260.0, 32.66, 180.0, 260.0, 3, '[{"bucket_end": 190.0, "bucket_start": 180.0, "count": 1}, {"bucket_end": 200.0, "bucket_start": 190.0, "count": 0}, {"bucket_end": 210.0, "bucket_start": 200.0, "count": 0}, {"bucket_end": 220.0, "bucket_start": 210.0, "count": 0}, {"bucket_end": 230.0, "bucket_start": 220.0, "count": 1}, {"bucket_end": 240.0, "bucket_start": 230.0, "count": 0}, {"bucket_end": 250.0, "bucket_start": 240.0, "count": 0}, {"bucket_end": 260.0, "bucket_start": 250.0, "count": 1}]'::jsonb),
  ('2026-05-13', 'cherry_tomato', 'Cairo', null, 'kg', 'EGP', 159.93, 121.98, 70.0, 287.8, 92.88, 70.0, 287.8, 3, '[{"bucket_end": 97.22, "bucket_start": 70.0, "count": 1}, {"bucket_end": 124.45, "bucket_start": 97.22, "count": 1}, {"bucket_end": 151.68, "bucket_start": 124.45, "count": 0}, {"bucket_end": 178.9, "bucket_start": 151.68, "count": 0}, {"bucket_end": 206.12, "bucket_start": 178.9, "count": 0}, {"bucket_end": 233.35, "bucket_start": 206.12, "count": 0}, {"bucket_end": 260.58, "bucket_start": 233.35, "count": 0}, {"bucket_end": 287.8, "bucket_start": 260.58, "count": 1}]'::jsonb),
  ('2026-05-13', 'dates', 'Cairo', null, 'kg', 'EGP', 29.67, 30.0, 24.0, 35.0, 4.5, 24.0, 35.0, 3, '[{"bucket_end": 25.38, "bucket_start": 24.0, "count": 1}, {"bucket_end": 26.75, "bucket_start": 25.38, "count": 0}, {"bucket_end": 28.12, "bucket_start": 26.75, "count": 0}, {"bucket_end": 29.5, "bucket_start": 28.12, "count": 0}, {"bucket_end": 30.88, "bucket_start": 29.5, "count": 1}, {"bucket_end": 32.25, "bucket_start": 30.88, "count": 0}, {"bucket_end": 33.62, "bucket_start": 32.25, "count": 0}, {"bucket_end": 35.0, "bucket_start": 33.62, "count": 1}]'::jsonb),
  ('2026-05-13', 'fruit', 'Cairo', null, 'kg', 'EGP', 56.67, 55.0, 25.0, 90.0, 26.56, 25.0, 90.0, 3, '[{"bucket_end": 33.12, "bucket_start": 25.0, "count": 1}, {"bucket_end": 41.25, "bucket_start": 33.12, "count": 0}, {"bucket_end": 49.38, "bucket_start": 41.25, "count": 0}, {"bucket_end": 57.5, "bucket_start": 49.38, "count": 1}, {"bucket_end": 65.62, "bucket_start": 57.5, "count": 0}, {"bucket_end": 73.75, "bucket_start": 65.62, "count": 0}, {"bucket_end": 81.88, "bucket_start": 73.75, "count": 0}, {"bucket_end": 90.0, "bucket_start": 81.88, "count": 1}]'::jsonb),
  ('2026-05-13', 'grape', 'Cairo', null, 'kg', 'EGP', 50.0, 50.0, 35.0, 65.0, 12.75, 35.0, 65.0, 4, '[{"bucket_end": 38.75, "bucket_start": 35.0, "count": 1}, {"bucket_end": 42.5, "bucket_start": 38.75, "count": 1}, {"bucket_end": 46.25, "bucket_start": 42.5, "count": 0}, {"bucket_end": 50.0, "bucket_start": 46.25, "count": 0}, {"bucket_end": 53.75, "bucket_start": 50.0, "count": 0}, {"bucket_end": 57.5, "bucket_start": 53.75, "count": 0}, {"bucket_end": 61.25, "bucket_start": 57.5, "count": 1}, {"bucket_end": 65.0, "bucket_start": 61.25, "count": 1}]'::jsonb),
  ('2026-05-13', 'grapefruit', 'Cairo', null, 'kg', 'EGP', 14.67, 15.0, 9.0, 20.0, 4.5, 9.0, 20.0, 3, '[{"bucket_end": 10.38, "bucket_start": 9.0, "count": 1}, {"bucket_end": 11.75, "bucket_start": 10.38, "count": 0}, {"bucket_end": 13.12, "bucket_start": 11.75, "count": 0}, {"bucket_end": 14.5, "bucket_start": 13.12, "count": 0}, {"bucket_end": 15.88, "bucket_start": 14.5, "count": 1}, {"bucket_end": 17.25, "bucket_start": 15.88, "count": 0}, {"bucket_end": 18.62, "bucket_start": 17.25, "count": 0}, {"bucket_end": 20.0, "bucket_start": 18.62, "count": 1}]'::jsonb),
  ('2026-05-13', 'guava', 'Cairo', null, 'kg', 'EGP', 28.33, 34.0, 12.0, 39.0, 11.73, 12.0, 39.0, 3, '[{"bucket_end": 15.38, "bucket_start": 12.0, "count": 1}, {"bucket_end": 18.75, "bucket_start": 15.38, "count": 0}, {"bucket_end": 22.12, "bucket_start": 18.75, "count": 0}, {"bucket_end": 25.5, "bucket_start": 22.12, "count": 0}, {"bucket_end": 28.88, "bucket_start": 25.5, "count": 0}, {"bucket_end": 32.25, "bucket_start": 28.88, "count": 0}, {"bucket_end": 35.62, "bucket_start": 32.25, "count": 1}, {"bucket_end": 39.0, "bucket_start": 35.62, "count": 1}]'::jsonb),
  ('2026-05-13', 'kiwi', 'Cairo', null, 'kg', 'EGP', 183.22, 183.8, 169.96, 195.9, 10.6, 169.96, 195.9, 3, '[{"bucket_end": 173.2, "bucket_start": 169.96, "count": 1}, {"bucket_end": 176.44, "bucket_start": 173.2, "count": 0}, {"bucket_end": 179.69, "bucket_start": 176.44, "count": 0}, {"bucket_end": 182.93, "bucket_start": 179.69, "count": 0}, {"bucket_end": 186.17, "bucket_start": 182.93, "count": 1}, {"bucket_end": 189.42, "bucket_start": 186.17, "count": 0}, {"bucket_end": 192.66, "bucket_start": 189.42, "count": 0}, {"bucket_end": 195.9, "bucket_start": 192.66, "count": 1}]'::jsonb),
  ('2026-05-13', 'lemon', 'Cairo', null, 'kg', 'EGP', 36.38, 35.5, 17.0, 57.5, 14.45, 17.0, 57.5, 4, '[{"bucket_end": 22.06, "bucket_start": 17.0, "count": 1}, {"bucket_end": 27.12, "bucket_start": 22.06, "count": 0}, {"bucket_end": 32.19, "bucket_start": 27.12, "count": 0}, {"bucket_end": 37.25, "bucket_start": 32.19, "count": 1}, {"bucket_end": 42.31, "bucket_start": 37.25, "count": 1}, {"bucket_end": 47.38, "bucket_start": 42.31, "count": 0}, {"bucket_end": 52.44, "bucket_start": 47.38, "count": 0}, {"bucket_end": 57.5, "bucket_start": 52.44, "count": 1}]'::jsonb),
  ('2026-05-13', 'mandarin', 'Cairo', null, 'kg', 'EGP', 20.33, 22.0, 12.0, 27.0, 6.24, 12.0, 27.0, 3, '[{"bucket_end": 13.88, "bucket_start": 12.0, "count": 1}, {"bucket_end": 15.75, "bucket_start": 13.88, "count": 0}, {"bucket_end": 17.62, "bucket_start": 15.75, "count": 0}, {"bucket_end": 19.5, "bucket_start": 17.62, "count": 0}, {"bucket_end": 21.38, "bucket_start": 19.5, "count": 0}, {"bucket_end": 23.25, "bucket_start": 21.38, "count": 1}, {"bucket_end": 25.12, "bucket_start": 23.25, "count": 0}, {"bucket_end": 27.0, "bucket_start": 25.12, "count": 1}]'::jsonb),
  ('2026-05-13', 'mango', 'Cairo', null, 'kg', 'EGP', 41.67, 50.0, 20.0, 55.0, 15.46, 20.0, 55.0, 3, '[{"bucket_end": 24.38, "bucket_start": 20.0, "count": 1}, {"bucket_end": 28.75, "bucket_start": 24.38, "count": 0}, {"bucket_end": 33.12, "bucket_start": 28.75, "count": 0}, {"bucket_end": 37.5, "bucket_start": 33.12, "count": 0}, {"bucket_end": 41.88, "bucket_start": 37.5, "count": 0}, {"bucket_end": 46.25, "bucket_start": 41.88, "count": 0}, {"bucket_end": 50.62, "bucket_start": 46.25, "count": 1}, {"bucket_end": 55.0, "bucket_start": 50.62, "count": 1}]'::jsonb),
  ('2026-05-13', 'orange', 'Cairo', null, 'kg', 'EGP', 18.0, 18.5, 10.0, 25.0, 5.43, 10.0, 25.0, 4, '[{"bucket_end": 11.88, "bucket_start": 10.0, "count": 1}, {"bucket_end": 13.75, "bucket_start": 11.88, "count": 0}, {"bucket_end": 15.62, "bucket_start": 13.75, "count": 0}, {"bucket_end": 17.5, "bucket_start": 15.62, "count": 1}, {"bucket_end": 19.38, "bucket_start": 17.5, "count": 0}, {"bucket_end": 21.25, "bucket_start": 19.38, "count": 1}, {"bucket_end": 23.12, "bucket_start": 21.25, "count": 0}, {"bucket_end": 25.0, "bucket_start": 23.12, "count": 1}]'::jsonb),
  ('2026-05-13', 'peach', 'Cairo', null, 'kg', 'EGP', 35.0, 40.0, 20.0, 45.0, 10.8, 20.0, 45.0, 3, '[{"bucket_end": 23.12, "bucket_start": 20.0, "count": 1}, {"bucket_end": 26.25, "bucket_start": 23.12, "count": 0}, {"bucket_end": 29.38, "bucket_start": 26.25, "count": 0}, {"bucket_end": 32.5, "bucket_start": 29.38, "count": 0}, {"bucket_end": 35.62, "bucket_start": 32.5, "count": 0}, {"bucket_end": 38.75, "bucket_start": 35.62, "count": 0}, {"bucket_end": 41.88, "bucket_start": 38.75, "count": 1}, {"bucket_end": 45.0, "bucket_start": 41.88, "count": 1}]'::jsonb),
  ('2026-05-13', 'pineapple', 'Cairo', null, 'pcs', 'EGP', 218.32, 220.0, 180.0, 254.95, 30.62, 180.0, 254.95, 3, '[{"bucket_end": 189.37, "bucket_start": 180.0, "count": 1}, {"bucket_end": 198.74, "bucket_start": 189.37, "count": 0}, {"bucket_end": 208.11, "bucket_start": 198.74, "count": 0}, {"bucket_end": 217.47, "bucket_start": 208.11, "count": 0}, {"bucket_end": 226.84, "bucket_start": 217.47, "count": 1}, {"bucket_end": 236.21, "bucket_start": 226.84, "count": 0}, {"bucket_end": 245.58, "bucket_start": 236.21, "count": 0}, {"bucket_end": 254.95, "bucket_start": 245.58, "count": 1}]'::jsonb),
  ('2026-05-13', 'plum', 'Cairo', null, 'kg', 'EGP', 190.0, 190.0, 180.0, 200.0, 8.16, 180.0, 200.0, 3, '[{"bucket_end": 182.5, "bucket_start": 180.0, "count": 1}, {"bucket_end": 185.0, "bucket_start": 182.5, "count": 0}, {"bucket_end": 187.5, "bucket_start": 185.0, "count": 0}, {"bucket_end": 190.0, "bucket_start": 187.5, "count": 0}, {"bucket_end": 192.5, "bucket_start": 190.0, "count": 1}, {"bucket_end": 195.0, "bucket_start": 192.5, "count": 0}, {"bucket_end": 197.5, "bucket_start": 195.0, "count": 0}, {"bucket_end": 200.0, "bucket_start": 197.5, "count": 1}]'::jsonb),
  ('2026-05-13', 'pomegranate', 'Cairo', null, 'kg', 'EGP', 30.0, 35.0, 15.0, 40.0, 10.8, 15.0, 40.0, 3, '[{"bucket_end": 18.12, "bucket_start": 15.0, "count": 1}, {"bucket_end": 21.25, "bucket_start": 18.12, "count": 0}, {"bucket_end": 24.38, "bucket_start": 21.25, "count": 0}, {"bucket_end": 27.5, "bucket_start": 24.38, "count": 0}, {"bucket_end": 30.62, "bucket_start": 27.5, "count": 0}, {"bucket_end": 33.75, "bucket_start": 30.62, "count": 0}, {"bucket_end": 36.88, "bucket_start": 33.75, "count": 1}, {"bucket_end": 40.0, "bucket_start": 36.88, "count": 1}]'::jsonb),
  ('2026-05-13', 'rockmelon', 'Cairo', null, 'kg', 'EGP', 21.87, 20.5, 9.0, 37.48, 10.31, 9.0, 37.48, 4, '[{"bucket_end": 12.56, "bucket_start": 9.0, "count": 1}, {"bucket_end": 16.12, "bucket_start": 12.56, "count": 0}, {"bucket_end": 19.68, "bucket_start": 16.12, "count": 1}, {"bucket_end": 23.24, "bucket_start": 19.68, "count": 1}, {"bucket_end": 26.8, "bucket_start": 23.24, "count": 0}, {"bucket_end": 30.36, "bucket_start": 26.8, "count": 0}, {"bucket_end": 33.92, "bucket_start": 30.36, "count": 0}, {"bucket_end": 37.48, "bucket_start": 33.92, "count": 1}]'::jsonb),
  ('2026-05-13', 'strawberry', 'Cairo', null, 'kg', 'EGP', 84.14, 27.5, 15.0, 266.56, 105.46, 15.0, 266.56, 4, '[{"bucket_end": 46.45, "bucket_start": 15.0, "count": 3}, {"bucket_end": 77.89, "bucket_start": 46.45, "count": 0}, {"bucket_end": 109.34, "bucket_start": 77.89, "count": 0}, {"bucket_end": 140.78, "bucket_start": 109.34, "count": 0}, {"bucket_end": 172.22, "bucket_start": 140.78, "count": 0}, {"bucket_end": 203.67, "bucket_start": 172.22, "count": 0}, {"bucket_end": 235.12, "bucket_start": 203.67, "count": 0}, {"bucket_end": 266.56, "bucket_start": 235.12, "count": 1}]'::jsonb),
  ('2026-05-13', 'tomato', 'Cairo', null, 'kg', 'EGP', 33.71, 22.5, 12.5, 99.99, 27.98, 12.5, 99.99, 7, '[{"bucket_end": 23.44, "bucket_start": 12.5, "count": 4}, {"bucket_end": 34.37, "bucket_start": 23.44, "count": 1}, {"bucket_end": 45.31, "bucket_start": 34.37, "count": 1}, {"bucket_end": 56.24, "bucket_start": 45.31, "count": 0}, {"bucket_end": 67.18, "bucket_start": 56.24, "count": 0}, {"bucket_end": 78.12, "bucket_start": 67.18, "count": 0}, {"bucket_end": 89.05, "bucket_start": 78.12, "count": 0}, {"bucket_end": 99.99, "bucket_start": 89.05, "count": 1}]'::jsonb),
  ('2026-05-13', 'watermelon', 'Cairo', null, 'kg', 'EGP', 12.33, 10.0, 7.0, 20.0, 5.56, 7.0, 20.0, 3, '[{"bucket_end": 8.62, "bucket_start": 7.0, "count": 1}, {"bucket_end": 10.25, "bucket_start": 8.62, "count": 1}, {"bucket_end": 11.88, "bucket_start": 10.25, "count": 0}, {"bucket_end": 13.5, "bucket_start": 11.88, "count": 0}, {"bucket_end": 15.12, "bucket_start": 13.5, "count": 0}, {"bucket_end": 16.75, "bucket_start": 15.12, "count": 0}, {"bucket_end": 18.38, "bucket_start": 16.75, "count": 0}, {"bucket_end": 20.0, "bucket_start": 18.38, "count": 1}]'::jsonb)
)
insert into daily_price_stats (stat_date, product_id, city, district, unit, currency, avg_price, median_price, min_price, max_price, stddev_price, p10_price, p90_price, sample_count, distribution)
select sr.stat_date::date, p.id, sr.city, sr.district, sr.unit, sr.currency, sr.avg_price, sr.median_price, sr.min_price, sr.max_price, sr.stddev_price, sr.p10_price, sr.p90_price, sr.sample_count, sr.distribution
from stat_rows sr
join products p on p.code = sr.product_code
where not exists (
  select 1 from daily_price_stats dps
  where dps.stat_date = sr.stat_date::date
    and dps.product_id = p.id
    and dps.city = sr.city
    and dps.district is not distinct from sr.district
    and dps.unit = sr.unit
);

insert into exchange_rates (base_currency, quote_currency, rate, as_of_date, source)
select 'EGP', 'KRW', 28.1348, '2026-05-13'::date, 'currencyrate.today EGP/KRW 2026-05-13 07:00 UTC'
where not exists (
  select 1 from exchange_rates
  where base_currency = 'EGP' and quote_currency = 'KRW' and as_of_date = '2026-05-13'::date
);

commit;
