#!/bin/bash

# Edge Functions 部署脚本（短信 + OSS STS）

echo "═══════════════════════════════════════════════════════════"
echo "🚀 部署 Edge Functions"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 检查 supabase CLI
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI 未安装"
    echo ""
    echo "安装方法："
    echo "   brew install supabase/tap/supabase  # macOS"
    echo "   npm install -g supabase             # npm"
    echo ""
    exit 1
fi

# 检查是否登录
if ! supabase projects list &> /dev/null; then
    echo "🔑 请先登录 Supabase"
    echo "   supabase login"
    exit 1
fi

echo "📋 需要设置的环境变量："
echo ""
echo "【短信服务】"
echo "   ALIBABA_CLOUD_ACCESS_KEY_ID=你的阿里云AccessKey ID"
echo "   ALIBABA_CLOUD_ACCESS_KEY_SECRET=你的阿里云AccessKey Secret"
echo "   SMS_SIGN_NAME=你的短信签名"
echo "   SMS_TEMPLATE_CODE=你的短信模板CODE"
echo ""
echo "【OSS STS服务】"
echo "   OSS_ACCESS_KEY_ID=你的阿里云OSS AccessKey ID"
echo "   OSS_ACCESS_KEY_SECRET=你的阿里云OSS AccessKey Secret"
echo "   OSS_ROLE_ARN=acs:ram::xxxx:role/xxxx"
echo "   OSS_BUCKET=rocket-workshop"
echo "   OSS_ENDPOINT=oss-cn-beijing.aliyuncs.com"
echo "   OSS_REGION=cn-beijing"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# 链接项目
echo "1️⃣ 链接项目..."
supabase link --project-ref default
echo ""

# 部署 send-sms
echo "2️⃣ 部署 send-sms..."
supabase functions deploy send-sms
echo ""

# 部署 get-oss-sts
echo "3️⃣ 部署 get-oss-sts..."
supabase functions deploy get-oss-sts
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "✅ 部署完成"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "测试命令："
echo ""
echo "# 测试短信发送"
echo "curl -X POST 'http://42.121.49.212:8080/functions/v1/send-sms' \\"
echo "  -H 'Authorization: Bearer YOUR_JWT' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"phone\":\"+8618520160445\"}'"
echo ""
echo "# 测试 OSS STS"
echo "curl -X POST 'http://42.121.49.212:8080/functions/v1/get-oss-sts' \\"
echo "  -H 'Authorization: Bearer YOUR_JWT' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"env\":\"test\",\"appSlug\":\"shenlun\"}'"
echo ""
