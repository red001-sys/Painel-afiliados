import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadConfig } from "./config.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const CJ_PRODUCTS_URL = "https://ads.api.cj.com/query";
const MAX_IDS_PER_CALL = 20; // mantém a chamada dentro do timeout (~1.5-2s/link)

interface CJProductRecord {
  id: string;
  linkCode: { clickUrl: string } | null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const config = loadConfig();
    if (!config.cj) {
      return jsonResponse(
        { success: false, error: "CJ_PERSONAL_ACCESS_TOKEN / CJ_WEBSITE_ID / CJ_PID não configurados" },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonResponse({ success: false, error: "Unauthorized" }, 401);

    const authClient = createClient(config.supabase.url, config.supabase.anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await authClient.auth.getUser();
    if (authError || !user) return jsonResponse({ success: false, error: "Unauthorized" }, 401);

    const { data: profile } = await authClient.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (profile?.role !== "admin") {
      return jsonResponse({ success: false, error: "Forbidden: admin access required" }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const productIds: string[] = Array.isArray(body.productIds) ? body.productIds : [];

    if (productIds.length === 0) {
      return jsonResponse({ success: false, error: "productIds vazio" }, 400);
    }
    if (productIds.length > MAX_IDS_PER_CALL) {
      return jsonResponse(
        { success: false, error: `Máximo ${MAX_IDS_PER_CALL} productIds por chamada` },
        400,
      );
    }

    const idsGraphQl = productIds.map((id) => `"${id}"`).join(", ");
    const query = `{ products(companyId: "${config.cj.companyId}", productIds: [${idsGraphQl}], advertiserCountries: ["US"], currency: "USD", limit: ${productIds.length}) { resultList { id linkCode(pid: "${config.cj.pid}") { clickUrl } } } }`;

    const response = await fetch(CJ_PRODUCTS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${config.cj.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ query, variables: {} }),
    });

    if (!response.ok) {
      const bodyPreview = (await response.text().catch(() => "")).slice(0, 500);
      return jsonResponse(
        { success: false, error: `CJ API error ${response.status}. Body: ${bodyPreview}` },
        502,
      );
    }

    const json = await response.json();
    if (json.errors?.length) {
      return jsonResponse(
        { success: false, error: `CJ GraphQL error: ${json.errors.map((e: { message: string }) => e.message).join("; ")}` },
        502,
      );
    }

    const records: CJProductRecord[] = json.data?.products?.resultList ?? [];
    const links: Record<string, string> = {};
    for (const r of records) {
      if (r.linkCode?.clickUrl) links[r.id] = r.linkCode.clickUrl;
    }

    const supabase = createClient(config.supabase.url, config.supabase.serviceRoleKey);
    let updated = 0;
    for (const [cjProductId, clickUrl] of Object.entries(links)) {
      const { error } = await supabase
        .from("products")
        .update({ cj_url: clickUrl })
        .eq("cj_product_id", cjProductId);
      if (!error) updated++;
    }

    return jsonResponse({
      success: true,
      requested: productIds.length,
      found: records.length,
      linked: Object.keys(links).length,
      updated,
      links,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ success: false, error: message }, 500);
  }
});
