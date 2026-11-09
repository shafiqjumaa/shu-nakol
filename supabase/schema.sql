-- شو ناكل؟ قاعدة بيانات Supabase — إعداد أولي للتجربة
create extension if not exists pgcrypto;

create table if not exists public.daily_orders (
 order_date date primary key default current_date,
 title text not null default 'طلبية غداء اليوم',
 is_open boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.menu_items (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 description text not null default '',
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.orders (
 id uuid primary key default gen_random_uuid(),
 employee_name text not null,
 items jsonb not null default '[]'::jsonb,
 note text not null default '',
 status text not null default 'new' check(status in ('new','buying','bought','delivered')),
 order_date date not null default current_date,
 created_at timestamptz not null default now()
);
create index if not exists orders_order_date_idx on public.orders(order_date);
create index if not exists orders_created_at_idx on public.orders(created_at desc);

alter table public.daily_orders enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;

drop policy if exists "Anyone can read menu" on public.menu_items;
create policy "Anyone can read menu" on public.menu_items for select to anon,authenticated using(active=true);
drop policy if exists "Admin manages menu" on public.menu_items;
create policy "Admin manages menu" on public.menu_items for all to authenticated using((select auth.uid()) is not null) with check((select auth.uid()) is not null);
drop policy if exists "Anyone can read daily order settings" on public.daily_orders;
create policy "Anyone can read daily order settings" on public.daily_orders for select to anon,authenticated using(true);
drop policy if exists "Admin manages daily order settings" on public.daily_orders;
create policy "Admin manages daily order settings" on public.daily_orders for all to authenticated using((select auth.uid()) is not null) with check((select auth.uid()) is not null);
drop policy if exists "Employees can submit orders" on public.orders;
create policy "Employees can submit orders" on public.orders for insert to anon,authenticated with check(employee_name<>'' and jsonb_typeof(items)='array' and order_date=current_date);
drop policy if exists "Admin can read and manage orders" on public.orders;
create policy "Admin can read and manage orders" on public.orders for all to authenticated using((select auth.uid()) is not null) with check((select auth.uid()) is not null);

insert into public.menu_items(name,description)
select v.name,v.description from (values
 ('شاورما دجاج','سندويشة شاورما مع الإضافات'),
 ('فلافل','سندويشة فلافل'),
 ('برغر','برغر لحم أو دجاج'),
 ('بطاطا','بطاطا مقلية')
) as v(name,description)
where not exists(select 1 from public.menu_items);

-- أمان: هذه سياسات أولية وليست جاهزة للنشر العام.
-- قبل الإطلاق يجب إنشاء دور admin حقيقي وربط سياسات الإدارة به،
-- والتحقق من أن الطلبية مفتوحة داخل قاعدة البيانات/Edge Function،
-- وإضافة rate limiting والتحقق من مدخلات الطلبات.
-- لا تستخدم service_role key في تطبيق المتصفح.
