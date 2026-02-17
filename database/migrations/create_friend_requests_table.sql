-- Tabela de solicitações de amizade
CREATE TABLE IF NOT EXISTS friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Garante que não haverá solicitações duplicadas
    CONSTRAINT unique_request UNIQUE (sender_id, receiver_id),
    -- Garante que não pode enviar solicitação para si mesmo
    CONSTRAINT not_self CHECK (sender_id != receiver_id)
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_friend_requests_sender_id ON friend_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver_id ON friend_requests(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON friend_requests(status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_created_at ON friend_requests(created_at);

-- RLS (Row Level Security)
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes para evitar conflitos
DROP POLICY IF EXISTS "Users can view their own friend requests" ON friend_requests;
DROP POLICY IF EXISTS "Users can send friend requests" ON friend_requests;
DROP POLICY IF EXISTS "Users can update received friend requests" ON friend_requests;
DROP POLICY IF EXISTS "Users can delete their own friend requests" ON friend_requests;

-- Usuários podem ver solicitações enviadas ou recebidas
CREATE POLICY "Users can view their own friend requests" ON friend_requests
    FOR SELECT USING (
        auth.uid() = sender_id OR 
        auth.uid() = receiver_id
    );

-- Usuários podem inserir solicitações enviadas por eles
CREATE POLICY "Users can send friend requests" ON friend_requests
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id
    );

-- Usuários podem atualizar solicitações recebidas (aceitar/rejeitar)
CREATE POLICY "Users can update received friend requests" ON friend_requests
    FOR UPDATE USING (
        auth.uid() = receiver_id
    );

-- Usuários podem deletar solicitações enviadas ou recebidas
CREATE POLICY "Users can delete their own friend requests" ON friend_requests
    FOR DELETE USING (
        auth.uid() = sender_id OR 
        auth.uid() = receiver_id
    );

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_friend_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remover trigger existente para evitar conflitos
DROP TRIGGER IF EXISTS friend_requests_updated_at ON friend_requests;

CREATE TRIGGER friend_requests_updated_at
    BEFORE UPDATE ON friend_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_friend_requests_updated_at();
