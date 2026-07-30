export interface Transaction {
  transactionId: string;
  eventId: string | null;
  actionId: string | null;
  publisherCommissionId: string | null;
  affiliateSid: string;
  saleAmount: number;
  commissionAmount: number;
  status: string;
  saleDate: string;
  advertiser: string;
  product: string;
  currency: string;
  orderId: string;
  lockedDate: string | null;
}

export interface SyncResult {
  success: boolean;
  read: number;
  imported: number;
  updated: number;
  duplicates: number;
  unknownSid: number;
  failed: number;
  durationMs: number;
  error?: string;
}

export interface SyncLogData {
  started_at: string;
  finished_at: string | null;
  transactions_read: number;
  transactions_imported: number;
  transactions_updated: number;
  transactions_skipped: number;
  unknown_sid: number;
  transactions_failed: number;
  duration_ms: number;
  status: string;
  error_message: string | null;
}

export interface SyncState {
  provider: string;
  last_sync_at: string | null;
  last_transaction_date: string | null;
}
