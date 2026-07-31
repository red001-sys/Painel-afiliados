-- ============================================
-- Migração: Adicionar policies admin na tabela affiliates
-- Admin precisa de INSERT, UPDATE, DELETE
-- Execute no SQL Editor do Supabase
-- =================================-----------

-- Admin pode SELECT todos os affiliates
CREATE POLICY "affiliates_admin_select"
  ON affiliates FOR SELECT
  USING (public.is_admin());

-- Admin pode INSERT affiliates
CREATE POLICY "affiliates_admin_insert"
  ON affiliates FOR INSERT
  WITH CHECK (public.is_admin());

-- Admin pode UPDATE affiliates
CREATE POLICY "affiliates_admin_update"
  ON affiliates FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Admin pode DELETE affiliates (apenas afiliados, não outros admins)
CREATE POLICY "affiliates_admin_delete"
  ON affiliates FOR DELETE
  USING (public.is_admin());
