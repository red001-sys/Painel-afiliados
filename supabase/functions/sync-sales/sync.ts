import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Transaction, SyncResult } from "./types.ts";
import { AffiliateProvider } from "./providers/provider.ts";
import {
  findAffiliateIdBySid,
  clearSidCache,
  getSaleByTransactionId,
  insertSale,
  updateSale,
} from "./database.ts";
import { SyncLogger } from "./logger.ts";

export async function runSync(
  supabase: SupabaseClient,
  provider: AffiliateProvider,
  startDate: string,
  endDate: string,
  logger: SyncLogger,
): Promise<SyncResult> {
  const startMs = Date.now();
  clearSidCache();

  const transactions = await provider.fetchTransactions(startDate, endDate);

  let imported = 0;
  let updated = 0;
  let duplicates = 0;
  let unknownSid = 0;
  let failed = 0;
  let lastDate = startDate;

  for (const tx of transactions) {
    try {
      if (tx.saleDate > lastDate) {
        lastDate = tx.saleDate;
      }

      const affiliateId = await findAffiliateIdBySid(
        supabase,
        tx.affiliateSid,
      );

      if (!affiliateId) {
        unknownSid++;
        continue;
      }

      const existing = await getSaleByTransactionId(
        supabase,
        tx.transactionId,
      );

      if (existing) {
        const wasUpdated = await updateSale(supabase, existing.id, tx);
        if (wasUpdated) {
          updated++;
        } else {
          duplicates++;
        }
        continue;
      }

      const inserted = await insertSale(supabase, tx, affiliateId);

      if (inserted) {
        imported++;
      } else {
        duplicates++;
      }
    } catch (error) {
      console.error(
        `Failed to process transaction ${tx.transactionId}: ${error instanceof Error ? error.message : String(error)}`,
      );
      failed++;
      continue;
    }
  }

  const durationMs = Date.now() - startMs;

  await logger.finish({
    read: transactions.length,
    imported,
    updated,
    duplicates,
    unknownSid,
    failed,
  });

  return {
    success: failed === 0,
    read: transactions.length,
    imported,
    updated,
    duplicates,
    unknownSid,
    failed,
    durationMs,
  };
}
