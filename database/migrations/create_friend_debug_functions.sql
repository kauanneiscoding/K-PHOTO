-- Remover funções existentes para evitar conflitos
DROP FUNCTION IF EXISTS debug_friendship(UUID, UUID);
DROP FUNCTION IF EXISTS get_user_friends(UUID);

-- Função para debug de amizades
CREATE FUNCTION debug_friendship(
    user_a UUID,
    user_b UUID
)
RETURNS TABLE(
    friendship_exists BOOLEAN,
    friendship_record JSON,
    user_a_friends JSON,
    user_b_friends JSON
) AS $$
BEGIN
    -- Verificar se existe amizade entre os dois usuários
    RETURN QUERY
    SELECT 
        EXISTS(
            SELECT 1 FROM friends 
            WHERE (user1_id = user_a AND user2_id = user_b) 
            OR (user1_id = user_b AND user2_id = user_a)
        ) as friendship_exists,
        (
            SELECT json_build_object(
                'id', id,
                'user1_id', user1_id,
                'user2_id', user2_id,
                'created_at', created_at
            ) FROM friends 
            WHERE (user1_id = user_a AND user2_id = user_b) 
            OR (user1_id = user_b AND user2_id = user_a)
            LIMIT 1
        ) as friendship_record,
        (
            SELECT json_agg(
                json_build_object(
                    'friend_id', CASE WHEN user1_id = user_a THEN user2_id ELSE user1_id END,
                    'created_at', created_at
                )
            ) FROM friends 
            WHERE user1_id = user_a OR user2_id = user_a
        ) as user_a_friends,
        (
            SELECT json_agg(
                json_build_object(
                    'friend_id', CASE WHEN user1_id = user_b THEN user2_id ELSE user1_id END,
                    'created_at', created_at
                )
            ) FROM friends 
            WHERE user1_id = user_b OR user2_id = user_b
        ) as user_b_friends;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para listar todas as amizades de um usuário
CREATE FUNCTION get_user_friends(
    target_user UUID DEFAULT auth.uid()
)
RETURNS TABLE(
    friend_id UUID,
    friendship_id UUID,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE WHEN user1_id = target_user THEN user2_id ELSE user1_id END as friend_id,
        id as friendship_id,
        created_at
    FROM friends 
    WHERE user1_id = target_user OR user2_id = target_user
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION debug_friendship(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_friends(UUID) TO authenticated;
