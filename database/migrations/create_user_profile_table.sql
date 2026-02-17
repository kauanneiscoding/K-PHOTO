-- Criar tabela user_profile se não existir
CREATE TABLE IF NOT EXISTS user_profile (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    theme TEXT DEFAULT 'default',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Adicionar colunas se não existirem
DO $$
BEGIN
    -- Adicionar username se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profile' 
        AND column_name = 'username'
    ) THEN
        ALTER TABLE user_profile 
        ADD COLUMN username TEXT UNIQUE NOT NULL;
        RAISE NOTICE 'Coluna username adicionada';
    END IF;
    
    -- Adicionar avatar_url se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profile' 
        AND column_name = 'avatar_url'
    ) THEN
        ALTER TABLE user_profile 
        ADD COLUMN avatar_url TEXT;
        RAISE NOTICE 'Coluna avatar_url adicionada';
    END IF;
    
    -- Adicionar bio se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profile' 
        AND column_name = 'bio'
    ) THEN
        ALTER TABLE user_profile 
        ADD COLUMN bio TEXT;
        RAISE NOTICE 'Coluna bio adicionada';
    END IF;
    
    -- Adicionar theme se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profile' 
        AND column_name = 'theme'
    ) THEN
        ALTER TABLE user_profile 
        ADD COLUMN theme TEXT DEFAULT 'default';
        RAISE NOTICE 'Coluna theme adicionada';
    END IF;
    
    -- Adicionar created_at se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profile' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE user_profile 
        ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE 'Coluna created_at adicionada';
    END IF;
    
    -- Adicionar updated_at se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profile' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE user_profile 
        ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE 'Coluna updated_at adicionada';
    END IF;
END $$;

-- Índices
CREATE INDEX IF NOT EXISTS idx_user_profile_username ON user_profile(username);
CREATE INDEX IF NOT EXISTS idx_user_profile_user_id ON user_profile(user_id);

-- RLS
ALTER TABLE user_profile ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes
DROP POLICY IF EXISTS "Users can view profiles" ON user_profile;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profile;

-- Políticas
CREATE POLICY "Users can view profiles" ON user_profile
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON user_profile
    FOR UPDATE USING (auth.uid() = user_id);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_user_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS user_profile_updated_at ON user_profile;
CREATE TRIGGER user_profile_updated_at
    BEFORE UPDATE ON user_profile
    FOR EACH ROW
    EXECUTE FUNCTION update_user_profile_updated_at();
