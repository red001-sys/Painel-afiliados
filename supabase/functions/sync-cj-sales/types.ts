export interface CJCommissionRecord {
  transactionId: string;
  publisherId: string;
  advertiserId: string;
  advertiserName: string;
  saleAmount: number;
  commissionAmount: number;
  currency: string;
  status: string;
  orderId: string;
  transactionDate: string;
  lockDate: string | null;
}

export interface CJApiResponse {
  metadata: {
    totalResults: number;
    pageNumber: number;
    pageSize: number;
  };
  data: CJCommissionRecord[];
}

export interface MappedSale {
  transaction_id: string;
  affiliate_id: string | null;
  affiliate_sid: string;
  sale_amount: number;
  commission_amount: number;
  status: string;
  sale_date: string;
  advertiser: string;
  product: string;
  currency: string;
  order_id: string;
  locked_date: string | null;
}

export interface SyncLogEntry {
  started_at: string;
  finished_at: string | null;
  transactions_read: number;
  transactions_imported: number;
  transactions_skipped: number;
  unknown_sid: number;
  status: string;
  error_message: string | null;
}

export interface SyncResult {
  transactionsRead: number;
  transactionsImported: number;
  transactionsSkipped: number;
  unknownSid: number;
}
