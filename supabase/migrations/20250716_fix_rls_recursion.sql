-- ============================================
-- Migração: Fix RLS Recursion
-- Resolve infinite recursion na tabela profiles
-- Execute no SQL Editor do Supabase
-- ============================================

-- --------------------------------------------
-- PASSO 1: Criar função SECURITY DEFINER is_admin()
-- Bypass RLS, consulta profiles sem trigger das policies
-- --------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

COMMENT ON FUNCTION public.is_admin()
  IS 'Verifica se o usuário atual é admin. SECURITY DEFINER para bypass de RLS (evita recursão).';

-- --------------------------------------------
-- PASSO 2: Dropar TODAS as policies problemáticas
-- --------------------------------------------

-- profiles: dropar tudo e recriar sem recursão
DROP POLICY IF EXISTS "profiles_select_own"      ON profiles;
DROP POLICY IF EXISTS "profiles_admin_all"        ON profiles;
DROP POLICY IF EXISTS "profiles_admin_select"     ON profiles;
DROP POLICY IF EXISTS "profiles_admin_insert"     ON profiles;
DROP POLICY IF EXISTS "profiles_admin_update"     ON profiles;
DROP POLICY IF EXISTS "profiles_admin_delete"     ON profiles;
DROP POLICY IF EXISTS "profiles_insert_own"       ON profiles;

-- sync_logs
DROP POLICY IF EXISTS "sync_logs_admin_select"    ON sync_logs;

-- products
DROP POLICY IF EXISTS "products_select_all"       ON products;
DROP POLICY IF EXISTS "products_admin_insert"     ON products;
DROP POLICY IF EXISTS "products_admin_update"     ON products;
DROP POLICY IF EXISTS "products_admin_delete"     ON products;

-- affiliate_links
DROP POLICY IF EXISTS "affiliate_links_admin_all"    ON affiliate_links;
DROP POLICY IF EXISTS "affiliate_links_select_own"   ON affiliate_links;

-- --------------------------------------------
-- PASSO 3: Recriar policies usando is_admin()
-- --------------------------------------------

-- =============================================
-- PROFILES — sem recursão
-- =============================================

-- 1. Usuário lê seu próprio perfil (id = auth.uid())
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

-- 2. Admin pode SELECT em todos os perfis
CREATE POLICY "profiles_admin_select"
  ON profiles FOR SELECT
  USING (public.is_admin());

-- 3. Admin pode INSERT perfis
CREATE POLICY "profiles_admin_insert"
  ON profiles FOR INSERT
  WITH CHECK (public.is_admin());

-- 4. Afiliado pode inserir seu próprio perfil (primeiro acesso)
CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid() AND role = 'affiliate');

-- 5. Admin pode UPDATE todos os perfis
CREATE POLICY "profiles_admin_update"
  ON profiles FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 6. Admin pode DELETE apenas afiliados (não outros admins)
CREATE POLICY "profiles_admin_delete"
  ON profiles FOR DELETE
  USING (public.is_admin() AND role = 'affiliate');

-- =============================================
-- SYNC_LOGS
-- =============================================
CREATE POLICY "sync_logs_admin_select"
  ON sync_logs FOR SELECT
  USING (public.is_admin());

-- =============================================
-- PRODUCTS
-- =============================================
CREATE POLICY "products_select_all"
  ON products FOR SELECT
  USING (true);

CREATE POLICY "products_admin_insert"
  ON products FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "products_admin_update"
  ON products FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "products_admin_delete"
  ON products FOR DELETE
  USING (public.is_admin());

-- =============================================
-- AFFILIATE_LINKS
-- =============================================
CREATE POLICY "affiliate_links_admin_all"
  ON affiliate_links FOR ALL
  USING (public.is_admin());

-- Afiliado vê seus próprios links (sem profiles reference)
CREATE POLICY "affiliate_links_select_own"
  ON affiliate_links FOR SELECT
  USING (
    affiliate_id IN (
      SELECT id FROM affiliates WHERE auth_user_id = auth.uid()
    )
  );

-- --------------------------------------------
-- PASSO 4: Confirmar que não existe mais
-- nenhuma query recursiva em policies
-- --------------------------------------------
-- Verificação: todas as policies admin agora usam
-- public.is_admin() que é SECURITY DEFINER e
-- bypass RLS, eliminando a recursão infinita.
-- --------------------------------------------
