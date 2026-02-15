-- Execute este script diretamente no SQL Editor do Supabase Dashboard

-- 1. Verificar se a coluna existe
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name='user_profile' AND column_name='theme';

-- 2. Se não existir, adicionar a coluna
-- (Descomente a linha abaixo se a coluna não existir)
-- ALTER TABLE user_profile ADD COLUMN theme VARCHAR(20) DEFAULT 'pink';

-- 3. Atualizar registros existentes (se necessário)
-- UPDATE user_profile SET theme = 'pink' WHERE theme IS NULL;

-- 4. Verificar o resultado
SELECT user_id, username, theme FROM user_profile LIMIT 5;
