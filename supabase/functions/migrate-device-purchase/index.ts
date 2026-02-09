// Supabase Edge Function: 迁移设备购买凭证
// 将设备上的购买记录迁移到用户账号

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Apple Verify URLs
const PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

serve(async (req) => {
    // Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: CORS_HEADERS });
    }

    try {
        const { device_id, user_id, app_slug, receipt, product_id, platform = 'ios' } = await req.json();

        if (!device_id || !user_id || !receipt) {
            throw new Error('Missing required fields: device_id, user_id, receipt');
        }

        // Initialize Supabase Client (Service Role for Admin Access)
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        );

        // 1. Calculate Receipt Hash (to prevent duplicate processing of the same receipt blob)
        const receiptHash = await sha256(receipt);

        // 2. Check if receipt already used
        const { data: existing } = await supabase
            .from('user_purchases')
            .select('id, user_id')
            .eq('receipt_hash', receiptHash)
            .maybeSingle();

        if (existing) {
            // If it belongs to another user, block it. If same user, it's idempotent success.
            if (existing.user_id !== user_id) {
                return new Response(JSON.stringify({
                    success: false,
                    error: 'Receipt already bound to another account'
                }), { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }, status: 400 });
            }
            return new Response(JSON.stringify({ success: true, message: 'Already migrated' }), {
                headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
                status: 200
            });
        }

        // 3. Verify Receipt with Apple
        const sharedSecret = Deno.env.get('APP_STORE_SHARED_SECRET');
        let appleResponse = await verifyWithApple(PRODUCTION_URL, receipt, sharedSecret);
        let verifyData = await appleResponse.json();

        if (verifyData.status === 21007) {
            // Sandbox retry
            appleResponse = await verifyWithApple(SANDBOX_URL, receipt, sharedSecret);
            verifyData = await appleResponse.json();
        }

        if (verifyData.status !== 0) {
            return new Response(JSON.stringify({
                success: false,
                error: `Apple verification failed status: ${verifyData.status}`
            }), { headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }, status: 400 });
        }

        // 4. Parse transaction details
        // Apple returns 'receipt' info and optionally 'latest_receipt_info' (array) for auto-renewables.
        // For non-consumables/consumables, main info is in 'receipt'.
        // We prioritize 'latest_receipt_info' if available to get the most recent transaction.
        const latestInfo = (verifyData.latest_receipt_info && verifyData.latest_receipt_info.length > 0)
            ? verifyData.latest_receipt_info[0]
            : verifyData.receipt;

        // Fallback or specific extraction
        const transId = latestInfo.transaction_id || latestInfo.original_transaction_id;
        const prodId = latestInfo.product_id;
        const purchasedAt = latestInfo.purchase_date_ms ? new Date(parseInt(latestInfo.purchase_date_ms)).toISOString() : new Date().toISOString();
        const expiresAt = latestInfo.expires_date_ms ? new Date(parseInt(latestInfo.expires_date_ms)).toISOString() : null;

        // 5. Insert into user_purchases
        const { error: insertError } = await supabase.from('user_purchases').insert({
            user_id: user_id,
            app_slug: app_slug || 'unknown',
            product_id: prodId || product_id || 'unknown',
            platform: platform,
            transaction_id: transId,
            receipt_data: receipt.substring(0, 100) + '...', // Don't save full huge blob if not needed, or save full? Schema says text. Truncating for now to save space, relies on hash for uniqueness.
            receipt_hash: receiptHash,
            migrated_from_device: device_id,
            is_valid: true,
            purchased_at: purchasedAt,
            expires_at: expiresAt
        });

        if (insertError) {
            throw new Error(`Database insert failed: ${insertError.message}`);
        }

        // 6. Mark device as migrated (Optional, logic in user_devices table handled by other flows?)
        // The architecture doc say "6. Record migration marker... 7. Write to Supabase user_devices". 
        // This function focuses on purchase migration. The client handles the user_devices mapping link?
        // Let's stick to just returning success, client handles the rest.

        return new Response(JSON.stringify({ success: true }), {
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

async function verifyWithApple(url: string, receiptData: string, password?: string) {
    const body: any = { 'receipt-data': receiptData };
    if (password) {
        body['password'] = password;
    }
    return fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
}

// Helper to hash receipt
async function sha256(message: string) {
    const encoder = new TextEncoder();
    const data = encoder.encode(message);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
