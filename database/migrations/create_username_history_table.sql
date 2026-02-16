-- Criar tabela para histórico de usernames
-- Guarda usernames antigos por 30 dias para evitar reuso imediato

CREATE TABLE IF NOT EXISTS username_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    
    -- Índices para performance
    CONSTRAINT username_history_user_username_unique UNIQUE(user_id, username),
    CONSTRAINT username_history_username_check CHECK (length(username) >= 3 AND length(username) <= 50)
);

-- Índices para consultas rápidas
CREATE INDEX IF NOT EXISTS idx_username_history_user_id ON username_history(user_id);
CREATE INDEX IF NOT EXISTS idx_username_history_username ON username_history(username);
CREATE INDEX IF NOT EXISTS idx_username_history_expires_at ON username_history(expires_at);

-- Função para limpar registros expirados automaticamente
CREATE OR REPLACE FUNCTION cleanup_expired_usernames()
RETURNS void AS $$
BEGIN
    DELETE FROM username_history WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Criar trigger para limpeza automática (opcional - pode ser chamado por um job)
-- CREATE OR REPLACE FUNCTION trigger_cleanup_expired_usernames()
-- RETURNS trigger AS $$
-- BEGIN
--     PERFORM cleanup_expired_usernames();
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- Comentários para documentação
COMMENT ON TABLE username_history IS 'Histórico de usernames dos usuários. Guarda usernames antigos por 30 dias para evitar reuso.';
COMMENT ON COLUMN username_history.expires_at IS 'Data em que o username pode ser reutilizado (30 dias após a troca).';
