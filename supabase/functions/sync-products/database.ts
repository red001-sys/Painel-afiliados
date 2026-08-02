import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { EcoFlowProduct } from "./types.ts";

export interface BulkUpsertResult {
  imported: number;
  updated: number;
  failed: number;
  lastError?: string;
}

const CHUNK_SIZE = 100;

/** Grava produtos em lote mantendo o campo `ativo` intacto em produtos que já
 * existem (o admin controla isso manualmente — a sincronização nunca deve
 * ligar/desligar visibilidade sozinha). Produtos novos entram INATIVOS. */
export async function bulkSyncEcoFlowProducts(
  supabase: SupabaseClient,
  products: EcoFlowProduct[],
): Promise<BulkUpsertResult> {
  const result: BulkUpsertResult = { imported: 0, updated: 0, failed: 0 };
  if (products.length === 0) return result;

  // 1. Descobre em lote quais produtos já existem (pelo cj_product_id)
  const existingIds = new Set<string>();
  for (let i = 0; i < products.length; i += CHUNK_SIZE) {
    const chunk = products.slice(i, i + CHUNK_SIZE).map((p) => p.cjProductId);
    const { data, error } = await supabase
      .from("products")
      .select("cj_product_id")
      .in("cj_product_id", chunk);

    if (error) {
      console.error(`Failed to load existing products: ${error.message}`);
      return result;
    }
    for (const row of data ?? []) existingIds.add(row.cj_product_id as string);
  }

  const toUpdate = products.filter((p) => existingIds.has(p.cjProductId));
  const toInsert = products.filter((p) => !existingIds.has(p.cjProductId));

  // 2. UPDATE em lote — sem mexer no campo ativo
  for (let i = 0; i < toUpdate.length; i += CHUNK_SIZE) {
    const chunk = toUpdate.slice(i, i + CHUNK_SIZE).map((p) => ({
      nome: p.nome,
      descricao: p.descricao,
      preco: p.preco,
      sale_price: p.precoPromocional,
      currency: p.moeda || "USD",
      brand: p.marca,
      imagem_url: p.imagemUrl,
      cj_url: p.cjUrl,
      cj_advertiser_id: p.cjAdvertiserId,
      cj_product_id: p.cjProductId,
      cj_last_synced_at: new Date().toISOString(),
    }));

    const { error } = await supabase.from("products").upsert(chunk, {
      onConflict: "cj_product_id",
      ignoreDuplicates: false,
    });

    if (error) {
      console.error(`Failed to update product batch: ${error.message}`);
      result.failed += chunk.length;
      result.lastError = error.message;
    } else {
      result.updated += chunk.length;
    }
  }

  // 3. INSERT em lote — novos entram ativo = false
  for (let i = 0; i < toInsert.length; i += CHUNK_SIZE) {
    const chunk = toInsert.slice(i, i + CHUNK_SIZE).map((p) => ({
      nome: p.nome,
      descricao: p.descricao,
      preco: p.preco,
      sale_price: p.precoPromocional,
      currency: p.moeda || "USD",
      brand: p.marca,
      imagem_url: p.imagemUrl,
      cj_url: p.cjUrl,
      cj_advertiser_id: p.cjAdvertiserId,
      cj_product_id: p.cjProductId,
      cj_last_synced_at: new Date().toISOString(),
      ativo: false,
    }));

    const { error } = await supabase.from("products").upsert(chunk, {
      onConflict: "cj_product_id",
      ignoreDuplicates: false,
    });

    if (error) {
      console.error(`Failed to insert product batch: ${error.message}`);
      result.failed += chunk.length;
      result.lastError = error.message;
    } else {
      result.imported += chunk.length;
    }
  }

  return result;
}
