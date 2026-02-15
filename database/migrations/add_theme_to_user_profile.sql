-- Adicionar campo theme à tabela user_profile
ALTER TABLE user_profile ADD COLUMN theme VARCHAR(20) DEFAULT 'pink';

-- Atualizar perfis existentes para ter o tema padrão
UPDATE user_profile SET theme = 'pink' WHERE theme IS NULL;

-- Adicionar comentário sobre o campo
COMMENT ON COLUMN user_profile.theme IS 'Tema do perfil do usuário: pink, purple, light, dark';
