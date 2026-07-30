import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createSyncLog, updateSyncLog } from "./database.ts";

export interface SyncLogger {
  logId: string;
  start(): Promise<void>;
  finish(result: {
    read: number;
    imported: number;
    updated: number;
    duplicates: number;
    unknownSid: number;
    failed: number;
    durationMs: number;
    error?: string;
  }): Promise<void>;
}

export async function createSyncLogger(
  supabase: SupabaseClient,
): Promise<SyncLogger> {
  const logId = await createSyncLog(supabase, {
    started_at: new Date().toISOString(),
    finished_at: null,
    transactions_read: 0,
    transactions_imported: 0,
    transactions_updated: 0,
    transactions_skipped: 0,
    unknown_sid: 0,
    transactions_failed: 0,
    status: "running",
    error_message: null,
  });

  return {
    logId,

    async start(): Promise<void> {
      await updateSyncLog(supabase, logId, {
        started_at: new Date().toISOString(),
      });
    },

    async finish(result): Promise<void> {
      let status = "success";
      if (result.error) {
        status = "error";
      } else if (result.failed > 0 || result.unknownSid > 0) {
        status = "partial";
      }

      await updateSyncLog(supabase, logId, {
        finished_at: new Date().toISOString(),
        transactions_read: result.read,
        transactions_imported: result.imported,
        transactions_updated: result.updated,
        transactions_skipped: result.duplicates,
        unknown_sid: result.unknownSid,
        transactions_failed: result.failed,
        duration_ms: result.durationMs,
        status,
        error_message: result.error ?? null,
      });
    },
  };
}
