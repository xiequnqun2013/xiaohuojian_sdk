-- ============================================================
-- PolarDB Supabase 数据库初始化脚本
-- 执行方式：Dashboard SQL Editor 或 psql
-- ============================================================

-- 测试环境 Schema
CREATE SCHEMA IF NOT EXISTS test_public;

-- ============================================================
-- 1. apps 表（应用注册）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.apps (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    slug text UNIQUE NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS test_public.apps (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    slug text UNIQUE NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.apps IS '应用注册表';
COMMENT ON TABLE test_public.apps IS '应用注册表（测试环境）';

-- 插入默认应用
INSERT INTO public.apps (name, slug) VALUES 
    ('申论学习', 'shenlun'),
    ('行测刷题', 'xingce')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO test_public.apps (name, slug) VALUES 
    ('申论学习测试', 'shenlun'),
    ('行测刷题测试', 'xingce')
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- 2. profiles 表（用户资料扩展）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    nickname text,
    avatar_url text,
    phone text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS test_public.profiles (
    id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    nickname text,
    avatar_url text,
    phone text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.profiles IS '用户资料扩展表';

-- ============================================================
-- 3. user_apps 表（用户-应用关联）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_apps (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    app_id uuid REFERENCES public.apps(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    UNIQUE(user_id, app_id)
);

CREATE TABLE IF NOT EXISTS test_public.user_apps (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    app_id uuid REFERENCES test_public.apps(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    UNIQUE(user_id, app_id)
);

COMMENT ON TABLE public.user_apps IS '用户与应用的多对多关联表';

-- ============================================================
-- 4. user_devices 表（设备-用户映射）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_devices (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id text NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    app_slug text NOT NULL,
    is_migrated boolean DEFAULT true,
    migrated_at timestamptz DEFAULT now(),
    UNIQUE(device_id, app_slug)
);

CREATE TABLE IF NOT EXISTS test_public.user_devices (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id text NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    app_slug text NOT NULL,
    is_migrated boolean DEFAULT true,
    migrated_at timestamptz DEFAULT now(),
    UNIQUE(device_id, app_slug)
);

COMMENT ON TABLE public.user_devices IS '设备-用户映射表，记录哪些设备迁移到了哪个账号';

-- ============================================================
-- 5. user_purchases 表（购买记录）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_purchases (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    app_slug text NOT NULL,
    product_id text NOT NULL,
    platform text NOT NULL CHECK (platform IN ('ios', 'android')),
    transaction_id text UNIQUE,
    receipt_data text,
    receipt_hash text UNIQUE,
    migrated_from_device text,
    is_valid boolean DEFAULT true,
    purchased_at timestamptz,
    expires_at timestamptz,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS test_public.user_purchases (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    app_slug text NOT NULL,
    product_id text NOT NULL,
    platform text NOT NULL CHECK (platform IN ('ios', 'android')),
    transaction_id text UNIQUE,
    receipt_data text,
    receipt_hash text UNIQUE,
    migrated_from_device text,
    is_valid boolean DEFAULT true,
    purchased_at timestamptz,
    expires_at timestamptz,
    created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.user_purchases IS '购买记录表，用于跨设备恢复';

-- ============================================================
-- 6. 触发器（自动创建 profile）
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 插入 public schema
    INSERT INTO public.profiles (id, phone)
    VALUES (new.id, new.phone)
    ON CONFLICT (id) DO NOTHING;
    
    -- 插入 test schema
    INSERT INTO test_public.profiles (id, phone)
    VALUES (new.id, new.phone)
    ON CONFLICT (id) DO NOTHING;
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 删除已存在的触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 创建触发器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

COMMENT ON FUNCTION public.handle_new_user() IS '用户注册时自动创建 profile 记录';

-- ============================================================
-- 7. RLS 策略
-- ============================================================

-- public.profiles RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own profile" 
    ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY IF NOT EXISTS "Users can update own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- test_public.profiles RLS
ALTER TABLE test_public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own profile (test)" 
    ON test_public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY IF NOT EXISTS "Users can update own profile (test)" 
    ON test_public.profiles FOR UPDATE USING (auth.uid() = id);

-- public.user_apps RLS
ALTER TABLE public.user_apps ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own apps" 
    ON public.user_apps FOR SELECT USING (auth.uid() = user_id);

-- test_public.user_apps RLS
ALTER TABLE test_public.user_apps ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own apps (test)" 
    ON test_public.user_apps FOR SELECT USING (auth.uid() = user_id);

-- public.user_devices RLS
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own devices" 
    ON public.user_devices FOR SELECT USING (auth.uid() = user_id);

-- test_public.user_devices RLS
ALTER TABLE test_public.user_devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own devices (test)" 
    ON test_public.user_devices FOR SELECT USING (auth.uid() = user_id);

-- public.user_purchases RLS
ALTER TABLE public.user_purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own purchases" 
    ON public.user_purchases FOR SELECT USING (auth.uid() = user_id);

-- test_public.user_purchases RLS
ALTER TABLE test_public.user_purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "Users can view own purchases (test)" 
    ON test_public.user_purchases FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- 8. 创建辅助函数
-- ============================================================

-- 获取 OSS 配置函数（替代 Edge Function）
CREATE OR REPLACE FUNCTION public.get_oss_sts(
    env text DEFAULT 'test',
    app_slug text DEFAULT 'shenlun'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_bucket text := 'rocket-workshop';
    v_endpoint text := 'oss-cn-beijing.aliyuncs.com';
    v_region text := 'cn-beijing';
    v_role_arn text := 'acs:ram::1228668199344213:role/flutter-oss-role';
    v_path_prefix text;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'error', 'Unauthorized',
            'message', '用户未登录',
            'code', 401
        );
    END IF;
    
    v_path_prefix := format('%s/users/%s/%s/', env, v_user_id, app_slug);
    
    RETURN jsonb_build_object(
        'success', true,
        'bucket', v_bucket,
        'endpoint', v_endpoint,
        'region', v_region,
        'pathPrefix', v_path_prefix,
        'roleArn', v_role_arn,
        'userId', v_user_id,
        'note', '请使用 Edge Function 获取真实 STS 凭证'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_oss_sts TO authenticated;
COMMENT ON FUNCTION public.get_oss_sts IS '获取 OSS 配置（简化版）';

-- ============================================================
-- 完成
-- ============================================================
SELECT 'PolarDB Supabase 数据库初始化完成！' AS status;
