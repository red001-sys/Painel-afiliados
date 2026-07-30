-- ============================================
-- CJ Painel - Supabase Schema
-- Execute este arquivo no SQL Editor do Supabase
-- ============================================

-- --------------------------------------------
-- TABELA: profiles
-- Controla o papel (role) de cada usuário.
-- --------------------------------------------
CREATE TABLE profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('admin', 'affiliate')),
  created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE profiles IS 'Perfis de acesso: admin ou affiliate';
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "profiles_admin_all"
  ON profiles FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (
    id = auth.uid() AND role = 'affiliate'
  );

-- --------------------------------------------
-- TABELA: affiliates
-- Armazena os afiliados cadastrados no sistema.
-- --------------------------------------------
CREATE TABLE affiliates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id  UUID UNIQUE,
  nome          TEXT,
  email         TEXT,
  sid           TEXT UNIQUE NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE  affiliates              IS 'Afiliados cadastrados no sistema CJ Painel';
COMMENT ON COLUMN affiliates.auth_user_id IS 'ID do usuário no Supabase Auth (FK implícita)';
COMMENT ON COLUMN affiliates.sid          IS 'SID único do afiliado na CJ Affiliate';

-- --------------------------------------------
-- TABELA: sales
-- Registra todas as vendas recebidas da CJ Affiliate.
-- affiliate_id  → chave estrangeira interna (consultas rápidas)
-- affiliate_sid → SID original da CJ (auditoria e rastreamento)
-- --------------------------------------------
CREATE TABLE sales (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id          TEXT UNIQUE NOT NULL,
  event_id                TEXT,
  action_id               TEXT,
  publisher_commission_id TEXT,
  affiliate_id            UUID REFERENCES affiliates(id) ON DELETE SET NULL,
  affiliate_sid           TEXT NOT NULL,
  sale_amount             NUMERIC(12,2),
  commission_amount       NUMERIC(12,2),
  status                  TEXT,
  sale_date               TIMESTAMPTZ,
  advertiser              TEXT,
  product                 TEXT,
  currency                TEXT,
  order_id                TEXT,
  locked_date             TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE  sales                           IS 'Vendas registradas via plataformas de afiliados';
COMMENT ON COLUMN sales.affiliate_id              IS 'FK → affiliates.id (chave interna para joins)';
COMMENT ON COLUMN sales.affiliate_sid             IS 'SID do afiliado na plataforma (auditoria / rastreamento)';
COMMENT ON COLUMN sales.transaction_id            IS 'ID da transação na plataforma';
COMMENT ON COLUMN sales.event_id                  IS 'ID do evento (quando disponível pela plataforma)';
COMMENT ON COLUMN sales.action_id                 IS 'ID da ação (quando disponível pela plataforma)';
COMMENT ON COLUMN sales.publisher_commission_id   IS 'ID da comissão do publisher (quando disponível)';
COMMENT ON COLUMN sales.status                    IS 'Status: pending, approved, rejected, locked';
COMMENT ON COLUMN sales.sale_amount               IS 'Valor total da venda';
COMMENT ON COLUMN sales.commission_amount         IS 'Valor da comissão do afiliado';
COMMENT ON COLUMN sales.updated_at                IS 'Última atualização do registro (status, valores, etc.)';

-- --------------------------------------------
-- ÍNDICES
-- Otimizam consultas frequentes por colunas
-- usadas em filtros, joins e ordenação.
-- --------------------------------------------
CREATE INDEX idx_sales_affiliate_sid  ON sales(affiliate_sid);
CREATE INDEX idx_sales_affiliate_id   ON sales(affiliate_id);
CREATE INDEX idx_sales_sale_date      ON sales(sale_date);
CREATE INDEX idx_sales_status         ON sales(status);
CREATE INDEX idx_products_ativo       ON products(ativo);
CREATE INDEX idx_sync_logs_started_at ON sync_logs(started_at DESC);

-- --------------------------------------------
-- ROW LEVEL SECURITY (RLS)
-- Garante que cada usuário só enxerga seus
-- próprios dados. Nenhum INSERT/UPDATE/DELETE
-- é permitido via client — apenas via Service
-- Role (Edge Functions).
-- --------------------------------------------
ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales      ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------
-- POLÍTICA: affiliates
-- O usuário autenticado só pode ler o próprio
-- registro de afiliado (onde auth_user_id = uid).
-- --------------------------------------------
CREATE POLICY "affiliate_select_own"
  ON affiliates FOR SELECT
  USING (auth_user_id = auth.uid());

-- --------------------------------------------
-- POLÍTICA: sales
-- O usuário autenticado só pode ler vendas
-- cujo affiliate_sid corresponda ao sid do
-- seu registro em affiliates.
-- --------------------------------------------
CREATE POLICY "sales_select_own"
  ON sales FOR SELECT
  USING (
    affiliate_sid IN (
      SELECT sid FROM affiliates WHERE auth_user_id = auth.uid()
    )
  );

-- --------------------------------------------
-- FUNÇÃO: link_affiliate_to_auth
-- Chamada após o signUp para vincular o
-- auth_user_id ao registro do afiliado.
-- SECURITY DEFINER para bypass do RLS.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION link_affiliate_to_auth(
  p_email TEXT,
  p_auth_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.affiliates
  SET auth_user_id = p_auth_user_id
  WHERE email = p_email
    AND auth_user_id IS NULL;
END;
$$;

-- --------------------------------------------
-- FUNÇÃO: check_affiliate_for_first_access
-- Verifica se existe afiliado com o email
-- e se já foi ativado. Usado no primeiro acesso.
-- SECURITY DEFINER para bypass do RLS.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION check_affiliate_for_first_access(
  p_email TEXT
)
RETURNS TABLE(found BOOLEAN, activated BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    TRUE,
    (a.auth_user_id IS NOT NULL)
  FROM affiliates a
  WHERE a.email = p_email
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, FALSE;
  END IF;
END;
$$;

-- --------------------------------------------
-- FUNÇÃO: ensure_affiliate_exists
-- Após login, garante que o afiliado está
-- vinculado ao usuário autenticado.
-- Caso não exista, cria automaticamente.
-- Retorna o registro do afiliado.
-- SECURITY DEFINER para bypass do RLS.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION ensure_affiliate_exists()
RETURNS SETOF affiliates
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_email TEXT;
  v_nome TEXT;
  v_sid TEXT;
  v_sid_base TEXT;
  v_counter INT := 1;
  v_affiliate affiliates%ROWTYPE;
BEGIN
  v_user_id := auth.uid();
  v_email := (SELECT email FROM auth.users WHERE id = v_user_id LIMIT 1);

  IF v_email IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado';
  END IF;

  -- Busca afiliado existente pelo email
  SELECT * INTO v_affiliate
  FROM affiliates
  WHERE email = v_email
  LIMIT 1;

  -- Caso 1: Encontrou com auth_user_id NULL → atualiza
  IF FOUND AND v_affiliate.auth_user_id IS NULL THEN
    UPDATE affiliates
    SET auth_user_id = v_user_id
    WHERE id = v_affiliate.id
    RETURNING * INTO v_affiliate;
    RETURN NEXT v_affiliate;
    RETURN;
  END IF;

  -- Caso 2: Encontrou com auth_user_id preenchido → retorna
  IF FOUND THEN
    RETURN NEXT v_affiliate;
    RETURN;
  END IF;

  -- Caso 3: Não encontrou → cria automaticamente
  v_sid_base := lower(replace(replace(replace(
    split_part(v_email, '@', 1), '.', '_'), ' ', ''), '-', '_'));

  -- Gera SID único
  v_sid := v_sid_base;
  WHILE EXISTS (SELECT 1 FROM affiliates WHERE sid = v_sid) LOOP
    v_counter := v_counter + 1;
    v_sid := v_sid_base || v_counter::TEXT;
  END LOOP;

  v_nome := split_part(v_email, '@', 1);

  INSERT INTO affiliates (auth_user_id, email, nome, sid)
  VALUES (v_user_id, v_email, v_nome, v_sid)
  RETURNING * INTO v_affiliate;

  RETURN NEXT v_affiliate;
  RETURN;
END;
$$;

-- --------------------------------------------
-- TABELA: sync_logs
-- Registra cada execução de sincronização
-- com a API da CJ Affiliate.
-- --------------------------------------------
CREATE TABLE sync_logs (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at             TIMESTAMPTZ DEFAULT now(),
  finished_at            TIMESTAMPTZ,
  transactions_read      INT DEFAULT 0,
  transactions_imported  INT DEFAULT 0,
  transactions_skipped   INT DEFAULT 0,
  unknown_sid            INT DEFAULT 0,
  status                 TEXT DEFAULT 'running',
  error_message          TEXT
);

COMMENT ON TABLE sync_logs IS 'Log de sincronizações com a CJ Affiliate';

ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sync_logs_admin_select"
  ON sync_logs FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- --------------------------------------------
-- TABELA: sync_state
-- Armazena o estado da sincronização incremental
-- por provider. Controla desde quando buscar
-- transações novas.
-- --------------------------------------------
CREATE TABLE sync_state (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider               TEXT UNIQUE NOT NULL,
  last_sync_at           TIMESTAMPTZ,
  last_transaction_date  TIMESTAMPTZ,
  created_at             TIMESTAMPTZ DEFAULT now(),
  updated_at             TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE sync_state IS 'Estado da sincronização incremental por provider';
COMMENT ON COLUMN sync_state.provider               IS 'Nome do provider (ex: cj, awin, impact)';
COMMENT ON COLUMN sync_state.last_sync_at           IS 'Data/hora da última execução de sincronização';
COMMENT ON COLUMN sync_state.last_transaction_date  IS 'Data da última transação importada com sucesso';

ALTER TABLE sync_state ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------
-- TABELA: products
-- Produtos disponíveis para geração de links.
-- --------------------------------------------
CREATE TABLE products (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        TEXT NOT NULL,
  categoria   TEXT,
  cj_url      TEXT,
  imagem_url  TEXT,
  ativo       BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE products IS 'Produtos para geração de links de afiliados';
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products_select_all"
  ON products FOR SELECT
  USING (true);

CREATE POLICY "products_admin_insert"
  ON products FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "products_admin_update"
  ON products FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "products_admin_delete"
  ON products FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
