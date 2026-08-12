import { Transaction } from "../types.ts";
import { CJConfig } from "../config.ts";
import { AffiliateProvider } from "./provider.ts";

// CJ's Commission Detail API is GraphQL, served from this dedicated host.
// NOTE: developers.cj.com is only the docs/marketing site (it returns HTML,
// not JSON) — that mismatch was the root cause of the
// "Unexpected token '<', '<!doctype'... is not valid JSON" error. DO NOT
// change this back to developers.cj.com/api/v3 — that endpoint doesn't
// serve JSON and this exact bug will come back.
const CJ_QUERY_URL = "https://commissions.api.cj.com/query";
const REQUEST_TIMEOUT_MS = 15000;
const MAX_PAGES = 50; // safety cap on cursor pagination per sync run

interface CJCommissionRecord {
  commissionId: string;
  actionTrackerId: string | null;
  actionStatus: string;
  advertiserId: string;
  advertiserName: string;
  saleAmountUsd: string | null;
  pubCommissionAmountUsd: string | null;
  orderId: string | null;
  eventDate: string;
  lockingDate: string | null;
  publisherId: string;
  sid?: string | null;
  shopperId?: string | null;
}

interface CJGraphQLResponse {
  data?: {
    publisherCommissions?: {
      count: number;
      maxCommissionId: string | null;
      payloadComplete: boolean;
      records: CJCommissionRecord[];
    };
  };
  errors?: { message: string }[];
}

export class CJProvider implements AffiliateProvider {
  readonly name = "cj";
  private token: string;
  private publisherId: string;

  constructor(config: CJConfig) {
    this.token = config.token.trim();
    this.publisherId = config.websiteId.trim();
  }

  async fetchTransactions(
    startDate: string,
    endDate: string,
  ): Promise<Transaction[]> {
    const allTransactions: Transaction[] = [];

    for (const [chunkStart, chunkEnd] of splitDateRange(startDate, endDate, 31)) {
      const chunkTransactions = await this.fetchTransactionsForRange(
        chunkStart,
        chunkEnd,
      );
      allTransactions.push(...chunkTransactions);
    }

    return allTransactions;
  }

  private async fetchTransactionsForRange(
    startDate: string,
    endDate: string,
  ): Promise<Transaction[]> {
    const allRecords: CJCommissionRecord[] = [];
    let sinceCommissionId: string | null = null;
    let payloadComplete = false;
    let page = 0;
    let retries = 0;
    const maxRetries = 2;

    while (!payloadComplete && page < MAX_PAGES) {
      try {
        const result = await this.fetchPage(
          startDate,
          endDate,
          sinceCommissionId,
        );
        retries = 0;

        allRecords.push(...result.records);
        payloadComplete = result.payloadComplete;
        sinceCommissionId = result.maxCommissionId;
        page++;

        if (!sinceCommissionId) break;
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        if (msg.includes("rate limited") && retries < maxRetries) {
          retries++;
          const delay = retries * 2000;
          console.warn(
            `Rate limited, retrying in ${delay}ms (attempt ${retries}/${maxRetries})`,
          );
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
    sinceCommissionId: string | null,
  ): Promise<{
    records: CJCommissionRecord[];
    payloadComplete: boolean;
    maxCommissionId: string | null;
  }> {
    const sincePostingDate = toCjInstant(startDate);
    const beforePostingDate = toCjInstant(endDate);
    const cursorArg = sinceCommissionId
      ? `, sinceCommissionId: "${sinceCommissionId}"`
      : "";

    const query = `{ publisherCommissions(forPublishers: ["${this.publisherId}"], sincePostingDate: "${sincePostingDate}", beforePostingDate: "${beforePostingDate}"${cursorArg}) { count maxCommissionId payloadComplete records { commissionId actionTrackerId actionStatus advertiserId advertiserName saleAmountUsd pubCommissionAmountUsd orderId eventDate lockingDate publisherId shopperId } } }`;

    const controller = new AbortController();
    const timeoutId = setTimeout(
      () => controller.abort(),
      REQUEST_TIMEOUT_MS,
    );

    try {
      const response = await fetch(CJ_QUERY_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ query, variables: {} }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw await this.buildError(response);
      }

      const contentType = response.headers.get("content-type") ?? "";
      if (!contentType.includes("application/json")) {
        const preview = (await response.text()).slice(0, 200);
        throw new Error(
          `CJ API returned non-JSON content-type "${contentType}". ` +
            `First 200 chars: ${preview}`,
        );
      }

      const body = (await response.json()) as CJGraphQLResponse;

      if (body.errors && body.errors.length > 0) {
        throw new Error(
          `CJ GraphQL error (sent forPublishers=["${this.publisherId}"]): ` +
            body.errors.map((e) => e.message).join("; "),
        );
      }

      const result = body.data?.publisherCommissions;
      if (!result) {
        throw new Error("CJ API returned an unexpected response format.");
      }

      return {
        records: result.records ?? [],
        payloadComplete: result.payloadComplete,
        maxCommissionId: result.maxCommissionId,
      };
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof DOMException && error.name === "AbortError") {
        throw new Error("CJ API request timed out after 15 seconds.");
      }

      if (error instanceof TypeError) {
        throw new Error("CJ API connection refused. Check network or URL.");
      }

      throw error;
    }
  }

  private async buildError(response: Response): Promise<Error> {
    const bodyText = await response.text().catch(() => "");
    const bodyPreview = bodyText.slice(0, 500);

    switch (response.status) {
      case 401:
        return new Error(
          `CJ authentication failed. Verify CJ_PERSONAL_ACCESS_TOKEN. Body: ${bodyPreview}`,
        );
      case 403:
        return new Error(
          `CJ access denied. Verify CJ_WEBSITE_ID (CID) and token permissions. Body: ${bodyPreview}`,
        );
      case 404:
        return new Error(`CJ API endpoint not found. Body: ${bodyPreview}`);
      case 429:
        return new Error(`CJ API rate limited. Try again later. Body: ${bodyPreview}`);
      default:
        return new Error(`CJ API error ${response.status}. Body: ${bodyPreview}`);
    }
  }
}

function splitDateRange(
  startDate: string,
  endDate: string,
  maxDays: number,
): [string, string][] {
  const chunks: [string, string][] = [];
  let cursor = new Date(`${startDate}T00:00:00Z`);
  const end = new Date(`${endDate}T00:00:00Z`);

  while (cursor <= end) {
    const chunkEnd = new Date(cursor);
    chunkEnd.setUTCDate(chunkEnd.getUTCDate() + maxDays - 1);
    if (chunkEnd > end) chunkEnd.setTime(end.getTime());

    chunks.push([
      cursor.toISOString().split("T")[0],
      chunkEnd.toISOString().split("T")[0],
    ]);

    cursor = new Date(chunkEnd);
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return chunks;
}

function toCjInstant(dateStr: string): string {
  if (dateStr.includes("T")) return dateStr;
  return `${dateStr}T00:00:00Z`;
}

function mapToTransaction(
  record: CJCommissionRecord,
): Transaction | null {
  const transactionId = String(record.commissionId ?? "").trim();
  const affiliateSid = String(record.shopperId ?? record.sid ?? "").trim();

  if (!transactionId || !affiliateSid) {
    return null;
  }

  return {
    transactionId,
    eventId: null,
    actionId: record.actionTrackerId ? String(record.actionTrackerId) : null,
    publisherCommissionId: transactionId,
    affiliateSid,
    saleAmount: Number(record.saleAmountUsd) || 0,
    commissionAmount: Number(record.pubCommissionAmountUsd) || 0,
    status: normalizeStatus(record.actionStatus),
    saleDate: toISOTimestamp(record.eventDate),
    advertiser: String(record.advertiserName || ""),
    product: String(record.advertiserName || ""),
    currency: "USD",
    orderId: String(record.orderId || ""),
    lockedDate: record.lockingDate ? toISOTimestamp(record.lockingDate) : null,
  };
}

function normalizeStatus(status: string): string {
  const s = (status || "").toLowerCase().trim();
  if (s === "new" || s === "extended") return "pending";
  if (s === "locked") return "locked";
  if (s === "closed") return "approved";
  if (s === "rejected" || s === "cancelled") return "rejected";
  return s || "pending";
}

function toISOTimestamp(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) {
      return "1970-01-01T00:00:00.000Z";
    }
    return d.toISOString();
  } catch {
    return "1970-01-01T00:00:00.000Z";
  }
}
