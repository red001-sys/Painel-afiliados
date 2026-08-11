-- Correção de segurança: funções de saque executáveis por PUBLIC (incl. anon)
-- Por padrão o Postgres concede EXECUTE a PUBLIC em toda função nova. As
-- funções security definer de saque ficaram, assim, chamáveis por anônimos.
-- get_affiliate_balance vazava o saldo de QUALQUER afiliado passando o id.

-- 1) get_affiliate_balance passa a exigir ownership (ou admin) e perde o
--    execute público.
create or replace function public.get_affiliate_balance(p_affiliate_id uuid)
returns numeric(12,2)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_balance numeric(12,2);
begin
  if not public.is_admin() and not exists (
    select 1 from public.affiliates
    where id = p_affiliate_id and auth_user_id = auth.uid()
  ) then
    raise exception 'Acesso negado';
  end if;

  select
    coalesce((
      select sum(commission_amount) from public.sales
      where affiliate_id = p_affiliate_id and status = 'approved'
    ), 0)
    - coalesce((
      select sum(valor) from public.withdrawal_requests
      where affiliate_id = p_affiliate_id and status in ('pago', 'pendente')
    ), 0)
  into v_balance;

  return v_balance;
end;
$$;

revoke execute on function public.get_affiliate_balance(uuid) from public, anon;
grant execute on function public.get_affiliate_balance(uuid) to authenticated, service_role;

revoke execute on function public.request_withdrawal(numeric) from public, anon;
grant execute on function public.request_withdrawal(numeric) to authenticated, service_role;

revoke execute on function public.confirm_withdrawal_payment(uuid) from public, anon;
grant execute on function public.confirm_withdrawal_payment(uuid) to authenticated, service_role;
