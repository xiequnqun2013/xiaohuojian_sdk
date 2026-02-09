
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";

// Config from MCP settings (as seen in .mcp.json)
const API_URL = "http://42.121.49.212:8080";
const SERVICE_ROLE_KEY = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoicG9sYXJkYiIsImlhdCI6MTc3MDQ0Mzc3NSwiZXhwIjoyMDg1ODAzNzc1fQ.iKeej68ZEKJZpAeG8R4YPkGpzsVzVAPc6hwD3BdmqyA";

console.log(`Testing against API_URL: ${API_URL}`);

// Test send-sms
async function testSendSms() {
    console.log("\n[TEST] send-sms");
    const url = `${API_URL}/functions/v1/send-sms`;

    const res = await fetch(url, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            phone: "+8613800138000",
            templateParam: { code: "123456" } // Using fixed code to avoid wasting SMS quota if real? But here it is mocked.
        }),
    });

    const data = await res.json();
    console.log("Status:", res.status);
    console.log("Response:", data);

    if (res.status === 200 && data.success) {
        console.log("✅ send-sms PASSED");
    } else {
        console.error("❌ send-sms FAILED");
    }
}

// Test get-oss-sts
async function testGetOssSts() {
    console.log("\n[TEST] get-oss-sts");
    const url = `${API_URL}/functions/v1/get-oss-sts`;

    const res = await fetch(url, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            env: "test",
            appSlug: "demo-app"
        }),
    });

    const data = await res.json();
    console.log("Status:", res.status);
    console.log("Response:", data);

    if (res.status === 200 && data.accessKeyId) {
        console.log("✅ get-oss-sts PASSED");
    } else {
        console.error("❌ get-oss-sts FAILED");
    }
}

await testSendSms();
await testGetOssSts();
