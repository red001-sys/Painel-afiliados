-- O sync em lote usa o upsert ON CONFLICT do PostgREST, que exige uma
-- constraint única de verdade (não um índice único parcial). Colunas com NULL
-- (produtos manuais) continuam podendo repetir — o Postgres permite múltiplos
-- NULLs em unique constraint.

drop index if exists idx_products_cj_product_unique;

alter table public.products
  add constraint products_cj_product_id_key unique (cj_product_id);

comment on constraint products_cj_product_id_key on public.products is 'Garante uma entrada por produto da CJ e habilita upsert ON CONFLICT (cj_product_id).';
