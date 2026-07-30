import { Transaction } from "../types.ts";
import { CJConfig } from "../config.ts";
import { AffiliateProvider } from "./provider.ts";

const CJ_BASE_URL = "https://developers.cj.com/api/v3";
const PAGE_SIZE = 100;
const REQUEST_TIMEOUT_MS = 15000;

interface CJCommissionRecord {
  transactionId: string;
  eventId: string | null;
  actionId: string | null;
  publisherCommissionId: string | null;
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

interface CJApiResponse {
  metadata: {
    totalResults: number;
    pageNumber: number;
    pageSize: number;
  };
  data: CJCommissionRecord[];
}

export class CJProvider implements AffiliateProvider {
  readonly name = "cj";
  private token: string;
  private websiteId: string;

  constructor(config: CJConfig) {
    this.token = config.token;
    this.websiteId = config.websiteId;
  }

  async fetchTransactions(
    startDate: string,
    endDate: string,
  ): Promise<Transaction[]> {
    const allRecords: CJCommissionRecord[] = [];
    let page = 1;
    let hasMore = true;
    let retries = 0;
    const maxRetries = 2;

    while (hasMore) {
      try {
        const response = await this.fetchPage(startDate, endDate, page);
        retries = 0;

        if (!response.data || response.data.length === 0) {
          hasMore = false;
          break;
        }

        allRecords.push(...response.data);

        const totalPages = Math.ceil(
          response.metadata.totalResults / PAGE_SIZE,
        );
        hasMore = page < totalPages;
        page++;
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        if (msg.includes("rate limited") && retries < maxRetries) {
          retries++;
          const delay = retries * 2000;
          console.warn(`Rate limited, retrying in ${delay}ms (attempt ${retries}/${maxRetries})`);
          await new Promise((r) => setTimeout(r, delay));
          continue;
        }
        throw error;
      }
    }

    return allRecords
      .map(mapToTransaction)
      .filter((tx): tx is Transaction => tx !== null);
  }

  private async fetchPage(
    startDate: string,
    endDate: string,
    page: number,
  ): Promise<CJApiResponse> {
    const params = new URLSearchParams({
      "website-id": this.websiteId,
      "date-type": "transaction",
      "start-date": startDate,
      "end-date": endDate,
      "page-number": page.toString(),
      "page-size": PAGE_SIZE.toString(),
    });

    const url = `${CJ_BASE_URL}/commissions?${params.toString()}`;

    const controller = new AbortController();
    const timeoutId = setTimeout(
      () => controller.abort(),
      REQUEST_TIMEOUT_MS,
    );

    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          Authorization: `Bearer ${this.token}`,
          "Content-Type": "application/json",
        },
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw await this.buildError(response);
      }

      const body = await response.json();

      if (!isValidCJResponse(body)) {
        throw new Error(
          "CJ API returned an unexpected response format.",
        );
      }

      return body as CJApiResponse;
    } catch (error) {
      clearTimeout(timeoutId);

      if (
        error instanceof DOMException &&
        error.name === "AbortError"
      ) {
        throw new Error(
          "CJ API request timed out after 15 seconds.",
        );
      }

      if (error instanceof TypeError) {
        throw new Error(
          "CJ API connection refused. Check network or URL.",
        );
      }

      const errObj = error as { statusCode?: number; message?: string };
      if (errObj.statusCode === 429) {
        throw new Error("CJ API rate limited. Try again later.");
      }

      throw error;
    }
  }

  private async buildError(response: Response): Promise<Error> {
    const body = await response.text().catch(() => "");

    switch (response.status) {
      case 401:
        return new Error(
          "CJ authentication failed. Verify CJ_PERSONAL_ACCESS_TOKEN.",
        );
      case 403:
        return new Error(
          "CJ access denied. Verify CJ_WEBSITE_ID and token permissions.",
        );
      case 404:
        return new Error(
          "CJ API endpoint not found. Check CJ API base URL.",
        );
      case 429:
        return new Error("CJ API rate limited. Try again later.");
      default:
        return new Error(
          `CJ API error ${response.status}`,
        );
    }
  }
}

function mapToTransaction(
  record: CJCommissionRecord,
): Transaction | null {
  const transactionId = String(record.transactionId ?? "").trim();
  const publisherId = String(record.publisherId ?? "").trim();

  if (!transactionId || !publisherId) {
    return null;
  }

  return {
    transactionId,
    eventId: record.eventId ? String(record.eventId) : null,
    actionId: record.actionId ? String(record.actionId) : null,
    publisherCommissionId: record.publisherCommissionId
      ? String(record.publisherCommissionId)
      : null,
    affiliateSid: publisherId,
    saleAmount: Number(record.saleAmount) || 0,
    commissionAmount: Number(record.commissionAmount) || 0,
    status: normalizeStatus(record.status),
    saleDate: toISOTimestamp(record.transactionDate),
    advertiser: String(record.advertiserName || ""),
    product: String(record.advertiserName || ""),
    currency: String(record.currency || "USD"),
    orderId: String(record.orderId || ""),
    lockedDate: record.lockDate
      ? toISOTimestamp(record.lockDate)
      : null,
  };
}

function normalizeStatus(status: string): string {
  const s = (status || "").toLowerCase().trim();
  if (s === "new" || s === "extended") return "pending";
  if (s === "locked") return "locked";
  if (s === "approved") return "approved";
  if (s === "closed" || s === "rejected" || s === "cancelled")
    return "rejected";
  return s || "pending";
}

function toISOTimestamp(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) {
      console.warn(`Invalid date value: ${dateStr}, using epoch fallback`);
      return "1970-01-01T00:00:00.000Z";
    }
    return d.toISOString();
  } catch {
    console.warn(`Failed to parse date: ${dateStr}, using epoch fallback`);
    return "1970-01-01T00:00:00.000Z";
  }
}

function isValidCJResponse(body: unknown): boolean {
  if (!body || typeof body !== "object") return false;
  const obj = body as Record<string, unknown>;
  if (!obj.metadata || typeof obj.metadata !== "object") return false;
  if (!Array.isArray(obj.data)) return false;
  return true;
}
