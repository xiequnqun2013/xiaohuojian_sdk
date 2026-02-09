
// Supabase Edge Function: 微信登录 (Auth WeChat)
// 1. 接收 code
// 2. 换取 openid
// 3. 自动注册/登录 Supabase 用户
// 4. 返回 Session (Access Token)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// WeChat API
const WECHAT_URL = 'https://api.weixin.qq.com/sns/jscode2session';

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: CORS_HEADERS });
    }

    try {
        const { code } = await req.json();
        if (!code) throw new Error('Missing code');

        // 1. Get Secrets
        const appId = Deno.env.get('WECHAT_APP_ID');
        const appSecret = Deno.env.get('WECHAT_APP_SECRET');
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

        if (!appId || !appSecret) {
            throw new Error('WECHAT_APP_ID or WECHAT_APP_SECRET not set');
        }

        // 2. Call WeChat API
        const wechatRes = await fetch(`${WECHAT_URL}?appid=${appId}&secret=${appSecret}&js_code=${code}&grant_type=authorization_code`);
        const wechatData = await wechatRes.json();

        if (wechatData.errcode) {
            throw new Error(`WeChat API Error: ${wechatData.errmsg}`);
        }

        const { openid, session_key } = wechatData;

        // 3. Deterministic User Identity
        const email = `wechat_${openid}@rocket-workshop.anonymous`;
        // Generate a secure password derived from openid and appSecret (so we can sign in repeatedly)
        const password = await hmacSha256(openid, appSecret);

        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        // 4. Try to sign in first (if user exists)
        let { data: sessionData, error: signInError } = await supabaseAdmin.auth.signInWithPassword({
            email,
            password,
        });

        // 5. If sign in fails, assume user needs to be created
        if (signInError) {
            // Create user
            const { data: signUpData, error: signUpError } = await supabaseAdmin.auth.admin.createUser({
                email,
                password,
                email_confirm: true,
                user_metadata: {
                    wechat_openid: openid,
                    avatar_url: '', // Can be updated later
                    full_name: 'WeChat User',
                }
            });

            if (signUpError) {
                // If create fails but it says "already registered", it means password might have changed or some other issue.
                // But normally signInWithPassword would have worked.
                throw new Error(`Create User Failed: ${signUpError.message}`);
            }

            // Auto sign in after creation to get session
            const { data: newSession, error: finalSignInError } = await supabaseAdmin.auth.signInWithPassword({
                email,
                password,
            });

            if (finalSignInError) throw finalSignInError;
            sessionData = newSession;
        }

        // 6. Return Session
        return new Response(JSON.stringify({
            user: sessionData.user,
            session: sessionData.session,
            openid // Optional: return openid if client needs it
        }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
            status: 200,
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
            status: 400,
        });
    }
});

// Helper: HMAC-SHA256 for deterministic password
async function hmacSha256(message: string, secret: string) {
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
        "raw",
        enc.encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );
    const signature = await crypto.subtle.sign("HMAC", key, enc.encode(message));
    return Array.from(new Uint8Array(signature)).map(b => b.toString(16).padStart(2, '0')).join('');
}
