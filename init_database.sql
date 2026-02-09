-- ============================================================
-- Rocket Workshop 用户系统数据库初始化
-- ============================================================

-- 1. 创建 apps 表（应用注册）
create table if not exists apps (
    id uuid default gen_random_uuid() primary key,
    name text not null,           -- 应用名称（如"申论学习"）
    slug text unique not null,    -- 应用标识（如"shenlun"）
    is_active boolean default true,
    created_at timestamptz default now()
);

comment on table apps is '应用注册表，存储所有接入的 App';

-- 插入第一个测试 App
insert into apps (name, slug) 
values ('申论学习', 'shenlun')
on conflict (slug) do nothing;

-- 2. 创建 user_apps 表（用户-应用关联）
create table if not exists user_apps (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) on delete cascade,
    app_id uuid references apps(id) on delete cascade,
    created_at timestamptz default now(),
    unique(user_id, app_id)
);

comment on table user_apps is '用户与应用的多对多关联表，记录用户使用过哪些 App';

-- 3. 创建 profiles 表（用户资料扩展）
create table if not exists profiles (
    id uuid references auth.users(id) on delete cascade primary key,
    nickname text,                -- 昵称
    avatar_url text,              -- 头像 URL
    phone text,                   -- 手机号
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

comment on table profiles is '用户资料扩展表，存储用户额外信息';

-- 4. 创建触发器函数（自动创建 profile）
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, phone)
    values (new.id, new.phone);
    return new;
end;
$$ language plpgsql security definer;

-- 删除已存在的触发器（如果存在）
drop trigger if exists on_auth_user_created on auth.users;

-- 创建触发器
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

comment on function public.handle_new_user() is '当新用户注册时自动创建用户资料';

-- 5. 启用 RLS 并创建策略

-- profiles RLS：用户只能看/改自己的资料
alter table profiles enable row level security;

drop policy if exists "Users can view own profile" on profiles;
create policy "Users can view own profile" on profiles 
    for select using (auth.uid() = id);

drop policy if exists "Users can update own profile" on profiles;
create policy "Users can update own profile" on profiles 
    for update using (auth.uid() = id);

-- user_apps RLS：用户只能看自己的 App 关联
alter table user_apps enable row level security;

drop policy if exists "Users can view own apps" on user_apps;
create policy "Users can view own apps" on user_apps 
    for select using (auth.uid() = user_id);

-- 允许插入（SDK 自动关联 App 时用）
drop policy if exists "Users can insert own apps" on user_apps;
create policy "Users can insert own apps" on user_apps 
    for insert with check (auth.uid() = user_id);

-- ============================================================
-- 完成！
-- ============================================================

-- 验证创建结果
select 'apps' as table_name, count(*) as count from apps
union all
select 'profiles' as table_name, 0 as count where not exists (select 1 from profiles)
union all
select 'user_apps' as table_name, 0 as count where not exists (select 1 from user_apps);
