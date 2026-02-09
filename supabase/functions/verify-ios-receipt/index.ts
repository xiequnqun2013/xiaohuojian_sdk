// Supabase Edge Function: 验证 iOS 内购收据
// 用于验证 App Store 购买凭证的有效性

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Apple Verify Receipt Endpoints
const PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

interface VerifyRequest {
    receiptData: string; // Base64 encoded receipt data
    excludeOldTransactions?: boolean;
}

serve(async (req) => {
    // Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: CORS_HEADERS });
    }

    try {
        // 1. Get request body
        const { receiptData, excludeOldTransactions = false }: VerifyRequest = await req.json();

        if (!receiptData) {
            throw new Error('Missing receiptData');
        }

        // 2. Get Shared Secret from env
        const sharedSecret = Deno.env.get('APP_STORE_SHARED_SECRET');
        if (!sharedSecret) {
            console.warn('APP_STORE_SHARED_SECRET is not set');
        }

        // 3. Verify logic (Sandbox fallback)
        // First try Production
        let response = await verifyWithApple(PRODUCTION_URL, receiptData, sharedSecret, excludeOldTransactions);
        let data = await response.json();

        // Status 21007 means "This receipt is from the test environment, but it was sent to the production environment for verification."
        if (data.status === 21007) {
            console.log('Production verification failed with 21007, retrying with Sandbox...');
            response = await verifyWithApple(SANDBOX_URL, receiptData, sharedSecret, excludeOldTransactions);
            data = await response.json();
        }

        // 4. Return result
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

async function verifyWithApple(url: string, receiptData: string, password?: string, excludeOldTransactions?: boolean) {
    const body: any = { 'receipt-data': receiptData };
    if (password) {
        body['password'] = password;
    }
    if (excludeOldTransactions) {
        body['exclude-old-transactions'] = excludeOldTransactions;
    }

    return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
}
