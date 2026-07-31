export interface EcoFlowProduct {
  cjProductId: string;
  cjAdvertiserId: string;
  nome: string;
  descricao: string | null;
  preco: number | null;
  precoPromocional: number | null;
  moeda: string;
  marca: string | null;
  imagemUrl: string | null;
  cjUrl: string | null;
}

export interface EcoFlowSyncResult {
  success: boolean;
  advertiserId: string;
  pagesFetched: number;
  totalAvailable: number;
  found: number;
  imported: number;
  updated: number;
  skippedNonUsd: number;
  failed: number;
  usedFallbackKeyword: boolean;
  durationMs: number;
  error?: string;
  lastBatchError?: string;
}
