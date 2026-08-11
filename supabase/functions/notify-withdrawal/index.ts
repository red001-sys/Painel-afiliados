import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Troque pelo provedor de email que preferir (Resend usado aqui por ser
// simples de configurar). Precisa da secret RESEND_API_KEY e de um
// domínio/remetente verificado no Resend.
const RESEND_API_URL = "https://api.resend.com/emails";

interface WebhookPayload {
  record: {
    id: string;
    affiliate_id: string;
    valor: number;
    created_at: string;
  };
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: WebhookPayload = await req.json();
    const { affiliate_id, valor, id } = payload.record;

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const adminEmail = Deno.env.get("ADMIN_NOTIFICATION_EMAIL");

    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: affiliate } = await supabase
      .from("affiliates")
      .select("nome, email, sid")
      .eq("id", affiliate_id)
      .maybeSingle();

    const affiliateName =
      affiliate?.nome ?? affiliate?.sid ?? "Vendedor desconhecido";

    if (!resendKey || !adminEmail) {
      console.warn(
        "RESEND_API_KEY ou ADMIN_NOTIFICATION_EMAIL não configurados — pulando envio de email (o alerta no painel admin continua funcionando normalmente).",
      );
      return new Response(
        JSON.stringify({ success: true, emailSkipped: true }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    const emailResponse = await fetch(RESEND_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Nex Vendedores <notificacoes@seudominio.com>",
        to: [adminEmail],
        subject: `Nova solicitação de saque — ${affiliateName}`,
        html: `
          <p><strong>${affiliateName}</strong> solicitou um saque de <strong>$${valor.toFixed(2)}</strong>.</p>
          <p>ID da solicitação: ${id}</p>
          <p>Acesse o painel admin → Saques pra confirmar o pagamento.</p>
        `,
      }),
    });

    if (!emailResponse.ok) {
      const body = await emailResponse.text();
      console.error(`Failed to send email: ${emailResponse.status} ${body}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(
      `notify-withdrawal error: ${
        error instanceof Error ? error.message : error
      }`,
    );
    return new Response(JSON.stringify({ success: false }), { status: 500 });
  }
});
