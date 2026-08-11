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
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated, service_role;

revoke execute on function link_affiliate_to_auth(text) from public, anon;
grant execute on function link_affiliate_to_auth(text) to authenticated, service_role;

revoke execute on function check_affiliate_for_first_access(text) from public, anon;
grant execute on function check_affiliate_for_first_access(text) to authenticated, service_role;

revoke execute on function ensure_affiliate_exists() from public, anon;
grant execute on function ensure_affiliate_exists() to authenticated, service_role;

-- Se a função abaixo existir no seu banco (sistema de ranking/estrelas),
-- destrava. Se não existir ainda, essa linha só vai dar erro "function
-- does not exist" e pode ser removida/ignorada com segurança.
do $$
begin
  if exists (
    select 1 from pg_proc where proname = 'award_affiliate_star'
  ) then
    execute 'revoke execute on function public.award_affiliate_star(uuid) from public, anon';
    execute 'grant execute on function public.award_affiliate_star(uuid) to authenticated, service_role';
  end if;
end $$;
