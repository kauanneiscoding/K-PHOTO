-- Remover índices existentes primeiro
DROP INDEX IF EXISTS idx_purchased_frames_user_id;
DROP INDEX IF EXISTS idx_purchased_frames_frame_path;

-- Remover políticas RLS existentes
DROP POLICY IF EXISTS "Users can view their own purchased frames" ON purchased_frames;
DROP POLICY IF EXISTS "Users can insert their own purchased frames" ON purchased_frames;
DROP POLICY IF EXISTS "Users can update their own purchased frames" ON purchased_frames;
DROP POLICY IF EXISTS "Users can delete their own purchased frames" ON purchased_frames;

-- Remover a tabela existente
DROP TABLE IF EXISTS purchased_frames CASCADE;

-- Recriar a tabela purchased_frames no Supabase com estrutura correta
CREATE TABLE purchased_frames (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    frame_path TEXT NOT NULL,
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, frame_path)
);

-- Índices para melhor performance
CREATE INDEX idx_purchased_frames_user_id ON purchased_frames(user_id);
CREATE INDEX idx_purchased_frames_frame_path ON purchased_frames(frame_path);

-- RLS (Row Level Security)
ALTER TABLE purchased_frames ENABLE ROW LEVEL SECURITY;

-- Política para usuários verem apenas seus próprios frames
CREATE POLICY "Users can view their own purchased frames" ON purchased_frames
    FOR SELECT USING (auth.uid()::text = user_id);

-- Política para usuários inserirem seus próprios frames
CREATE POLICY "Users can insert their own purchased frames" ON purchased_frames
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Política para usuários atualizarem seus próprios frames
CREATE POLICY "Users can update their own purchased frames" ON purchased_frames
    FOR UPDATE USING (auth.uid()::text = user_id);

-- Política para usuários deletarem seus próprios frames
CREATE POLICY "Users can delete their own purchased frames" ON purchased_frames
    FOR DELETE USING (auth.uid()::text = user_id);
