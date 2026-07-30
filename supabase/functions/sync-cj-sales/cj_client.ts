import { CJApiResponse } from "./types.ts";

const CJ_BASE_URL = "https://developers.cj.com/api/v3";
const PAGE_SIZE = 100;

export class CJClient {
  private token: string;
  private websiteId: string;

  constructor(token: string, websiteId: string) {
    this.token = token;
    this.websiteId = websiteId;
  }

  async fetchAllCommissions(
    startDate: string,
    endDate: string,
  ): Promise<CJApiResponse["data"]> {
    const allRecords: CJApiResponse["data"] = [];
    let page = 1;
    let hasMore = true;

    while (hasMore) {
      const response = await this.fetchPage(startDate, endDate, page);

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
    }

    return allRecords;
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

    const response = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${this.token}`,
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(
        `CJ API error ${response.status}: ${body}`,
      );
    }

    return await response.json();
  }
}
