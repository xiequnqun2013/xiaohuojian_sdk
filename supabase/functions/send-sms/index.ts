// Edge Function: 发送短信验证码
// 使用阿里云短信服务 SDK

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// 阿里云 SDK (模拟实现，因为 Edge Function 中无法直接使用 npm 包)
// 实际部署时需要使用阿里云官方 SDK 或自定义实现

// 阿里云短信配置（通过环境变量注入）
const SMS_CONFIG = {
  accessKeyId: Deno.env.get('ALIBABA_CLOUD_ACCESS_KEY_ID') || '',
  accessKeySecret: Deno.env.get('ALIBABA_CLOUD_ACCESS_KEY_SECRET') || '',
  endpoint: 'dysmsapi.aliyuncs.com',
  regionId: 'cn-hangzhou',
  signName: Deno.env.get('SMS_SIGN_NAME') || '小火箭',
  templateCode: Deno.env.get('SMS_TEMPLATE_CODE') || 'SMS_123456789',
};

interface SMSRequest {
  phone: string;
  templateParam?: Record<string, string>;
}

// URL 编码（按照阿里云 RFC 3986 规范）
function percentEncode(str: string): string {
  // 按照阿里云文档的 RFC 3986 编码规则
  return encodeURIComponent(str)
    .replace(/!/g, '%21')
    .replace(/'/g, '%27')
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29')
    .replace(/\*/g, '%2A')
    .replace(/~/g, '%7E');
}

// 生成阿里云签名
async function generateSignature(
  method: string,
  params: Record<string, string>
): Promise<string> {
  // 1. 排序参数
  const sortedParams = Object.entries(params)
    .filter(([_, value]) => value !== undefined && value !== '')
    .sort(([a], [b]) => (a < b ? -1 : 1));

  // 2. 构建 Canonical Query String
  const canonicalQueryString = sortedParams
    .map(([key, value]) => {
      return `${percentEncode(key)}=${percentEncode(value)}`;
    })
    .join('&');

  // 3. 构建 StringToSign
  const stringToSign = `${method}&${percentEncode('/')}&${percentEncode(canonicalQueryString)}`;

  // 4. HMAC-SHA1 签名
  const key = `${SMS_CONFIG.accessKeySecret}&`;
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

  return signatureBase64;
}

// 调用阿里云发送短信
async function sendSMS(
  phone: string,
  code: string
): Promise<{ success: boolean; message: string; requestId?: string }> {
  // 格式化手机号（去掉 +86）
  const formattedPhone = phone.startsWith('+86') ? phone.slice(3) : phone;

  // 生成时间戳（阿里云要求 UTC 时间，格式 YYYY-MM-DDTHH:MM:SSZ）
  const isoString = new Date().toISOString();
  const timestamp = isoString.substring(0, 19) + 'Z';
  const nonce = crypto.randomUUID();

  // 构建参数
  const params: Record<string, string> = {
    AccessKeyId: SMS_CONFIG.accessKeyId,
    Action: 'SendSms',
    Format: 'JSON',
    PhoneNumbers: formattedPhone,
    SignName: SMS_CONFIG.signName,
    SignatureMethod: 'HMAC-SHA1',
    SignatureNonce: nonce,
    SignatureVersion: '1.0',
    TemplateCode: SMS_CONFIG.templateCode,
    TemplateParam: JSON.stringify({ code }),
    Timestamp: timestamp,
    Version: '2017-05-25',
  };

  // 生成签名
  const signature = await generateSignature('GET', params);
  params.Signature = signature;

  // 构建 URL
  const queryString = Object.entries(params)
    .map(([key, value]) => {
      return `${percentEncode(key)}=${percentEncode(value)}`;
    })
    .join('&');

  const url = `https://${SMS_CONFIG.endpoint}/?${queryString}`;

  console.log('SMS Request URL:', url);
  console.log('Raw timestamp:', new Date().toISOString());
  console.log('Formatted timestamp:', timestamp);

  try {
    const response = await fetch(url, { method: 'GET' });
    const data = await response.json();

    console.log('SMS Response:', data);

    if (data.Code === 'OK') {
      return {
        success: true,
        message: '发送成功',
        requestId: data.RequestId,
      };
    } else {
      return {
        success: false,
        message: `发送失败: ${data.Message} (${data.Code})`,
        requestId: data.RequestId,
      };
    }
  } catch (error) {
    return {
      success: false,
      message: `请求异常: ${error.message}`,
    };
  }
}

serve(async (req) => {
  // 1. 检查请求方法
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // 2. 验证身份 (JWT 或 Service Role Key 或 Anon Key)
  const authHeader = req.headers.get('Authorization');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';

  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // 检查是否是 Service Role Key 或 Anon Key (用于测试)
  const token = authHeader.replace('Bearer ', '');
  const isServiceRole = token === serviceRoleKey;
  const isAnonKey = token === anonKey;

  if (!isServiceRole && !isAnonKey) {
    // 验证 JWT (用户登录后的 token)
    try {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        serviceRoleKey
      );
      const { data: { user }, error } = await supabase.auth.getUser(token);
      if (error || !user) {
        return new Response(
          JSON.stringify({ error: 'Invalid token' }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        );
      }
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  try {
    // 3. 解析请求体
    const body: SMSRequest = await req.json();
    const { phone, templateParam } = body;

    if (!phone) {
      return new Response(
        JSON.stringify({ error: '手机号不能为空' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // 4. 生成验证码（6位数字）
    const code = templateParam?.code || Math.floor(100000 + Math.random() * 900000).toString();

    console.log(`Sending SMS to ${phone}, code: ${code}`);

    // 5. 调用阿里云发送短信
    const result = await sendSMS(phone, code);

    if (result.success) {
      return new Response(
        JSON.stringify({
          success: true,
          message: '验证码发送成功',
          requestId: result.requestId,
          code: code,
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    } else {
      return new Response(
        JSON.stringify({
          error: result.message,
          requestId: result.requestId,
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: '服务器错误', message: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
