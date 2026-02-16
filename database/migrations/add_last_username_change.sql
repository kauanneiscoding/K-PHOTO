-- Adicionar campo last_username_change à tabela user_profile
ALTER TABLE user_profile ADD COLUMN last_username_change TIMESTAMPTZ;

-- Adicionar comentário sobre o campo
COMMENT ON COLUMN user_profile.last_username_change IS 'Data da última alteração de username (cooldown de 30 dias)';

-- Definir valor padrão nulo para usuários existentes
UPDATE user_profile SET last_username_change = NULL WHERE last_username_change IS NULL;

-- Verificar o resultado
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name='user_profile' AND column_name='last_username_change';
