-- ============================================
-- Migração: affiliate_links + products.descricao
-- Execute no SQL Editor do Supabase
-- ============================================

-- --------------------------------------------
-- FUNÇÃO: update_updated_at()
-- Trigger para atualizar updated_at automaticamente
-- --------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------
-- TABELA: affiliate_links
-- Links finais da CJ, vinculados a um afiliado.
-- O admin cola o link completo com SID.
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS affiliate_links (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id    UUID NOT NULL REFERENCES affiliates(id) ON DELETE CASCADE,
  product_id      UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  cj_base_link    TEXT NULL,
  final_link      TEXT NOT NULL,
  link_name       TEXT NULL,
  display_order   INTEGER DEFAULT 0,
  ativo           BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE  affiliate_links                     IS 'Links finais da CJ vinculados a um afiliado';
COMMENT ON COLUMN affiliate_links.affiliate_id        IS 'FK → affiliates.id';
COMMENT ON COLUMN affiliate_links.product_id          IS 'FK → products.id';
COMMENT ON COLUMN affiliate_links.cj_base_link        IS 'Link base da CJ (auditoria, sem SID)';
COMMENT ON COLUMN affiliate_links.final_link          IS 'Link final copiado do CJ (com SID incluso)';
COMMENT ON COLUMN affiliate_links.link_name           IS 'Nome personalizado do link';
COMMENT ON COLUMN affiliate_links.display_order       IS 'Ordem de exibição do link';
COMMENT ON COLUMN affiliate_links.updated_at          IS 'Última atualização do registro';

-- --------------------------------------------
-- TRIGGER: atualizar updated_at
-- --------------------------------------------
DROP TRIGGER IF EXISTS trg_affiliate_links_updated_at ON affiliate_links;
CREATE TRIGGER trg_affiliate_links_updated_at
  BEFORE UPDATE ON affiliate_links
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- --------------------------------------------
-- RLS
-- --------------------------------------------
ALTER TABLE affiliate_links ENABLE ROW LEVEL SECURITY;

-- Admin pode tudo nos links
DROP POLICY IF EXISTS "affiliate_links_admin_all" ON affiliate_links;
CREATE POLICY "affiliate_links_admin_all"
  ON affiliate_links FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Afiliado vê seus próprios links
DROP POLICY IF EXISTS "affiliate_links_select_own" ON affiliate_links;
CREATE POLICY "affiliate_links_select_own"
  ON affiliate_links FOR SELECT
  USING (
    affiliate_id IN (
      SELECT id FROM affiliates WHERE auth_user_id = auth.uid()
    )
  );

-- --------------------------------------------
-- ÍNDICES
-- --------------------------------------------
CREATE INDEX IF NOT EXISTS idx_affiliate_links_affiliate_id       ON affiliate_links(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_links_product_id         ON affiliate_links(product_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_links_affiliate_ativo    ON affiliate_links(affiliate_id, ativo);

-- --------------------------------------------
-- products: adicionar descricao (ignora se já existir)
-- --------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='descricao') THEN
    ALTER TABLE products ADD COLUMN descricao TEXT;
    COMMENT ON COLUMN products.descricao IS 'Descrição curta do produto';
  END IF;
END $$;
