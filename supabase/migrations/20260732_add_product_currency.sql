-- Campos extras que a Product Search API da CJ devolve e que o sync de
-- catálogo precisa persistir além dos campos básicos já existentes.

alter table public.products
  add column if not exists currency text,
  add column if not exists brand text,
  add column if not exists sale_price numeric;

comment on column public.products.currency is 'Moeda do preço vindo da CJ (ex: USD). Sync filtra só USD.';
comment on column public.products.brand is 'Marca do produto vindo da CJ (ex: EcoFlow).';
comment on column public.products.sale_price is 'Preço promocional (salePrice) quando a CJ informa; null caso contrário.';
