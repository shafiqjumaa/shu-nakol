-- شو ناكل؟ — Supabase schema with admin-only authorization
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

create table if not exists public.admin_users (
 id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
alter table public.daily_orders enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;

revoke all on table public.admin_users, public.daily_orders, public.menu_items, public.orders from anon, authenticated;
grant select on table public.daily_orders, public.menu_items to anon, authenticated;
grant insert on table public.orders to anon, authenticated;
grant select, update, delete on table public.orders to authenticated;
grant insert, update, delete on table public.daily_orders, public.menu_items to authenticated;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists(select 1 from public.admin_users where id = (select auth.uid()));
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "Anyone can read menu" on public.menu_items;
drop policy if exists "Admin manages menu" on public.menu_items;
drop policy if exists "Anyone can read daily order settings" on public.daily_orders;
drop policy if exists "Admin manages daily order settings" on public.daily_orders;
drop policy if exists "Employees can submit orders" on public.orders;
drop policy if exists "Admin can read and manage orders" on public.orders;
drop policy if exists "Public reads active menu" on public.menu_items;
create policy "Public reads active menu" on public.menu_items for select to anon, authenticated using(active=true);
drop policy if exists "Admins manage menu" on public.menu_items;
create policy "Admins manage menu" on public.menu_items for all to authenticated using((select public.is_admin())) with check((select public.is_admin()));
drop policy if exists "Public reads daily order settings" on public.daily_orders;
create policy "Public reads daily order settings" on public.daily_orders for select to anon, authenticated using(true);
drop policy if exists "Admins manage daily order settings" on public.daily_orders;
create policy "Admins manage daily order settings" on public.daily_orders for all to authenticated using((select public.is_admin())) with check((select public.is_admin()));

drop policy if exists "Open daily order accepts valid submissions" on public.orders;
create policy "Open daily order accepts valid submissions" on public.orders for insert to anon, authenticated
with check (
 order_date=current_date
 and length(trim(employee_name)) between 1 and 100
 and jsonb_typeof(items)='array'
 and jsonb_array_length(items) between 1 and 20
 and exists(select 1 from public.daily_orders d where d.order_date=current_date and d.is_open=true)
);
drop policy if exists "Admins read orders" on public.orders;
create policy "Admins read orders" on public.orders for select to authenticated using((select public.is_admin()));
drop policy if exists "Admins update orders" on public.orders;
create policy "Admins update orders" on public.orders for update to authenticated using((select public.is_admin())) with check((select public.is_admin()));
drop policy if exists "Admins delete orders" on public.orders;
create policy "Admins delete orders" on public.orders for delete to authenticated using((select public.is_admin()));

insert into public.menu_items(name,description)
select v.name,v.description from (values
 ('شاورما دجاج','سندويشة شاورما مع الإضافات'),
 ('فلافل','سندويشة فلافل'),
 ('برغر','برغر لحم أو دجاج'),
 ('بطاطا','بطاطا مقلية')
) as v(name,description)
where not exists(select 1 from public.menu_items);
insert into public.daily_orders(order_date,title,is_open)
values(current_date,'طلبية غداء اليوم',true) on conflict(order_date) do nothing;

-- بعد إنشاء مستخدم من Authentication > Users، أضف UUID الخاص به:
-- insert into public.admin_users(id) values ('PASTE_AUTH_USER_UUID_HERE');
-- لا تضع Secret Key في الواجهة الأمامية.
