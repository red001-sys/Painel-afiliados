export interface CJConfig {
  token: string;
  websiteId: string;
}

export function loadCJConfig(): CJConfig | { error: string } {
  const token = Deno.env.get("CJ_PERSONAL_ACCESS_TOKEN");
  const websiteId = Deno.env.get("CJ_WEBSITE_ID");

  if (!token) {
    return { error: "CJ_PERSONAL_ACCESS_TOKEN secret not configured." };
  }

  if (!websiteId) {
    return { error: "CJ_WEBSITE_ID secret not configured." };
  }

  return { token, websiteId };
}
