import { CJApiResponse } from "./types.ts";

const CJ_BASE_URL = "https://developers.cj.com/api/v3";
const REQUEST_TIMEOUT_MS = 15000;

interface CJClientError {
  message: string;
  statusCode?: number;
}

export class CJClient {
  private token: string;
  private websiteId: string;

  constructor(token: string, websiteId: string) {
    this.token = token;
    this.websiteId = websiteId;
  }

  async testConnection(): Promise<{
    data: CJApiResponse;
  }> {
    const params = new URLSearchParams({
      "website-id": this.websiteId,
      "date-type": "transaction",
      "page-number": "1",
      "page-size": "1",
    });

    const url = `${CJ_BASE_URL}/commissions?${params.toString()}`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

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

      if (!this.isValidResponse(body)) {
        throw new Error("CJ API returned an unexpected response format.");
      }

      return { data: body as CJApiResponse };
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof DOMException && error.name === "AbortError") {
        throw new Error("Request timed out after 15 seconds.");
      }

      if (error instanceof TypeError) {
        throw new Error("Connection refused. Check network or CJ API URL.");
      }

      throw error;
    }
  }

  private async buildError(response: Response): Promise<CJClientError> {
    const body = await response.text().catch(() => "");

    switch (response.status) {
      case 401:
        return {
          message: "Authentication failed. Verify CJ_PERSONAL_ACCESS_TOKEN.",
          statusCode: 401,
        };
      case 403:
        return {
          message: "Access denied. Verify CJ_WEBSITE_ID and token permissions.",
          statusCode: 403,
        };
      case 404:
        return {
          message: "API endpoint not found. Check CJ API base URL.",
          statusCode: 404,
        };
      case 429:
        return {
          message: "Rate limited. Try again later.",
          statusCode: 429,
        };
      default:
        return {
          message: `CJ API error ${response.status}`,
          statusCode: response.status,
        };
    }
  }

  private isValidResponse(body: unknown): boolean {
    if (!body || typeof body !== "object") return false;
    const obj = body as Record<string, unknown>;
    if (!obj.metadata || typeof obj.metadata !== "object") return false;
    if (!Array.isArray(obj.data)) return false;
    return true;
  }
}
