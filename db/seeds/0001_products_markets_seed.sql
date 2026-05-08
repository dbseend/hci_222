-- Minimal seed for current Flutter mock flow.

insert into public.products (code, name, default_unit)
values
  ('p001', 'Grapes', 'kg'),
  ('p002', 'Tomatoes', 'kg'),
  ('p003', 'Cucumbers', 'kg'),
  ('p004', 'Pomegranate', 'pcs'),
  ('p005', 'Lemons', 'pcs')
on conflict (code) do update
set
  name = excluded.name,
  default_unit = excluded.default_unit,
  updated_at = now();

insert into public.markets (name, city, district, lat, lng)
values
  ('Khan el-Khalili Market', 'Cairo', 'Old Cairo', 30.0478, 31.2625),
  ('Ataba Market', 'Cairo', 'Downtown Cairo', 30.0565, 31.2457),
  ('Imbaba Market', 'Cairo', 'Imbaba', 30.0732, 31.2076)
on conflict do nothing;
