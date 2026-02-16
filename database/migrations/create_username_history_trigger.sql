-- Trigger para automaticamente salvar username antigo no histórico quando for alterado

-- Função para salvar username antigo no histórico
CREATE OR REPLACE FUNCTION save_username_to_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Salva o username antigo no histórico apenas se realmente mudou
    IF OLD.username IS NOT NULL AND OLD.username != NEW.username THEN
        INSERT INTO username_history (user_id, username, changed_at, expires_at)
        VALUES (
            NEW.user_id,
            OLD.username,
            NOW(),
            NOW() + INTERVAL '30 days'
        );
        
        -- Log para debugging
        RAISE LOG 'Username antigo "%" salvo no histórico para usuário %', OLD.username, NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remove trigger antigo se existir
DROP TRIGGER IF EXISTS trigger_save_username_to_history ON user_profile;

-- Cria o trigger que será executado antes de atualizar o username
CREATE TRIGGER trigger_save_username_to_history
BEFORE UPDATE OF username ON user_profile
FOR EACH ROW
EXECUTE FUNCTION save_username_to_history();

-- Comentário para documentação
COMMENT ON FUNCTION save_username_to_history() IS 'Salva automaticamente o username antigo no histórico quando é alterado.';
COMMENT ON TRIGGER trigger_save_username_to_history ON user_profile IS 'Trigger para salvar username antigo no histórico a cada alteração.';
