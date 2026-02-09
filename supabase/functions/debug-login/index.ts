// Supabase Edge Function: 调试登录 (Bypass SMS)
// 仅允许在测试环境使用，用于绕过短信验证直接登录
// 注意：生产环境严禁部署此函数或需严格鉴权

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    // Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: CORS_HEADERS });
    }

    try {
        const { phone } = await req.json();

        if (!phone) {
            throw new Error('Missing required field: phone');
        }

        // Initialize Supabase Client (Service Role for Admin Access)
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

        // format phone to +86... if not already
        const formattedPhone = phone.startsWith('+') ? phone : `+86${phone}`;
        const email = `${formattedPhone.replace('+', '')}@test.rocket`;
        const password = `test_${formattedPhone}`; // Simple deterministic password for test

        // 2. Try to Sign In with Password directly (assuming clean state or known user)
        let { data, error } = await supabaseAdmin.auth.signInWithPassword({
            email,
            password,
        });

        // 3. If User doesn't exist, Create User
        if (error && error.message.includes('Invalid login credentials')) {
            console.log(`User not found, creating user: ${email}`);

            const { data: createData, error: createError } = await supabaseAdmin.auth.admin.createUser({
                email,
                password,
                phone: formattedPhone, // Link phone number
                email_confirm: true,
                phone_confirm: true,
                user_metadata: { is_test_user: true }
            });

            if (createError) {
                // If phone is taken, we might collide with existing real user.
                // In that case, we can try to update THAT user's password? No, unsafe.
                // Just error out and say "Phone already taken by real user".
                throw new Error(`Failed to create test user (Phone/Email collision?): ${createError.message}`);
            }

            // Sign in again
            const res = await supabaseAdmin.auth.signInWithPassword({
                email,
                password,
            });
            data = res.data;
            error = res.error;
        }

        if (error || !data.session) {
            throw new Error(`Failed to sign in test user: ${error?.message}`);
        }

        return new Response(JSON.stringify(data), {
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
