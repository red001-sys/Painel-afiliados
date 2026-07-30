-- ============================================
-- Migração incremental: sync_state + sales columns
-- Execute este arquivo no SQL Editor do Supabase
-- ============================================

-- --------------------------------------------
-- sales: novas colunas (ignora se já existir)
-- --------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sales' AND column_name='event_id') THEN
    ALTER TABLE sales ADD COLUMN event_id TEXT;
    COMMENT ON COLUMN sales.event_id IS 'ID do evento (quando disponível pela plataforma)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sales' AND column_name='action_id') THEN
    ALTER TABLE sales ADD COLUMN action_id TEXT;
    COMMENT ON COLUMN sales.action_id IS 'ID da ação (quando disponível pela plataforma)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sales' AND column_name='publisher_commission_id') THEN
    ALTER TABLE sales ADD COLUMN publisher_commission_id TEXT;
    COMMENT ON COLUMN sales.publisher_commission_id IS 'ID da comissão do publisher (quando disponível)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sales' AND column_name='updated_at') THEN
    ALTER TABLE sales ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
    COMMENT ON COLUMN sales.updated_at IS 'Última atualização do registro (status, valores, etc.)';
  END IF;
END $$;

-- --------------------------------------------
-- sync_state: tabela nova (ignora se já existir)
-- --------------------------------------------
CREATE TABLE IF NOT EXISTS sync_state (
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

DROP POLICY IF EXISTS "sync_state_admin_all" ON sync_state;
CREATE POLICY "sync_state_admin_all"
  ON sync_state FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
