-- Campos pra rastrear produtos importados automaticamente da Product
-- Search API da CJ, mantendo a tabela compatível com produtos cadastrados
-- manualmente (cj_advertiser_id/cj_product_id ficam null pra esses).

alter table public.products
  add column if not exists cj_advertiser_id text,
  add column if not exists cj_product_id text,
  add column if not exists cj_last_synced_at timestamptz;

-- Evita duplicar o mesmo produto da CJ em re-sincronizações
create unique index if not exists idx_products_cj_product_unique
  on public.products (cj_product_id)
  where cj_product_id is not null;

comment on column public.products.cj_advertiser_id is 'ID do advertiser na CJ (ex: EcoFlow) — null se o produto foi cadastrado manualmente.';
comment on column public.products.cj_product_id is 'ID único do produto retornado pela Product Search API — usado pra evitar duplicar em re-sync.';
comment on column public.products.cj_last_synced_at is 'Última vez que este produto foi atualizado pela sync-products.';

-- Tabela simples de configuração: quais palavras-chave buscar
create table if not exists public.product_sync_keywords (
  id uuid primary key default gen_random_uuid(),
  keyword text not null unique,
  advertiser_id text not null,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.product_sync_keywords is 'Palavras-chave que a sync-products usa pra buscar produtos na Product Search API da CJ (a API exige keyword, não existe "listar tudo").';

alter table public.product_sync_keywords enable row level security;

drop policy if exists "product_sync_keywords_admin_all" on public.product_sync_keywords;
create policy "product_sync_keywords_admin_all"
  on public.product_sync_keywords for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());
