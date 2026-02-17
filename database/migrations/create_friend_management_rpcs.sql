-- Remover funções existentes para evitar conflitos
DROP FUNCTION IF EXISTS send_friend_request(UUID);
DROP FUNCTION IF EXISTS accept_friend_request(UUID, UUID);
DROP FUNCTION IF EXISTS reject_friend_request(UUID, UUID);
DROP FUNCTION IF EXISTS remove_friend(UUID);

-- RPC function para enviar solicitação de amizade
CREATE FUNCTION send_friend_request(
    target_user UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    request_exists BOOLEAN;
    friendship_exists BOOLEAN;
    is_self BOOLEAN;
BEGIN
    -- Verificar se está tentando adicionar a si mesmo
    is_self := (target_user = auth.uid());
    
    IF is_self THEN
        RETURN QUERY SELECT FALSE, 'Cannot send friend request to yourself'::TEXT;
        RETURN;
    END IF;
    
    -- Verificar se já existe uma solicitação
    SELECT EXISTS(
        SELECT 1 FROM friend_requests 
        WHERE ((sender_id = auth.uid() AND receiver_id = target_user) 
        OR (sender_id = target_user AND receiver_id = auth.uid()))
        AND status = 'pending'
    ) INTO request_exists;
    
    IF request_exists THEN
        RETURN QUERY SELECT FALSE, 'Friend request already exists'::TEXT;
        RETURN;
    END IF;
    
    -- Verificar se já são amigos
    SELECT EXISTS(
        SELECT 1 FROM friends 
        WHERE (user1_id = auth.uid() AND user2_id = target_user) 
        OR (user1_id = target_user AND user2_id = auth.uid())
    ) INTO friendship_exists;
    
    IF friendship_exists THEN
        RETURN QUERY SELECT FALSE, 'Users are already friends'::TEXT;
        RETURN;
    END IF;
    
    -- Criar solicitação de amizade
    INSERT INTO friend_requests (sender_id, receiver_id)
    VALUES (auth.uid(), target_user);
    
    RETURN QUERY SELECT TRUE, 'Friend request sent successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC function para aceitar solicitação de amizade
CREATE FUNCTION accept_friend_request(
    sender UUID,
    receiver UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    request_exists BOOLEAN;
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
    
    -- Atualizar status da solicitação
    UPDATE friend_requests 
    SET status = 'accepted', updated_at = NOW()
    WHERE sender_id = sender 
    AND receiver_id = receiver 
    AND status = 'pending';
    
    -- Criar amizade (garantir ordem correta: user1_id < user2_id)
    INSERT INTO friends (user1_id, user2_id)
    VALUES (
        LEAST(sender, receiver),
        GREATEST(sender, receiver)
    );
    
    RETURN QUERY SELECT TRUE, 'Friend request accepted successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC function para rejeitar solicitação de amizade
CREATE FUNCTION reject_friend_request(
    sender UUID,
    receiver UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    request_exists BOOLEAN;
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
    
    -- Atualizar status da solicitação
    UPDATE friend_requests 
    SET status = 'rejected', updated_at = NOW()
    WHERE sender_id = sender 
    AND receiver_id = receiver 
    AND status = 'pending';
    
    RETURN QUERY SELECT TRUE, 'Friend request rejected successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC function para remover amizade
CREATE FUNCTION remove_friend(
    friend_user UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    friendship_exists BOOLEAN;
    deleted_count INTEGER;
BEGIN
    -- Verificar se está tentando remover a si mesmo
    IF friend_user = auth.uid() THEN
        RETURN QUERY SELECT FALSE, 'Cannot remove yourself as friend'::TEXT;
        RETURN;
    END IF;
    
    -- Verificar se a amizade existe
    SELECT EXISTS(
        SELECT 1 FROM friends 
        WHERE (user1_id = auth.uid() AND user2_id = friend_user) 
        OR (user1_id = friend_user AND user2_id = auth.uid())
    ) INTO friendship_exists;
    
    IF NOT friendship_exists THEN
        RETURN QUERY SELECT FALSE, 'Friendship not found'::TEXT;
        RETURN;
    END IF;
    
    -- Remover amizade (deve remover apenas um registro devido à estrutura da tabela)
    DELETE FROM friends 
    WHERE (user1_id = auth.uid() AND user2_id = friend_user) 
    OR (user1_id = friend_user AND user2_id = auth.uid());
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    IF deleted_count > 0 THEN
        RETURN QUERY SELECT TRUE, 'Friendship removed successfully'::TEXT;
    ELSE
        RETURN QUERY SELECT FALSE, 'Failed to remove friendship'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions para executar as funções
GRANT EXECUTE ON FUNCTION send_friend_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION reject_friend_request(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_friend(UUID) TO authenticated;
