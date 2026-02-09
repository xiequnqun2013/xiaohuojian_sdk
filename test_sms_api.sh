#!/bin/bash

# Supabase SMS 发送测试脚本

SUPABASE_URL="http://8.161.114.102:80"
ANON_KEY="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzcwNDQ0NjQ0LCJleHAiOjEzMjgxMDg0NjQ0fQ.b8jrVt73j4A3vlAN34TAntvPKy-9H3bMFdP37zux3pQ"
PHONE="+8618520160445"

echo "正在发送验证码到: $PHONE"
echo ""

# 调用 Supabase Auth API 发送 OTP
curl -X POST "$SUPABASE_URL/auth/v1/otp" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"phone\": \"$PHONE\"
  }"

echo ""
echo ""
echo "如果配置正确，手机应该收到验证码短信"
