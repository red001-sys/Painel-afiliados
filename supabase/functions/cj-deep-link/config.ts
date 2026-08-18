export interface SupabaseConfig {
  url: string;
  serviceRoleKey: string;
  anonKey: string;
}

export interface CJConfig {
  token: string;
  companyId: string;
  pid: string;
}

export interface AppConfig {
  supabase: SupabaseConfig;
  cj: CJConfig | null;
}

export function loadConfig(): AppConfig {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseKey || !anonKey) {
    throw new Error(
      "SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and SUPABASE_ANON_KEY are required.",
    );
  }

  const cjToken = Deno.env.get("CJ_PERSONAL_ACCESS_TOKEN")?.trim();
  const cjCompanyId = Deno.env.get("CJ_WEBSITE_ID")?.trim();
  const cjPid = Deno.env.get("CJ_PID")?.trim();

  const cj: CJConfig | null =
    cjToken && cjCompanyId && cjPid
      ? { token: cjToken, companyId: cjCompanyId, pid: cjPid }
      : null;

  return {
    supabase: { url: supabaseUrl, serviceRoleKey: supabaseKey, anonKey },
    cj,
  };
}
