-- RPC function para aceitar solicitação de amizade
CREATE OR REPLACE FUNCTION accept_friend_request(
    sender UUID,
    receiver UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    request_exists BOOLEAN;
    friendship_exists BOOLEAN;
    request_id UUID;
BEGIN
    -- Verificar se a solicitação existe e está pendente
    SELECT EXISTS(
        SELECT 1 FROM friend_requests 
        WHERE sender_id = sender 
        AND receiver_id = receiver 
        AND status = 'pending'
    ) INTO request_exists;
    
    IF NOT request_exists THEN
        RETURN QUERY SELECT FALSE, 'Friend request not found or already processed'::TEXT;
        RETURN;
    END IF;
    
    -- Verificar se a amizade já existe
    SELECT EXISTS(
        SELECT 1 FROM friends 
        WHERE (user1_id = sender AND user2_id = receiver) 
        OR (user1_id = receiver AND user2_id = sender)
    ) INTO friendship_exists;
    
    IF friendship_exists THEN
        RETURN QUERY SELECT FALSE, 'Friendship already exists'::TEXT;
        RETURN;
    END IF;
    
    -- Obter o ID da solicitação
    SELECT id INTO request_id FROM friend_requests 
    WHERE sender_id = sender 
    AND receiver_id = receiver 
    AND status = 'pending';
    
    -- Atualizar status da solicitação
    UPDATE friend_requests 
    SET status = 'accepted', updated_at = NOW()
    WHERE id = request_id;
    
    -- Criar amizade (garantir ordem correta: user1_id < user2_id)
    INSERT INTO friends (user1_id, user2_id)
    VALUES (
        LEAST(sender, receiver),
        GREATEST(sender, receiver)
    );
    
    RETURN QUERY SELECT TRUE, 'Friend request accepted successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permission para executar a função
GRANT EXECUTE ON FUNCTION accept_friend_request(UUID, UUID) TO authenticated;
