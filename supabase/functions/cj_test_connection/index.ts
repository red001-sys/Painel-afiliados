/**
 * CJ Affiliate Test Connection Edge Function.
 *
 * Validates:
 *   1. User is authenticated (Authorization header)
 *   2. CJ secrets are configured (CJ_PERSONAL_ACCESS_TOKEN, CJ_WEBSITE_ID)
 *   3. CJ API is reachable and returns valid data
 *
 * Features:
 *   - Auth check via Supabase JWT verification
 *   - 15s timeout on CJ API requests
 *   - Automatic retry on 429 (rate limit) with 2s delay
 *   - Detailed error messages for each failure type
 *
 * Response: ConnectionTestResult | ConnectionTestError
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { CJClient } from "./cj_client.ts";
import { loadCJConfig } from "./config.ts";
import { ConnectionTestResult, ConnectionTestError } from "./types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_RETRIES = 1;
const RETRY_DELAY_MS = 2000;

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ success: false, error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(
      { success: false, error: "Supabase env not configured." },
      500,
    );
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return jsonResponse({ success: false, error: "Unauthorized" }, 401);
  }

  const config = loadCJConfig();

  if ("error" in config) {
    return jsonResponse(
      { success: false, error: config.error } satisfies ConnectionTestError,
      500,
    );
  }

  const client = new CJClient(config.token, config.websiteId);

  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const { data } = await client.testConnection();

      const recordsFound = data.metadata?.totalResults ?? 0;
      const firstRecord = data.data?.[0] ?? null;

      const result: ConnectionTestResult = {
        success: true,
        apiReachable: true,
        recordsFound,
        sampleTransaction: firstRecord
          ? {
              transactionId: String(firstRecord.transactionId ?? ""),
              sid: String(firstRecord.publisherId ?? ""),
              advertiser: String(firstRecord.advertiserName ?? ""),
              saleAmount: String(firstRecord.saleAmount ?? "0"),
              commissionAmount: String(firstRecord.commissionAmount ?? "0"),
            }
          : null,
      };

      return jsonResponse(result, 200);
    } catch (error) {
      lastError =
        error instanceof Error
          ? error
          : new Error(
              (error as { message?: string })?.message ?? "Unknown error",
            );

      const statusCode =
        (error as { statusCode?: number })?.statusCode ?? 500;

      if (statusCode === 429 && attempt < MAX_RETRIES) {
        await new Promise((r) => setTimeout(r, RETRY_DELAY_MS));
        continue;
      }

      return jsonResponse(
        {
          success: false,
          error: lastError.message,
          statusCode,
        } satisfies ConnectionTestError,
        statusCode,
      );
    }
  }

  return jsonResponse(
    {
      success: false,
      error: lastError?.message ?? "Unknown error",
      statusCode: 500,
    } satisfies ConnectionTestError,
    500,
  );
});

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
