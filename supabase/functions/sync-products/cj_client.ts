import { EcoFlowProduct } from "./types.ts";
import { CJConfig } from "./config.ts";

// Catálogo oficial da EcoFlow US. A query `products` aceita `partnerIds`,
// então dá pra puxar tudo do advertiser sem depender de keyword.
export const ECOTLOW_ADVERTISER_ID = "5815804";
export const ECOTLOW_ADVERTISER_NAME = "EcoFlow";

// Fallback: a API pode exigir keyword em alguns cenários. Se a primeira
// chamada sem keyword falhar pedindo keywords, usamos "ecoflow" como filtro
// mínimo — o partnerIds já restringe os resultados à EcoFlow.
const FALLBACK_KEYWORD = "ecoflow";
// NOTA: o campo linkCode (deep link de vendedor) foi removido de propósito:
// (1) gera links de forma lenta (~27s para 5 produtos) e
// (2) exige um pid (website ID do publisher) que não temos — retornava
//     "cannot access requested publisherid". O app usa links manuais com SID,
//     então o produto fica com cj_url = null e o admin pode preencher depois.
const CJ_PRODUCTS_URL = "https://ads.api.cj.com/query";
const REQUEST_TIMEOUT_MS = 15000;

interface CJProductRecord {
  id: string;
  title: string;
  description: string | null;
  brand: string | null;
  price: { amount: string; currency: string } | null;
  salePrice: { amount: string; currency: string } | null;
  imageLink: string | null;
  linkCode: { clickUrl: string } | null;
}

interface CJProductsPage {
  totalCount: number;
  resultList: CJProductRecord[];
}

interface CJProductsResponse {
  data?: {
    products?: CJProductsPage;
  };
  errors?: { message: string }[];
}

export class CJEcoFlowProductProvider {
  private token: string;
  private companyId: string;
  private useFallbackKeyword: boolean;

  constructor(config: CJConfig) {
    this.token = config.token;
    this.companyId = config.companyId;
    this.useFallbackKeyword = false;
  }

  get usedFallbackKeyword(): boolean {
    return this.useFallbackKeyword;
  }

  /**
   * Busca uma página do catálogo da EcoFlow com paginação via offset.
   * Tenta sem keyword; se a CJ recusar exigindo keyword, liga o fallback
   * (e usa a keyword nas próximas chamadas).
   */
  async searchProducts(
    offset: number,
    limit: number,
  ): Promise<{ page: CJProductsPage; error?: string }> {
    const query = `{ products(companyId: "${this.companyId}", partnerIds: ["${ECOTLOW_ADVERTISER_ID}"], limit: ${limit}, offset: ${offset}) { totalCount resultList { id title description brand price { amount currency } salePrice { amount currency } imageLink } } }`;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch(CJ_PRODUCTS_URL, {
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
        const bodyPreview = (await response.text().catch(() => "")).slice(0, 500);
        throw new Error(`CJ Products API error ${response.status}. Body: ${bodyPreview}`);
      }

      // A CJ às vezes não manda Content-Type application/json; tenta parsear
      // direto e só reclama se realmente não for JSON.
      let body: CJProductsResponse;
      const raw = await response.text();
      try {
        body = JSON.parse(raw) as CJProductsResponse;
      } catch {
        throw new Error(
          `CJ Products API returned non-JSON body. First 200 chars: ${raw.slice(0, 200)}`,
        );
      }

      if (body.errors && body.errors.length > 0) {
        const message = body.errors.map((e) => e.message).join("; ");

        if (!this.useFallbackKeyword && /keyword/i.test(message)) {
          console.warn(
            `CJ requires keywords; switching to fallback keyword "${FALLBACK_KEYWORD}".`,
          );
          this.useFallbackKeyword = true;
          return this.searchProducts(offset, limit);
        }

        throw new Error(
          `CJ Products GraphQL error (offset=${offset}): ${message}`,
        );
      }

      if (!body.data?.products) {
        throw new Error(
          `CJ Products returned no "products" data (offset=${offset}).`,
        );
      }

      return { page: body.data.products };
    } catch (error) {
      clearTimeout(timeoutId);
      if (error instanceof DOMException && error.name === "AbortError") {
        throw new Error("CJ Products API request timed out after 15 seconds.");
      }
      throw error;
    }
  }
}

export function mapToEcoFlowProduct(
  record: CJProductRecord,
): EcoFlowProduct {
  return {
    cjProductId: record.id,
    cjAdvertiserId: ECOTLOW_ADVERTISER_ID,
    nome: record.title,
    descricao: record.description,
    preco: record.price ? Number(record.price.amount) || null : null,
    precoPromocional: record.salePrice
      ? Number(record.salePrice.amount) || null
      : null,
    moeda: record.price?.currency ?? record.salePrice?.currency ?? "",
    marca: record.brand,
    imagemUrl: record.imageLink,
    cjUrl: record.linkCode?.clickUrl ?? null,
  };
}
