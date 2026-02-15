-- Verificar se a coluna theme existe e adicionar se necessário
DO $$
BEGIN
    -- Verificar se a coluna theme existe na tabela user_profile
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='user_profile' 
        AND column_name='theme'
    ) THEN
        -- Adicionar a coluna se não existir
        ALTER TABLE user_profile ADD COLUMN theme VARCHAR(20) DEFAULT 'pink';
        
        -- Atualizar registros existentes
        UPDATE user_profile SET theme = 'pink' WHERE theme IS NULL;
        
        RAISE NOTICE 'Coluna theme adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna theme já existe';
    END IF;
END $$;

-- Verificar o resultado
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name='user_profile' AND column_name='theme';
