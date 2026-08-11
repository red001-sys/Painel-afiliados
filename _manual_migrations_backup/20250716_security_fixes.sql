-- ============================================
-- Migração de segurança: fixes críticos
-- Execute este arquivo no SQL Editor do Supabase
-- ============================================

-- --------------------------------------------
-- Fix #1: link_affiliate_to_auth — prevenir hijacking
-- Usa auth.uid() internamente, ignora parâmetro
-- --------------------------------------------
CREATE OR REPLACE FUNCTION link_affiliate_to_auth(
  p_email TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.affiliates
  SET auth_user_id = v_user_id
  WHERE email = p_email
    AND auth_user_id IS NULL;
END;
$$;

-- --------------------------------------------
-- Fix #2: check_affiliate_for_first_access
-- Mantido para authenticated (necessário no first access)
-- Apenas anon bloqueado
-- --------------------------------------------
REVOKE EXECUTE ON FUNCTION check_affiliate_for_first_access(TEXT) FROM anon;

-- --------------------------------------------
-- Fix #3: Profilis — prevenir admin deletar outros admins
-- --------------------------------------------
DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_select" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_insert" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_delete" ON profiles;

CREATE POLICY "profiles_admin_select"
  ON profiles FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "profiles_admin_insert"
  ON profiles FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "profiles_admin_update"
  ON profiles FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Admin pode deletar apenas perfis de vendedores (não outros admins)
CREATE POLICY "profiles_admin_delete"
  ON profiles FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    AND role = 'affiliate'
  );

-- --------------------------------------------
-- Fix #4: Schema constraints
-- --------------------------------------------
DO $$
BEGIN
  -- Normalizar status inválidos na tabela sales
  UPDATE sales SET status = 'pending' WHERE status NOT IN ('pending', 'approved', 'rejected', 'locked');
  UPDATE sales SET status = 'pending' WHERE status IS NULL;

  -- Normalizar status inválidos na tabela sync_logs
  UPDATE sync_logs SET status = 'error' WHERE status NOT IN ('running', 'success', 'partial', 'error');
  UPDATE sync_logs SET status = 'running' WHERE status IS NULL;

  -- affiliates.nome NOT NULL
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='affiliates' AND column_name='nome' AND is_nullable='YES') THEN
    UPDATE affiliates SET nome = 'Sem nome' WHERE nome IS NULL;
    ALTER TABLE affiliates ALTER COLUMN nome SET NOT NULL;
  END IF;

  -- affiliates.email NOT NULL
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='affiliates' AND column_name='email' AND is_nullable='YES') THEN
    ALTER TABLE affiliates ALTER COLUMN email SET NOT NULL;
  END IF;

  -- sales.status NOT NULL + CHECK
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sales' AND column_name='status' AND is_nullable='YES') THEN
    ALTER TABLE sales ALTER COLUMN status SET NOT NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sales_status_check') THEN
    ALTER TABLE sales ADD CONSTRAINT sales_status_check CHECK (status IN ('pending', 'approved', 'rejected', 'locked'));
  END IF;

  -- sync_logs.status CHECK
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='sync_logs_status_check') THEN
    ALTER TABLE sync_logs ADD CONSTRAINT sync_logs_status_check CHECK (status IN ('running', 'success', 'partial', 'error'));
  END IF;
END $$;

-- --------------------------------------------
-- Fix #5: Índices (mover para após tabelas)
-- --------------------------------------------
CREATE INDEX IF NOT EXISTS idx_products_ativo ON products(ativo) WHERE ativo = true;
CREATE INDEX IF NOT EXISTS idx_sync_logs_started_at ON sync_logs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_affiliate_links_affiliate_id ON affiliate_links(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_links_ativo ON affiliate_links(ativo) WHERE ativo = true;
