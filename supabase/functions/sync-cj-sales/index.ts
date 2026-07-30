import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { CJClient } from "./cj_client.ts";
import { mapCJRecordToSale } from "./mapper.ts";
import {
  createSyncLog,
  findAffiliateIdBySid,
  insertSales,
  transactionExists,
  updateSyncLog,
} from "./database.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const cjToken = Deno.env.get("CJ_PERSONAL_ACCESS_TOKEN");
  const cjWebsiteId = Deno.env.get("CJ_WEBSITE_ID");

  if (!supabaseUrl || !supabaseKey || !cjToken || !cjWebsiteId) {
    return new Response(
      JSON.stringify({ success: false, error: "Missing required environment variables" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ success: false, error: "Unauthorized" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  const logId = await createSyncLog(supabase, {
    started_at: new Date().toISOString(),
    finished_at: null,
    transactions_read: 0,
    transactions_imported: 0,
    transactions_skipped: 0,
    unknown_sid: 0,
    status: "running",
    error_message: null,
  });

  try {
    const cj = new CJClient(cjToken, cjWebsiteId);

    const { startDate, endDate } = getDateRange(req);

    const records = await cj.fetchAllCommissions(startDate, endDate);

    let imported = 0;
    let skipped = 0;
    let unknownSid = 0;

    for (const record of records) {
      const sid = String(record.publisherId);

      const affiliateId = await findAffiliateIdBySid(supabase, sid);

      if (!affiliateId) {
        unknownSid++;
        console.log(`SID not found: ${sid}, transaction: ${record.transactionId}`);
        continue;
      }

      const exists = await transactionExists(
        supabase,
        String(record.transactionId),
      );

      if (exists) {
        skipped++;
        continue;
      }

      const sale = mapCJRecordToSale(record, affiliateId);

      await insertSales(supabase, [sale]);
      imported++;
    }

    await updateSyncLog(supabase, logId, {
      finished_at: new Date().toISOString(),
      transactions_read: records.length,
      transactions_imported: imported,
      transactions_skipped: skipped,
      unknown_sid: unknownSid,
      status: "success",
    });

    return new Response(
      JSON.stringify({
        success: true,
        transactionsRead: records.length,
        transactionsImported: imported,
        transactionsSkipped: skipped,
        unknownSid: unknownSid,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unknown error";

    await updateSyncLog(supabase, logId, {
      finished_at: new Date().toISOString(),
      status: "error",
      error_message: message,
    });

    return new Response(
      JSON.stringify({ success: false, error: message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

function getDateRange(req: Request): {
  startDate: string;
  endDate: string;
} {
  const url = new URL(req.url);
  const start = url.searchParams.get("start_date");
  const end = url.searchParams.get("end_date");

  if (start && end) {
    return { startDate: start, endDate: end };
  }

  const now = new Date();
  const thirtyDaysAgo = new Date(now);
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  return {
    startDate: formatDate(thirtyDaysAgo),
    endDate: formatDate(now),
  };
}

function formatDate(d: Date): string {
  return d.toISOString().split("T")[0];
}
