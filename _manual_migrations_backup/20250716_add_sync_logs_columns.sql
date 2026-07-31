-- ============================================
-- Migração: sync_logs novas colunas
-- Execute este arquivo no SQL Editor do Supabase
-- ============================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sync_logs' AND column_name='transactions_updated') THEN
    ALTER TABLE sync_logs ADD COLUMN transactions_updated INT DEFAULT 0;
    COMMENT ON COLUMN sync_logs.transactions_updated IS 'Vendas existentes atualizadas (mudança de status/valor)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sync_logs' AND column_name='transactions_failed') THEN
    ALTER TABLE sync_logs ADD COLUMN transactions_failed INT DEFAULT 0;
    COMMENT ON COLUMN sync_logs.transactions_failed IS 'Transações que falharam durante o processamento';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sync_logs' AND column_name='duration_ms') THEN
    ALTER TABLE sync_logs ADD COLUMN duration_ms INT DEFAULT 0;
    COMMENT ON COLUMN sync_logs.duration_ms IS 'Duração total da sincronização em milissegundos';
  END IF;
END $$;
