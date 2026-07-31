/**
 * Configuration for the sync-ecoflow-products Edge Function.
 *
 * Required Supabase secrets (mesmos já usados por sync-sales):
 *   - SUPABASE_URL
 *   - SUPABASE_SERVICE_ROLE_KEY
 *
 * Required CJ secrets (mesmos já usados por sync-sales):
 *   - CJ_PERSONAL_ACCESS_TOKEN
 *   - CJ_WEBSITE_ID  (CID, não PID — mesma observação do sync-sales)
 */

export interface SupabaseConfig {
  url: string;
  serviceRoleKey: string;
}

export interface CJConfig {
  token: string;
  companyId: string;
}

export interface AppConfig {
  supabase: SupabaseConfig;
  cj: CJConfig | null;
}

export function loadConfig(): AppConfig {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseKey) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.",
    );
  }

  const cjToken = Deno.env.get("CJ_PERSONAL_ACCESS_TOKEN")?.trim();
  const cjCompanyId = Deno.env.get("CJ_WEBSITE_ID")?.trim();

  const cj: CJConfig | null =
    cjToken && cjCompanyId ? { token: cjToken, companyId: cjCompanyId } : null;

  return {
    supabase: { url: supabaseUrl, serviceRoleKey: supabaseKey },
    cj,
  };
}
