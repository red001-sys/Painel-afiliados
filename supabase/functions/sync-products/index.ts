import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadConfig } from "./config.ts";
import {
  CJEcoFlowProductProvider,
  ECOTLOW_ADVERTISER_ID,
  mapToEcoFlowProduct,
} from "./cj_client.ts";
import { bulkSyncEcoFlowProducts } from "./database.ts";
import { EcoFlowProduct, EcoFlowSyncResult } from "./types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PAGE_LIMIT = 50;
// Busca até 4 páginas ao mesmo tempo pra não estourar o tempo da função.
const CONCURRENCY = 4;
// Limite de segurança: 100 páginas = até 5.000 produtos por execução.
// A EcoFlow tem ~1.255 produtos hoje, então sobra folga.
const MAX_PAGES = 100;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Busca todas as páginas do catálogo, respeitando a concorrência. */
async function fetchAllPages(
  provider: CJEcoFlowProductProvider,
): Promise<{ products: EcoFlowProduct[]; totalAvailable: number; pagesFetched: number }> {
  const products: EcoFlowProduct[] = [];
  let offset = 0;
  let pagesFetched = 0;
  let totalAvailable = 0;
  let done = false;

  while (!done && pagesFetched < MAX_PAGES) {
    const offsets = Array.from(
      { length: CONCURRENCY },
      (_, i) => offset + i * PAGE_LIMIT,
    );

    const pages = await Promise.all(
      offsets.map((o) => provider.searchProducts(o, PAGE_LIMIT)),
    );

    for (const { page } of pages) {
      pagesFetched++;
      totalAvailable = page.totalCount;
      if (page.resultList.length === 0) {
        done = true;
        break;
      }
      for (const record of page.resultList) {
        products.push(mapToEcoFlowProduct(record));
      }
    }

    offset += CONCURRENCY * PAGE_LIMIT;
  }

  return { products, totalAvailable, pagesFetched };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startMs = Date.now();

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ success: false, error: "Unauthorized" }, 401);
  }

  try {
    const config = loadConfig();

    // Verifica que quem chamou é um admin autenticado antes de fazer
    // qualquer trabalho. Sem isso, qualquer pessoa com a anon key pública
    // (visível em qualquer inspeção do app) conseguia disparar essa sync.
    const authClient = createClient(config.supabase.url, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await authClient.auth.getUser();
    if (authError || !user) {
      return jsonResponse({ success: false, error: "Unauthorized" }, 401);
    }

    const { data: profile } = await authClient
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();

    if (profile?.role !== "admin") {
      return jsonResponse({ success: false, error: "Forbidden: admin access required" }, 403);
    }

    if (!config.cj) {
      return jsonResponse(
        { success: false, error: "CJ_PERSONAL_ACCESS_TOKEN / CJ_WEBSITE_ID not configured" },
        500,
      );
    }

    const supabase = createClient(config.supabase.url, config.supabase.serviceRoleKey);
    const provider = new CJEcoFlowProductProvider(config.cj);

    const { products: all, totalAvailable, pagesFetched } =
      await fetchAllPages(provider);

    // Só o catálogo da EcoFlow em dólar — ignora feeds de outros países
    // (ex: Australia Store, que vem em AUD) sem travar o sync. A CJ repete o
    // mesmo produto em várias lojas/feeds, então deduplicamos por id (o upsert
    // ON CONFLICT falha se o mesmo id aparecer 2x no mesmo lote).
    const usdProducts: EcoFlowProduct[] = [];
    const seenIds = new Set<string>();
    for (const p of all) {
      if (p.moeda && p.moeda.toUpperCase() !== "USD") continue;
      if (seenIds.has(p.cjProductId)) continue;
      seenIds.add(p.cjProductId);
      usdProducts.push(p);
    }
    const skippedNonUsd = all.length - usdProducts.length;

    const { imported, updated, failed, lastError } =
      await bulkSyncEcoFlowProducts(supabase, usdProducts);

    const result: EcoFlowSyncResult = {
      success: failed === 0,
      advertiserId: ECOTLOW_ADVERTISER_ID,
      pagesFetched,
      totalAvailable,
      found: all.length,
      imported,
      updated,
      skippedNonUsd,
      failed,
      usedFallbackKeyword: provider.usedFallbackKeyword,
      durationMs: Date.now() - startMs,
      lastBatchError: lastError,
    };

    return jsonResponse(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse(
      {
        success: false,
        advertiserId: ECOTLOW_ADVERTISER_ID,
        pagesFetched: 0,
        totalAvailable: 0,
        found: 0,
        imported: 0,
        updated: 0,
        skippedNonUsd: 0,
        failed: 1,
        usedFallbackKeyword: false,
        durationMs: Date.now() - startMs,
        error: message,
      },
      500,
    );
  }
});
