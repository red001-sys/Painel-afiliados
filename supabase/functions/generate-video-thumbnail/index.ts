import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Gera um frame real do vídeo e o salva como capa/thumbnail no bucket
// "videos" (`thumb_<video_id>.jpg`), gravando o resultado em
// `videos.thumbnail_url`. Idempotente: se a capa já existir, devolve a URL
// existente sem reprocessar o vídeo.
//
// Chamada sob demanda pelo app quando um vídeo não tem `thumbnail_url`.
// Aceita `{ "video_id": "<uuid>" }` no corpo.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const videoId = body.video_id;
    if (!videoId) {
      return json({ error: "video_id is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const { data: video, error: fetchError } = await supabase
      .from("videos")
      .select("id, video_url, thumbnail_url")
      .eq("id", videoId)
      .maybeSingle();

    if (fetchError || !video) {
      return json({ error: "Video not found" }, 404);
    }

    if (video.thumbnail_url) {
      return json({ thumbnail_url: video.thumbnail_url });
    }

    // Só conseguimos extrair frame de vídeos hospedados no Storage do
    // Supabase. Vídeos de links externos (Drive, YouTube etc.) precisam de
    // capa enviada manualmente pelo admin.
    const storageMarker = "/storage/v1/object/public/videos/";
    if (!video.video_url.includes(storageMarker)) {
      return json({ thumbnail_url: null, skipped: true, reason: "external_url" });
    }

    const cleanUrl = video.video_url.split("?")[0];
    const videoResp = await fetch(cleanUrl);
    if (!videoResp.ok) {
      return json({ error: "Could not download video" }, 502);
    }
    const videoBytes = new Uint8Array(await videoResp.arrayBuffer());

    const ffmpeg = await loadFfmpeg();
    ffmpeg.FS.writeFile("input.mp4", videoBytes);
    // Warm-up: a PRIMEIRA invocação do core UMD com encode jpeg estoura a
    // memória WASM ("memory access out of bounds") para certos bitstreams.
    // Um decode trivial primeiro estabiliza a instância (verificado: sem o
    // warm-up o comando exato falha; com ele, funciona).
    ffmpeg.exec("-i", "input.mp4", "-frames:v", "1", "-f", "rawvideo", "warm.raw");
    try {
      ffmpeg.FS.unlink("warm.raw");
    } catch {
      // ignora: arquivo pode não ter sido criado
    }
    ffmpeg.exec(
      "-i", "input.mp4",
      "-frames:v", "1",
      "-vf", "scale=480:-2",
      "-q:v", "5",
      "thumb.jpg",
    );
    const thumbBytes = new Uint8Array(ffmpeg.FS.readFile("thumb.jpg"));

    const thumbPath = `thumb_${videoId}.jpg`;
    const { error: uploadError } = await supabase.storage
      .from("videos")
      .upload(thumbPath, thumbBytes, {
        contentType: "image/jpeg",
        upsert: true,
      });

    if (uploadError) {
      return json({ error: `Upload failed: ${uploadError.message}` }, 500);
    }

    const { data: publicUrl } = supabase.storage
      .from("videos")
      .getPublicUrl(thumbPath);
    const thumbnailUrl = publicUrl.publicUrl;

    await supabase
      .from("videos")
      .update({ thumbnail_url: thumbnailUrl })
      .eq("id", videoId);

    return json({ thumbnail_url: thumbnailUrl });
  } catch (error) {
    console.error(
      `generate-video-thumbnail error: ${
        error instanceof Error ? error.message : error
      }`,
    );
    return json(
      { error: error instanceof Error ? error.message : "Unexpected error" },
      500,
    );
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Carrega o core do ffmpeg.wasm direto no isolate (sem Web Worker — o
// runtime de Edge Functions não expõe `Worker`). O build UMD não tem
// import/export, então é avaliado com `eval` com os globals de
// Node/browser sombreados, forçando o Emscripten a não usar o branch Node
// (o runtime injeta um `process` falso que quebraria o core). O .wasm é
// fornecido via `wasmBinary` para não depender de fetch condicional.
async function loadFfmpeg(): Promise<any> {
  const baseUrl = "https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.6/dist/umd";
  const [jsResp, wasmResp] = await Promise.all([
    fetch(`${baseUrl}/ffmpeg-core.js`),
    fetch(`${baseUrl}/ffmpeg-core.wasm`),
  ]);
  if (!jsResp.ok || !wasmResp.ok) {
    throw new Error(`Failed to fetch ffmpeg core (js=${jsResp.status} wasm=${wasmResp.status})`);
  }

  const jsSrc = await jsResp.text();
  const wasmBinary = new Uint8Array(await wasmResp.arrayBuffer());

  const factory = (() => {
    // Sombra os globals para o Emscripten não cair no branch de Node nem de
    // browser dentro do eval (que roda no escopo léxico atual).
    const process = undefined;
    const window = undefined;
    const self = undefined;
    const importScripts = undefined;
    const navigator = undefined;

    // Captura a factory em globalThis (var dentro de eval em strict mode
    // não vaza para fora).
    const patched = jsSrc.replace(
      "var createFFmpegCore",
      "globalThis.__createFFmpegCore",
    );
    // eslint-disable-next-line no-eval
    eval(patched);

    return (globalThis as any).__createFFmpegCore;
  })();

  if (typeof factory !== "function") {
    throw new Error("ffmpeg core factory not found after eval");
  }

  const core = await factory({
    wasmBinary,
    locateFile: () => "ffmpeg-core.wasm",
  });
  return core;
}
