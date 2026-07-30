import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Transaction, SyncLogData, SyncState } from "./types.ts";

const sidCache = new Map<string, string | null>();

export async function findAffiliateIdBySid(
  supabase: SupabaseClient,
  sid: string,
): Promise<string | null> {
  if (sidCache.has(sid)) {
    return sidCache.get(sid) ?? null;
  }

  const { data } = await supabase
    .from("affiliates")
    .select("id")
    .eq("sid", sid)
    .limit(1)
    .maybeSingle();

  const id = data?.id ?? null;
  sidCache.set(sid, id);
  return id;
}

export function clearSidCache(): void {
  sidCache.clear();
}

export async function getSyncState(
  supabase: SupabaseClient,
  provider: string,
): Promise<SyncState | null> {
  const { data } = await supabase
    .from("sync_state")
    .select("provider, last_sync_at, last_transaction_date")
    .eq("provider", provider)
    .maybeSingle();

  return data as SyncState | null;
}

export async function upsertSyncState(
  supabase: SupabaseClient,
  provider: string,
  lastTransactionDate: string,
): Promise<void> {
  const now = new Date().toISOString();

  const { error } = await supabase
    .from("sync_state")
    .upsert(
      {
        provider,
        last_sync_at: now,
        last_transaction_date: lastTransactionDate,
        updated_at: now,
      },
      { onConflict: "provider" },
    );

  if (error) throw error;
}

export async function getSaleByTransactionId(
  supabase: SupabaseClient,
  transactionId: string,
): Promise<{
  id: string;
  status: string;
  commission_amount: number | null;
  sale_amount: number | null;
  locked_date: string | null;
} | null> {
  const { data } = await supabase
    .from("sales")
    .select("id, status, commission_amount, sale_amount, locked_date")
    .eq("transaction_id", transactionId)
    .limit(1)
    .maybeSingle();

  return data;
}

export async function insertSale(
  supabase: SupabaseClient,
  transaction: Transaction,
  affiliateId: string,
): Promise<boolean> {
  const { error } = await supabase.from("sales").insert({
    transaction_id: transaction.transactionId,
    event_id: transaction.eventId,
    action_id: transaction.actionId,
    publisher_commission_id: transaction.publisherCommissionId,
    affiliate_id: affiliateId,
    affiliate_sid: transaction.affiliateSid,
    sale_amount: transaction.saleAmount,
    commission_amount: transaction.commissionAmount,
    status: transaction.status,
    sale_date: transaction.saleDate,
    advertiser: transaction.advertiser,
    product: transaction.product,
    currency: transaction.currency,
    order_id: transaction.orderId,
    locked_date: transaction.lockedDate,
  });

  if (error) {
    if (error.code === "23505") {
      return false;
    }
    throw error;
  }

  return true;
}

export async function updateSale(
  supabase: SupabaseClient,
  saleId: string,
  transaction: Transaction,
): Promise<boolean> {
  const { data: existing } = await supabase
    .from("sales")
    .select("status, commission_amount, sale_amount, locked_date")
    .eq("id", saleId)
    .single();

  if (!existing) return false;

  const statusChanged = existing.status !== transaction.status;
  const commissionChanged =
    Number(existing.commission_amount) !== transaction.commissionAmount;
  const saleAmountChanged =
    Number(existing.sale_amount) !== transaction.saleAmount;
  const lockedDateChanged =
    existing.locked_date !== transaction.lockedDate;

  if (
    !statusChanged &&
    !commissionChanged &&
    !saleAmountChanged &&
    !lockedDateChanged
  ) {
    return false;
  }

  const { error } = await supabase
    .from("sales")
    .update({
      status: transaction.status,
      commission_amount: transaction.commissionAmount,
      sale_amount: transaction.saleAmount,
      locked_date: transaction.lockedDate,
      event_id: transaction.eventId,
      action_id: transaction.actionId,
      publisher_commission_id: transaction.publisherCommissionId,
      updated_at: new Date().toISOString(),
    })
    .eq("id", saleId);

  if (error) throw error;
  return true;
}

export async function createSyncLog(
  supabase: SupabaseClient,
  log: SyncLogData,
): Promise<string> {
  const { data, error } = await supabase
    .from("sync_logs")
    .insert(log)
    .select("id")
    .single();

  if (error) throw error;
  return data.id;
}

export async function updateSyncLog(
  supabase: SupabaseClient,
  logId: string,
  updates: Partial<SyncLogData>,
): Promise<void> {
  const { error } = await supabase
    .from("sync_logs")
    .update(updates)
    .eq("id", logId);

  if (error) throw error;
}
