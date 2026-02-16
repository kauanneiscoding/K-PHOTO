-- Adicionar campo bio à tabela user_profile
ALTER TABLE user_profile ADD COLUMN bio TEXT;

-- Adicionar comentário sobre o campo
COMMENT ON COLUMN user_profile.bio IS 'Bio do usuário - descrição personalizada do perfil (máximo 500 caracteres)';

-- Verificar o resultado
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name='user_profile' AND column_name='bio';
