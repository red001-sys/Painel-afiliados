import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadConfig } from "./config.ts";
import { createSyncLogger } from "./logger.ts";
import { runSync } from "./sync.ts";
import { getSyncState, upsertSyncState } from "./database.ts";
import { CJProvider } from "./providers/cj_provider.ts";
import { SyncResult } from "./types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_LOOKBACK_DAYS = 90;
const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

function isValidDate(dateStr: string): boolean {
  if (!DATE_REGEX.test(dateStr)) return false;
  const d = new Date(dateStr);
  return !isNaN(d.getTime());
}

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

  const supabaseAuth = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabaseAuth.auth.getUser();

  if (authError || !user) {
    return jsonResponse({ success: false, error: "Unauthorized" }, 401);
  }

  let config;
  try {
    config = loadConfig();
  } catch (error) {
    return jsonResponse(
      { success: false, error: (error as Error).message },
      500,
    );
  }

  if (!config.cj) {
    return jsonResponse(
      {
        success: false,
        error:
          "CJ secrets not configured. Set CJ_PERSONAL_ACCESS_TOKEN and CJ_WEBSITE_ID.",
      },
      500,
    );
  }

  const supabase = createClient(
    config.supabase.url,
    config.supabase.serviceRoleKey,
  );
  const provider = new CJProvider(config.cj);

  let logger;
  try {
    logger = await createSyncLogger(supabase);
  } catch (error) {
    return jsonResponse(
      { success: false, error: "Failed to create sync log: " + (error as Error).message },
      500,
    );
  }

  try {
    const url = new URL(req.url);
    const overrideStart = url.searchParams.get("start_date");
    const overrideEnd = url.searchParams.get("end_date");

    if (overrideStart && !isValidDate(overrideStart)) {
      return jsonResponse(
        { success: false, error: "Invalid start_date format. Use YYYY-MM-DD." },
        400,
      );
    }
    if (overrideEnd && !isValidDate(overrideEnd)) {
      return jsonResponse(
        { success: false, error: "Invalid end_date format. Use YYYY-MM-DD." },
        400,
      );
    }

    const syncState = await getSyncState(supabase, provider.name);

    let startDate: string;
    const endDate = overrideEnd || new Date().toISOString().split("T")[0];

    if (overrideStart) {
      startDate = overrideStart;
    } else if (syncState?.last_transaction_date) {
      const lastDate = new Date(syncState.last_transaction_date);
      lastDate.setDate(lastDate.getDate() - 1);
      startDate = lastDate.toISOString().split("T")[0];
    } else {
      const lookback = new Date();
      lookback.setDate(lookback.getDate() - DEFAULT_LOOKBACK_DAYS);
      startDate = lookback.toISOString().split("T")[0];
    }

    const result = await runSync(
      supabase,
      provider,
      startDate,
      endDate,
      logger,
    );

    if (result.read > 0) {
      try {
        await upsertSyncState(supabase, provider.name, endDate);
      } catch (_stateError) {
        // Log but don't fail the sync
      }
    }

    return jsonResponse(result, 200);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unknown error";

    await logger.finish({
      read: 0,
      imported: 0,
      updated: 0,
      duplicates: 0,
      unknownSid: 0,
      failed: 1,
      durationMs: 0,
      error: message,
    });

    const result: SyncResult = {
      success: false,
      read: 0,
      imported: 0,
      updated: 0,
      duplicates: 0,
      unknownSid: 0,
      failed: 1,
      durationMs: 0,
      error: message,
    };

    return jsonResponse(result, 500);
  }
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
