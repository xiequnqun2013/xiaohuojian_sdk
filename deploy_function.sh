#!/bin/bash
# Edge Function 部署脚本（使用 Supabase CLI）

set -e

PROJECT_REF="ra-supabase-sb6xjntrfya75g"
FUNCTION_NAME="get-oss-sts"
SUPABASE_URL="http://rocketapi.lensflow.cn"

echo "═══════════════════════════════════════════════════════════"
echo "🚀 部署 Edge Function: $FUNCTION_NAME"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "项目: $PROJECT_REF"
echo "URL: $SUPABASE_URL"
echo ""

# 检查 Service Role Key
if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "⚠️  需要设置环境变量 SUPABASE_SERVICE_ROLE_KEY"
    echo ""
    echo "获取方法:"
    echo "   1. 访问 $SUPABASE_URL/project/default/settings/api"
    echo "   2. 复制 service_role key"
    echo ""
    read -s -p "请输入 Service Role Key: " KEY
    echo ""
    export SUPABASE_SERVICE_ROLE_KEY="$KEY"
fi

# 确保函数目录存在
mkdir -p supabase/functions/$FUNCTION_NAME

# 复制函数代码（如果不存在）
if [ ! -f "supabase/functions/$FUNCTION_NAME/index.ts" ]; then
    echo "📝 创建函数文件..."
    cat > supabase/functions/$FUNCTION_NAME/index.ts << 'EOF'
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const OSS_CONFIG = {
  accessKeyId: Deno.env.get('OSS_ACCESS_KEY_ID') || '',
  accessKeySecret: Deno.env.get('OSS_ACCESS_KEY_SECRET') || '',
  roleArn: Deno.env.get('OSS_ROLE_ARN') || '',
  bucket: Deno.env.get('OSS_BUCKET') || 'rocket-workshop',
  endpoint: Deno.env.get('OSS_ENDPOINT') || 'oss-cn-beijing.aliyuncs.com',
  region: Deno.env.get('OSS_REGION') || 'cn-beijing',
};

serve(async (req) => {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const env = body.env || 'test';
    const appSlug = body.appSlug || 'default';
    const pathPrefix = `${env}/users/${user.id}/${appSlug}/`;
    
    return new Response(
      JSON.stringify({
        accessKeyId: OSS_CONFIG.accessKeyId,
        accessKeySecret: OSS_CONFIG.accessKeySecret,
        bucket: OSS_CONFIG.bucket,
        endpoint: OSS_CONFIG.endpoint,
        region: OSS_CONFIG.region,
        pathPrefix: pathPrefix,
        userId: user.id,
        expiration: new Date(Date.now() + 3600 * 1000).toISOString(),
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
EOF
fi

# 部署函数
echo "📦 部署函数..."
echo ""

supabase functions deploy $FUNCTION_NAME \
  --project-ref $PROJECT_REF \
  --use-api 2>&1 || {
    echo ""
    echo "❌ 部署失败"
    echo ""
    echo "可能原因:"
    echo "   1. 自托管 Supabase 不支持 CLI 部署"
    echo "   2. 需要使用 Dashboard 手动部署"
    echo ""
    echo "替代方案:"
    echo "   访问 $SUPABASE_URL/project/default/functions"
    echo "   点击 'Deploy a new function' 手动部署"
    exit 1
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ 部署完成！"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "测试命令:"
echo "   curl -X POST $SUPABASE_URL/functions/v1/$FUNCTION_NAME \\"
echo "     -H \"Authorization: Bearer YOUR_JWT\" \\"
echo "     -d '{\"env\":\"test\",\"appSlug\":\"shenlun\"}'"
echo ""
