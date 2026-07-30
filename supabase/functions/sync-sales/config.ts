/**
 * Configuration for the sync-sales Edge Function.
 *
 * Required Supabase secrets:
 *   - SUPABASE_URL
 *   - SUPABASE_SERVICE_ROLE_KEY
 *   - SUPABASE_ANON_KEY (for auth verification)
 *
 * Required CJ secrets (for sync execution):
 *   - CJ_PERSONAL_ACCESS_TOKEN
 *   - CJ_WEBSITE_ID
 *
 * Supported query parameters (for manual/cron overrides):
 *   - start_date: Override start date (YYYY-MM-DD)
 *   - end_date: Override end date (YYYY-MM-DD)
 *
 * Cron example (Supabase cron):
 *   supabase functions invoke sync-sales \
 *     --header "Authorization: Bearer <service_role_key>" \
 *     --query "start_date=2025-01-01&end_date=2025-01-31"
 */

export interface SupabaseConfig {
  url: string;
  serviceRoleKey: string;
}

export interface CJConfig {
  token: string;
  websiteId: string;
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

  const cjToken = Deno.env.get("CJ_PERSONAL_ACCESS_TOKEN");
  const cjWebsiteId = Deno.env.get("CJ_WEBSITE_ID");

  const cj: CJConfig | null =
    cjToken && cjWebsiteId
      ? { token: cjToken, websiteId: cjWebsiteId }
      : null;

  return {
    supabase: { url: supabaseUrl, serviceRoleKey: supabaseKey },
    cj,
  };
}
