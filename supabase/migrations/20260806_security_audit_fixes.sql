-- Auditoria de segurança — 2 correções:
--
-- 1) A migration "security_fixes.sql" (mesma data, mas ordenada depois de
--    "fix_rls_recursion.sql" por ordem alfabética) reintroduziu sem querer
--    a recursão nas policies admin de "profiles", usando de novo
--    "EXISTS (SELECT 1 FROM profiles WHERE ...)" em vez de is_admin().
--    Isso causa erro de "infinite recursion detected in policy" sempre
--    que essas policies são avaliadas.
--
-- 2) Toda função SECURITY DEFINER no Postgres recebe EXECUTE liberado pra
--    PUBLIC (incluindo o papel "anon", ou seja, qualquer pessoa sem login)
--    por padrão, a menos que seja revogado explicitamente. Isso já causou
--    um vazamento real (get_affiliate_balance, corrigido em migration
--    anterior). Aqui fechamos essa mesma brecha em TODAS as funções do
--    projeto, mesmo as que hoje "por acaso" são seguras por checarem
--    auth.uid() internamente — não dá pra depender disso se algum dia
--    alguém editar a função e esquecer desse detalhe.

-- --------------------------------------------
-- 1) Corrige profiles de vez, sem chance de outra
--    migration futura desfazer por ordem alfabética
-- --------------------------------------------
drop policy if exists "profiles_admin_select" on profiles;
drop policy if exists "profiles_admin_insert" on profiles;
drop policy if exists "profiles_admin_update" on profiles;
drop policy if exists "profiles_admin_delete" on profiles;
drop policy if exists "profiles_admin_all" on profiles;

create policy "profiles_admin_select"
  on profiles for select
  using (public.is_admin());

create policy "profiles_admin_insert"
  on profiles for insert
  with check (public.is_admin());

create policy "profiles_admin_update"
  on profiles for update
  using (public.is_admin())
  with check (public.is_admin());

-- Admin só apaga perfis de vendedor, nunca outro admin
create policy "profiles_admin_delete"
  on profiles for delete
  using (public.is_admin() and role = 'affiliate');

-- --------------------------------------------
-- 2) Revoga EXECUTE de anon/public em todas as
--    funções SECURITY DEFINER do projeto
-- --------------------------------------------
-- Cada revoke/grant é condicional (só roda se a função existir de
-- verdade no banco) porque nem tudo que está documentado/no schema.sql
-- necessariamente foi criado no banco remoto — schema.sql serve como
-- referência histórica, não como fonte da verdade 100% atualizada.
do $$
declare
  fn record;
  fns text[][] := array[
    ['is_admin', ''],
    ['link_affiliate_to_auth', 'text'],
    ['check_affiliate_for_first_access', 'text'],
    ['ensure_affiliate_exists', ''],
    ['award_affiliate_star', 'uuid'],
    ['get_affiliate_balance', 'uuid'],
    ['request_withdrawal', 'numeric'],
    ['confirm_withdrawal_payment', 'uuid']
  ];
  i int;
  fn_name text;
  fn_args text;
  fn_signature text;
begin
  for i in 1..array_length(fns, 1) loop
    fn_name := fns[i][1];
    fn_args := fns[i][2];
    fn_signature := fn_name || '(' || fn_args || ')';

    if exists (
      select 1 from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where p.proname = fn_name and n.nspname = 'public'
    ) then
      execute format('revoke execute on function public.%s from public, anon', fn_signature);
      execute format('grant execute on function public.%s to authenticated, service_role', fn_signature);
      raise notice 'Revoked/granted: %', fn_signature;
    else
      raise notice 'Skipped (does not exist): %', fn_signature;
    end if;
  end loop;
end $$;
