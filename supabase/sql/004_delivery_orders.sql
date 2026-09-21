-- Delivery orders + admin-ready lookup tables.
-- Apply in Supabase SQL Editor (project: hather / gonlutyrhccmdpdwqdhk).

-- ---------------------------------------------------------------------------
-- Order types (managed later from admin)
-- ---------------------------------------------------------------------------
create table if not exists public.order_types (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists order_types_active_sort_idx
  on public.order_types (is_active, sort_order);

-- ---------------------------------------------------------------------------
-- Auto-delete duration options (minutes)
-- ---------------------------------------------------------------------------
create table if not exists public.order_delete_durations (
  id uuid primary key default gen_random_uuid(),
  label_ar text not null,
  minutes int not null check (minutes > 0),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists order_delete_durations_active_sort_idx
  on public.order_delete_durations (is_active, sort_order);

-- ---------------------------------------------------------------------------
-- Delivery fee presets (admin can expand later)
-- ---------------------------------------------------------------------------
create table if not exists public.delivery_fee_options (
  id uuid primary key default gen_random_uuid(),
  label_ar text not null,
  amount_iqd numeric(12, 0) not null check (amount_iqd >= 0),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Coupons (admin managed)
-- ---------------------------------------------------------------------------
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_type text not null check (discount_type in ('percent', 'fixed')),
  discount_value numeric(12, 2) not null check (discount_value > 0),
  is_active boolean not null default true,
  expires_at timestamptz,
  max_uses int,
  used_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists coupons_code_idx on public.coupons (code);

-- ---------------------------------------------------------------------------
-- Home ads (admin managed; app falls back to local placeholder)
-- ---------------------------------------------------------------------------
create table if not exists public.home_ads (
  id uuid primary key default gen_random_uuid(),
  title_ar text,
  image_url text,
  link_url text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Delivery orders
-- ---------------------------------------------------------------------------
create table if not exists public.delivery_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  order_type_id uuid references public.order_types (id),
  order_type_name text not null,
  details text not null,
  delete_after_minutes int not null check (delete_after_minutes > 0),
  expires_at timestamptz not null,
  delivery_fee_iqd numeric(12, 0) not null check (delivery_fee_iqd >= 0),
  coupon_code text,
  coupon_discount_iqd numeric(12, 0) not null default 0,
  destination_type text not null check (destination_type in ('current', 'map')),
  destination_lat double precision,
  destination_lng double precision,
  destination_address text,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'completed', 'cancelled', 'expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists delivery_orders_user_created_idx
  on public.delivery_orders (user_id, created_at desc);

create index if not exists delivery_orders_status_expires_idx
  on public.delivery_orders (status, expires_at);

alter table public.order_types enable row level security;
alter table public.order_delete_durations enable row level security;
alter table public.delivery_fee_options enable row level security;
alter table public.coupons enable row level security;
alter table public.home_ads enable row level security;
alter table public.delivery_orders enable row level security;

-- Public read for active lookup / ads (authenticated users).
drop policy if exists "order_types_select_active" on public.order_types;
create policy "order_types_select_active"
  on public.order_types for select to authenticated
  using (is_active = true);

drop policy if exists "order_delete_durations_select_active" on public.order_delete_durations;
create policy "order_delete_durations_select_active"
  on public.order_delete_durations for select to authenticated
  using (is_active = true);

drop policy if exists "delivery_fee_options_select_active" on public.delivery_fee_options;
create policy "delivery_fee_options_select_active"
  on public.delivery_fee_options for select to authenticated
  using (is_active = true);

drop policy if exists "coupons_select_active" on public.coupons;
create policy "coupons_select_active"
  on public.coupons for select to authenticated
  using (is_active = true);

drop policy if exists "home_ads_select_active" on public.home_ads;
create policy "home_ads_select_active"
  on public.home_ads for select to authenticated
  using (is_active = true);

drop policy if exists "delivery_orders_select_own" on public.delivery_orders;
create policy "delivery_orders_select_own"
  on public.delivery_orders for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "delivery_orders_insert_own" on public.delivery_orders;
create policy "delivery_orders_insert_own"
  on public.delivery_orders for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "delivery_orders_update_own" on public.delivery_orders;
create policy "delivery_orders_update_own"
  on public.delivery_orders for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Seed defaults (safe to re-run)
insert into public.order_types (name_ar, sort_order)
select * from (values
  ('طعام', 1),
  ('مشتريات', 2),
  ('أدوية', 3),
  ('مستندات', 4),
  ('أخرى', 5)
) as v(name_ar, sort_order)
where not exists (select 1 from public.order_types limit 1);

insert into public.order_delete_durations (label_ar, minutes, sort_order)
select * from (values
  ('30 دقيقة', 30, 1),
  ('ساعة واحدة', 60, 2),
  ('ساعتان', 120, 3),
  ('6 ساعات', 360, 4),
  ('24 ساعة', 1440, 5)
) as v(label_ar, minutes, sort_order)
where not exists (select 1 from public.order_delete_durations limit 1);

insert into public.delivery_fee_options (label_ar, amount_iqd, sort_order)
select * from (values
  ('2,000 د.ع', 2000, 1),
  ('3,000 د.ع', 3000, 2),
  ('5,000 د.ع', 5000, 3),
  ('7,000 د.ع', 7000, 4),
  ('10,000 د.ع', 10000, 5)
) as v(label_ar, amount_iqd, sort_order)
where not exists (select 1 from public.delivery_fee_options limit 1);
