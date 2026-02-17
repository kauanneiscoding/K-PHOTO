-- Corrigir políticas RLS da tabela friends para usar user_id e friend_id

-- Remover políticas antigas
DROP POLICY IF EXISTS "Users can insert friendships" ON friends;
DROP POLICY IF EXISTS "Users can delete friendships" ON friends;
DROP POLICY IF EXISTS "Users can view their own friendships" ON friends;

-- Criar políticas corretas para user_id e friend_id
CREATE POLICY "Users can view their own friendships" ON friends
    FOR SELECT USING (
        auth.uid() = user_id OR 
        auth.uid() = friend_id
    );

CREATE POLICY "Users can insert friendships" ON friends
    FOR INSERT WITH CHECK (
        auth.uid() = user_id OR 
        auth.uid() = friend_id
    );

CREATE POLICY "Users can delete friendships" ON friends
    FOR DELETE USING (
        auth.uid() = user_id OR 
        auth.uid() = friend_id
    );
