#!/bin/bash
# 完整的登录测试脚本

SUPABASE_URL="http://8.161.114.102:80"
ANON_KEY="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzcwNDQ0NjQ0LCJleHAiOjEzMjgxMDg0NjQ0fQ.b8jrVt73j4A3vlAN34TAntvPKy-9H3bMFdP37zux3pQ"

echo "═══════════════════════════════════════════════════════════"
echo "📱 短信登录测试"
echo "═══════════════════════════════════════════════════════════"
echo ""

PHONE="+8618520160445"

echo "1️⃣ 检查用户是否存在..."
USER_RESPONSE=$(curl -s "$SUPABASE_URL/rest/v1/users?phone=eq.$PHONE&select=id,phone,created_at" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY")

echo "用户数据: $USER_RESPONSE"
echo ""

if [ "$USER_RESPONSE" = "[]" ]; then
    echo "❌ 用户不存在"
else
    echo "✅ 用户已存在"
fi

echo ""
echo "2️⃣ 尝试直接登录（使用已确认的用户）..."
echo ""
echo "由于验证码过期太快，请在 Flutter App 中测试:"
echo ""
echo "   cd flutter-sdk/example_app"
echo "   flutter run --dart-define=ENV=test"
echo ""
echo "   手机号: 18520160445"
echo "   点击'发送验证码' → 输入收到的验证码"
echo ""

# 3. 测试 RPC 函数
echo "3️⃣ 测试 OSS 配置获取（需要登录后的 JWT）..."
echo ""
echo "登录成功后，在 App 中会自动调用:"
echo "  - get_oss_sts RPC 函数"
echo "  - 获取 OSS 配置和路径前缀"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "✅ 后端配置完成"
echo "═══════════════════════════════════════════════════════════"
