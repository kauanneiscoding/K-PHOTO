-- Tabela de amizades (relacionamento mútuo)
CREATE TABLE IF NOT EXISTS friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Garante que não haverá duplicatas de amizade (ordem não importa)
    -- Usamos CHECK para garantir que user1_id < user2_id para evitar duplicatas invertidas
    CONSTRAINT unique_friendship UNIQUE (user1_id, user2_id),
    CONSTRAINT user_order CHECK (user1_id < user2_id)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_friends_user1_id ON friends(user1_id);
CREATE INDEX IF NOT EXISTS idx_friends_user2_id ON friends(user2_id);
CREATE INDEX IF NOT EXISTS idx_friends_created_at ON friends(created_at);

-- RLS (Row Level Security)
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes para evitar conflitos
DROP POLICY IF EXISTS "Users can view their own friendships" ON friends;
DROP POLICY IF EXISTS "Users can insert friendships" ON friends;
DROP POLICY IF EXISTS "Users can delete friendships" ON friends;

-- Usuários podem ver amizades onde são participantes
CREATE POLICY "Users can view their own friendships" ON friends
    FOR SELECT USING (
        auth.uid() = user1_id OR 
        auth.uid() = user2_id
    );

-- Usuários podem inserir amizades onde são um dos participantes
CREATE POLICY "Users can insert friendships" ON friends
    FOR INSERT WITH CHECK (
        auth.uid() = user1_id OR 
        auth.uid() = user2_id
    );

-- Usuários podem deletar amizades onde são participantes
CREATE POLICY "Users can delete friendships" ON friends
    FOR DELETE USING (
        auth.uid() = user1_id OR 
        auth.uid() = user2_id
    );
