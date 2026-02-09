// Supabase Edge Function: 获取 OSS STS 临时凭证
// 用于 Flutter 客户端直传文件到阿里云 OSS

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// OSS 配置（通过环境变量注入）
const OSS_CONFIG = {
  accessKeyId: Deno.env.get('OSS_ACCESS_KEY_ID') || '',
  accessKeySecret: Deno.env.get('OSS_ACCESS_KEY_SECRET') || '',
  roleArn: Deno.env.get('OSS_ROLE_ARN') || '',
  bucket: Deno.env.get('OSS_BUCKET') || 'rocket-workshop',
  endpoint: Deno.env.get('OSS_ENDPOINT') || 'oss-cn-beijing.aliyuncs.com',
  region: Deno.env.get('OSS_REGION') || 'cn-beijing',
  durationSeconds: 3600, // 凭证有效期 1 小时
};

interface STSRequest {
  userId?: string;
  appSlug?: string;
  env?: 'test' | 'prod';
}

serve(async (req) => {
  // 1. 验证用户登录 (JWT 或 Service Role Key 或 Anon Key)
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const token = authHeader.replace('Bearer ', '');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';

  // 检查是否是 Service Role Key 或 Anon Key (用于测试)
  const isServiceRole = token === serviceRoleKey;
  const isAnonKey = token === anonKey;

  let userId = 'test-user';

  if (!isServiceRole && !isAnonKey) {
    // 验证 JWT (用户登录后的 token)
    try {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        serviceRoleKey
      );
      const { data: { user }, error: authError } = await supabase.auth.getUser(token);

      if (authError || !user) {
        return new Response(
          JSON.stringify({ error: 'Invalid token' }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        );
      }
      userId = user.id;
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  // 2. 获取请求参数
  const body: STSRequest = await req.json().catch(() => ({}));
  const env = body.env || 'test';
  const appSlug = body.appSlug || 'default';

  try {
    // 3. 构建 STS AssumeRole 请求
    const timestamp = new Date().toISOString();
    const nonce = crypto.randomUUID();

    const params = new URLSearchParams({
      Format: 'JSON',
      Version: '2015-04-01',
      AccessKeyId: OSS_CONFIG.accessKeyId,
      SignatureMethod: 'HMAC-SHA1',
      Timestamp: timestamp,
      SignatureVersion: '1.0',
      SignatureNonce: nonce,
      Action: 'AssumeRole',
      RoleArn: OSS_CONFIG.roleArn,
      RoleSessionName: `flutter-${userId.substring(0, 8)}`,
      DurationSeconds: OSS_CONFIG.durationSeconds.toString(),
    });

    // 计算签名
    const sortedParams = Array.from(params.entries())
      .sort(([a], [b]) => (a < b ? -1 : 1))
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join('&');

    const stringToSign = `GET&%2F&${encodeURIComponent(sortedParams)}`;
    const key = `${OSS_CONFIG.accessKeySecret}&`;

    // HMAC-SHA1 签名
    const encoder = new TextEncoder();
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      encoder.encode(key),
      { name: 'HMAC', hash: 'SHA-1' },
      false,
      ['sign']
    );

    const signature = await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(stringToSign));
    const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)));

    params.set('Signature', signatureBase64);

    // 4. 调用阿里云 STS
    const stsUrl = `https://sts.${OSS_CONFIG.region}.aliyuncs.com/?${params.toString()}`;

    const stsResponse = await fetch(stsUrl);
    const stsData = await stsResponse.json();

    if (!stsResponse.ok) {
      console.error('STS Error:', stsData);
      return new Response(
        JSON.stringify({ error: 'Failed to get STS token', details: stsData }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const credentials = stsData.Credentials;

    // 5. 返回凭证 + 配置
    return new Response(
      JSON.stringify({
        // STS 临时凭证
        accessKeyId: credentials.AccessKeyId,
        accessKeySecret: credentials.AccessKeySecret,
        securityToken: credentials.SecurityToken,
        expiration: credentials.Expiration,

        // OSS 配置
        bucket: OSS_CONFIG.bucket,
        endpoint: OSS_CONFIG.endpoint,
        region: OSS_CONFIG.region,

        // 路径前缀（环境隔离）
        pathPrefix: `${env}/users/${userId}/${appSlug}/`,

        // 允许的操作
        allowedOperations: ['PutObject', 'GetObject', 'ListObjects'],
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
