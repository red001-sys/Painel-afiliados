import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { MappedSale, SyncLogEntry } from "./types.ts";

export async function findAffiliateIdBySid(
  supabase: SupabaseClient,
  sid: string,
): Promise<string | null> {
  const { data } = await supabase
    .from("affiliates")
    .select("id")
    .eq("sid", sid)
    .limit(1)
    .maybeSingle();

  return data?.id ?? null;
}

export async function transactionExists(
  supabase: SupabaseClient,
  transactionId: string,
): Promise<boolean> {
  const { data } = await supabase
    .from("sales")
    .select("id")
    .eq("transaction_id", transactionId)
    .limit(1)
    .maybeSingle();

  return data !== null;
}

export async function insertSales(
  supabase: SupabaseClient,
  sales: MappedSale[],
): Promise<number> {
  if (sales.length === 0) return 0;

  const { data, error } = await supabase
    .from("sales")
    .insert(sales)
    .select("id");

  if (error) throw error;
  return data?.length ?? 0;
}

export async function createSyncLog(
  supabase: SupabaseClient,
  log: SyncLogEntry,
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
  updates: Partial<SyncLogEntry>,
): Promise<void> {
  const { error } = await supabase
    .from("sync_logs")
    .update(updates)
    .eq("id", logId);

  if (error) throw error;
}
