#!/bin/bash

# Edge Function 测试脚本

SUPABASE_URL="http://8.161.114.102:80"
ANON_KEY="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzcwNDQ0NjQ0LCJleHAiOjEzMjgxMDg0NjQ0fQ.b8jrVt73j4A3vlAN34TAntvPKy-9H3bMFdP37zux3pQ"

echo "═══════════════════════════════════════════════════════════"
echo "🧪 Edge Function 测试"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. 先测试匿名访问（应该失败）
echo "1️⃣ 测试匿名访问（应该返回 401）..."
curl -s -X POST "$SUPABASE_URL/functions/v1/get-oss-sts" \
  -H "Content-Type: application/json" \
  -d '{"env":"test","appSlug":"shenlun"}' | head -100

echo ""
echo ""

# 2. 提示用户获取 JWT
echo "2️⃣ 请提供登录后的 JWT Token 进行测试"
echo ""
echo "获取 JWT 的方法："
echo "   1. 运行 example_app 登录"
echo "   2. 登录成功后，调用 Supabase API 获取当前 session"
echo "   3. 复制 access_token"
echo ""
echo "或者使用 service role key 测试（跳过鉴权）："
echo "   需要设置 Edge Function 的环境变量"
echo ""

# 3. 测试 RPC 函数（已部署）
echo "3️⃣ 测试 RPC 函数（无需 Edge Function）..."
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/get_oss_sts_credentials" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_env":"test","p_app_slug":"shenlun"}'

echo ""
echo ""

# 如果提供了 JWT，测试带认证的请求
if [ -n "$1" ]; then
    JWT="$1"
    echo "4️⃣ 使用提供的 JWT 测试..."
    curl -s -X POST "$SUPABASE_URL/functions/v1/get-oss-sts" \
      -H "Authorization: Bearer $JWT" \
      -H "Content-Type: application/json" \
      -d '{"env":"test","appSlug":"shenlun"}'
    echo ""
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ 测试完成"
echo "═══════════════════════════════════════════════════════════"
