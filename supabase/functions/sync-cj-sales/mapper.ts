import { CJCommissionRecord, MappedSale } from "./types.ts";

export function mapCJRecordToSale(
  record: CJCommissionRecord,
  affiliateId: string | null,
): MappedSale {
  return {
    transaction_id: String(record.transactionId),
    affiliate_id: affiliateId,
    affiliate_sid: String(record.publisherId),
    sale_amount: Number(record.saleAmount) || 0,
    commission_amount: Number(record.commissionAmount) || 0,
    status: normalizeStatus(record.status),
    sale_date: toISOTimestamp(record.transactionDate),
    advertiser: String(record.advertiserName || ""),
    product: String(record.advertiserName || ""),
    currency: String(record.currency || "USD"),
    order_id: String(record.orderId || ""),
    locked_date: record.lockDate
      ? toISOTimestamp(record.lockDate)
      : null,
  };
}

function normalizeStatus(status: string): string {
  const s = (status || "").toLowerCase().trim();
  if (s === "new" || s === "extended") return "pending";
  if (s === "locked") return "locked";
  if (s === "approved") return "approved";
  if (s === "closed" || s === "rejected" || s === "cancelled") return "rejected";
  return s || "pending";
}

function toISOTimestamp(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return new Date().toISOString();
    return d.toISOString();
  } catch {
    return new Date().toISOString();
  }
}
