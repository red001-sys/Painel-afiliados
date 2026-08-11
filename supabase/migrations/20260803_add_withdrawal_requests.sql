-- Sistema de solicitação de saque de comissão

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  affiliate_id uuid not null references public.affiliates(id) on delete cascade,
  valor numeric(12,2) not null check (valor > 0),
  status text not null default 'pendente' check (status in ('pendente', 'pago', 'cancelado')),
  -- Guarda a chave PIX no momento do pedido (auditoria — o vendedor pode
  -- trocar a chave depois, e precisamos saber pra onde foi pago cada saque)
  chave_pix_snapshot text,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  paid_by uuid references auth.users(id),
  observacoes text
);

create index if not exists idx_withdrawal_requests_affiliate on public.withdrawal_requests(affiliate_id);
create index if not exists idx_withdrawal_requests_status on public.withdrawal_requests(status);

comment on table public.withdrawal_requests is 'Solicitações de saque de comissão feitas pelos vendedores';
comment on column public.withdrawal_requests.chave_pix_snapshot is 'Chave PIX do vendedor no momento do pedido, pra auditoria caso ele troque depois';

alter table public.withdrawal_requests enable row level security;

-- Vendedor vê só as próprias solicitações
drop policy if exists "withdrawal_requests_select_own" on public.withdrawal_requests;
create policy "withdrawal_requests_select_own"
  on public.withdrawal_requests for select
  to authenticated
  using (
    affiliate_id in (select id from public.affiliates where auth_user_id = auth.uid())
  );

-- Admin vê e gerencia tudo
drop policy if exists "withdrawal_requests_admin_all" on public.withdrawal_requests;
create policy "withdrawal_requests_admin_all"
  on public.withdrawal_requests for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Cálculo do saldo disponível: comissões aprovadas - saques pagos - saques
-- pendentes (reserva o valor assim que solicitado, pra não deixar pedir
-- saque duplicado antes do admin confirmar o primeiro)
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
  -- Só o próprio vendedor (ou admin) pode consultar o saldo
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

-- Revoga EXECUTE de public/anon (as default privileges do Supabase concedem
-- diretamente a anon/authenticated/service_role, então é preciso revogar
-- explicitamente) e libera apenas para authenticated/service_role.
revoke execute on function public.get_affiliate_balance(uuid) from public, anon;
grant execute on function public.get_affiliate_balance(uuid) to authenticated, service_role;

-- Cria a solicitação validando TODAS as regras no servidor (nunca confiar
-- só na validação do app — o app só existe pra dar uma boa UX, a regra de
-- verdade mora aqui).
create or replace function public.request_withdrawal(p_valor numeric)
returns public.withdrawal_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_affiliate_id uuid;
  v_balance numeric(12,2);
  v_is_first boolean;
  v_pending_count int;
  v_pix text;
  v_result public.withdrawal_requests;
begin
  select id, chave_pix into v_affiliate_id, v_pix
  from public.affiliates
  where auth_user_id = auth.uid();

  if v_affiliate_id is null then
    raise exception 'Vendedor não encontrado para o usuário logado';
  end if;

  if v_pix is null or v_pix = '' then
    raise exception 'Cadastre sua chave PIX em Dados Bancários antes de solicitar saque';
  end if;

  select count(*) into v_pending_count
  from public.withdrawal_requests
  where affiliate_id = v_affiliate_id and status = 'pendente';

  if v_pending_count > 0 then
    raise exception 'Você já tem uma solicitação de saque pendente. Aguarde o pagamento antes de pedir outro.';
  end if;

  select (count(*) = 0) into v_is_first
  from public.withdrawal_requests
  where affiliate_id = v_affiliate_id and status <> 'cancelado';

  v_balance := public.get_affiliate_balance(v_affiliate_id);

  if p_valor > v_balance then
    raise exception 'Valor solicitado (%) maior que o saldo disponível (%)', p_valor, v_balance;
  end if;

  if v_is_first then
    if p_valor < 5 then
      raise exception 'O saque mínimo é de $5';
    end if;
  else
    if p_valor not in (50, 100) and p_valor <> v_balance then
      raise exception 'Após o primeiro saque, os valores permitidos são $50, $100 ou o saldo total ($%)', v_balance;
    end if;
  end if;

  insert into public.withdrawal_requests (affiliate_id, valor, chave_pix_snapshot)
  values (v_affiliate_id, p_valor, v_pix)
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.request_withdrawal(numeric) to authenticated, service_role;
revoke execute on function public.request_withdrawal(numeric) from public, anon;

-- Admin confirma que o PIX foi pago manualmente por fora do app
create or replace function public.confirm_withdrawal_payment(p_request_id uuid)
returns public.withdrawal_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.withdrawal_requests;
begin
  if not public.is_admin() then
    raise exception 'Apenas administradores podem confirmar pagamentos';
  end if;

  update public.withdrawal_requests
  set status = 'pago', paid_at = now(), paid_by = auth.uid()
  where id = p_request_id and status = 'pendente'
  returning * into v_result;

  if v_result is null then
    raise exception 'Solicitação não encontrada ou já processada';
  end if;

  return v_result;
end;
$$;

grant execute on function public.confirm_withdrawal_payment(uuid) to authenticated, service_role;
revoke execute on function public.confirm_withdrawal_payment(uuid) from public, anon;
