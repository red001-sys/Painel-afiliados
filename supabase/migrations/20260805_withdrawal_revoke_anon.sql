-- Revoga EXECUTE do papel anon nas funções de saque.
-- As default privileges do Supabase concedem EXECUTE diretamente a
-- anon/authenticated/service_role em toda função criada no schema public,
-- então revoke from public não é suficiente — precisa revogar do anon.
revoke execute on function public.get_affiliate_balance(uuid) from anon;
revoke execute on function public.request_withdrawal(numeric) from anon;
revoke execute on function public.confirm_withdrawal_payment(uuid) from anon;
