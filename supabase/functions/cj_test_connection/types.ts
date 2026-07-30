export interface CJApiResponse {
  metadata: {
    totalResults: number;
    pageNumber: number;
    pageSize: number;
  };
  data: CJCommissionRecord[];
}

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

export interface ConnectionTestResult {
  success: boolean;
  apiReachable: boolean;
  recordsFound: number;
  sampleTransaction: {
    transactionId: string;
    sid: string;
    advertiser: string;
    saleAmount: string;
    commissionAmount: string;
  } | null;
}

export interface ConnectionTestError {
  success: false;
  error: string;
  statusCode?: number;
}
