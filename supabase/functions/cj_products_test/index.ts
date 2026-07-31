/**
 * cj_products_test — Diagnóstico de latência (isolamento).
 *
 * 4 variações em paralelo, timeout de 30s cada:
 *   (a) campos mínimos, limit 5, sem keyword
 *   (b) campos mínimos, limit 50, sem keyword
 *   (c) campos completos (com linkCode/salePrice/brand), limit 5, sem keyword
 *   (d) campos completos, limit 5, keyword "ecoflow"
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const MINIMAL_FIELDS = `id title price { amount currency }`;
const FULL_FIELDS = `id title description brand price { amount currency } salePrice { amount currency } imageLink linkCode(pid: "7988263") { clickUrl }`;

async function timedQuery(
  label: string,
  token: string,
  query: string,
  timeoutMs = 30000,
): Promise<Record<string, unknown>> {
  const start = Date.now();
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch("https://ads.api.cj.com/query", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ query, variables: {} }),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);
    const text = await response.text();
    const elapsed = Date.now() - start;
    let parsed: unknown = null;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = text.slice(0, 300);
    }
    return { label, httpStatus: response.status, elapsedMs: elapsed, body: parsed };
  } catch (error) {
    clearTimeout(timeoutId);
    return {
      label,
      elapsedMs: Date.now() - start,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const companyId = Deno.env.get("CJ_WEBSITE_ID")?.trim() ?? "7988263";
  const token = Deno.env.get("CJ_PERSONAL_ACCESS_TOKEN")?.trim();
  const ecoflowAdvertiserId = "5815804";

  if (!token) {
    return jsonResponse(
      { success: false, error: "CJ_PERSONAL_ACCESS_TOKEN not configured." },
      500,
    );
  }

  const base = (fields: string, limit: number, kw = "") =>
    `{ products(companyId: "${companyId}", ${kw ? `keywords: [${kw}], ` : ""}partnerIds: ["${ecoflowAdvertiserId}"], limit: ${limit}, offset: 0) { totalCount resultList { ${fields} } } }`;

  const queries: Record<string, string> = {
    a_minimal_limit5: base(MINIMAL_FIELDS, 5),
    b_minimal_limit50: base(MINIMAL_FIELDS, 50),
    c_full_limit5: base(FULL_FIELDS, 5),
    d_full_limit5_keyword: base(FULL_FIELDS, 5, `"ecoflow"`),
  };

  const results = await Promise.all(
    Object.entries(queries).map(([label, query]) =>
      timedQuery(label, token, query),
    ),
  );

  return jsonResponse({ success: true, companyIdUsed: companyId, results });
});
