create table if not exists public.price_sources (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (
    source_type in ('user_market', 'web', 'government', 'manual_seed')
  ),
  name text not null,
  url text,
  weight numeric not null default 1.0 check (weight > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (source_type, name)
);

alter table public.price_sources enable row level security;

create table if not exists public.price_observations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  source_id uuid not null references public.price_sources(id),
  purchase_id uuid references public.purchases(id),
  region_code text not null default 'cairo',
  currency text not null default 'EGP',
  unit text not null check (unit in ('kg', 'pcs')),
  quantity numeric not null default 1 check (quantity > 0),
  total_price_egp numeric not null check (total_price_egp >= 0),
  unit_price_egp numeric not null check (unit_price_egp >= 0),
  observed_at timestamptz not null,
  status text not null default 'pending' check (
    status in ('pending', 'accepted', 'rejected')
  ),
  rejection_reason text,
  confidence_score numeric not null default 0.5 check (
    confidence_score >= 0 and confidence_score <= 1
  ),
  raw_payload jsonb,
  created_at timestamptz not null default now()
);

alter table public.price_observations enable row level security;

create table if not exists public.price_reference_stats (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  region_code text not null default 'cairo',
  unit text not null check (unit in ('kg', 'pcs')),
  window_days int not null check (window_days > 0),
  stat_date date not null,
  sample_count int not null check (sample_count >= 0),
  weighted_avg_price_egp numeric not null check (weighted_avg_price_egp >= 0),
  median_price_egp numeric not null check (median_price_egp >= 0),
  min_price_egp numeric not null check (min_price_egp >= 0),
  max_price_egp numeric not null check (max_price_egp >= 0),
  p25_price_egp numeric check (p25_price_egp is null or p25_price_egp >= 0),
  p75_price_egp numeric check (p75_price_egp is null or p75_price_egp >= 0),
  stddev_price_egp numeric check (stddev_price_egp is null or stddev_price_egp >= 0),
  source_mix jsonb,
  created_at timestamptz not null default now(),
  unique (product_id, region_code, unit, window_days, stat_date)
);

alter table public.price_reference_stats enable row level security;

alter table public.purchases
add column if not exists price_observation_id uuid references public.price_observations(id);

create index if not exists idx_price_obs_stats_lookup
on public.price_observations (product_id, region_code, unit, observed_at desc)
where status = 'accepted';

create index if not exists idx_price_obs_pending
on public.price_observations (status, created_at desc);

create index if not exists idx_price_obs_source_created
on public.price_observations (source_id, created_at desc);

create index if not exists idx_price_ref_lookup
on public.price_reference_stats (
  product_id,
  region_code,
  unit,
  window_days,
  stat_date desc
);

create index if not exists idx_purchases_price_observation_id
on public.purchases (price_observation_id);

insert into public.price_sources (source_type, name, weight)
values
  ('user_market', 'TruePrice user market reports', 1.00),
  ('government', 'Egypt government/statistical references', 0.80),
  ('web', 'Egypt web retail references', 0.50),
  ('manual_seed', 'TruePrice MVP manual seed', 0.30)
on conflict (source_type, name) do update
set weight = excluded.weight,
    is_active = true;
