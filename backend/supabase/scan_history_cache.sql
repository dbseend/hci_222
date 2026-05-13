alter table scan_histories
add column if not exists detected_product_code text,
add column if not exists detected_product_name text,
add column if not exists detected_product_name_ar text,
add column if not exists detection_confidence numeric,
add column if not exists detected_price_egp numeric,
add column if not exists quoted_total_price_egp numeric,
add column if not exists quoted_quantity numeric default 1,
add column if not exists quoted_unit text default 'kg',
add column if not exists quoted_unit_price_egp numeric,
add column if not exists detected_at timestamptz,
add column if not exists price_entered_at timestamptz,
add column if not exists updated_at timestamptz default now();

create index if not exists scan_histories_detection_lookup_idx
on scan_histories (client_user_id, detected_product_code, created_at desc);
