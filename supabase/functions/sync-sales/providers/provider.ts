import { Transaction } from "../types.ts";

export interface AffiliateProvider {
  readonly name: string;

  fetchTransactions(
    startDate: string,
    endDate: string,
  ): Promise<Transaction[]>;
}
