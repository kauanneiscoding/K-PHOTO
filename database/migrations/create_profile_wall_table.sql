-- Criar tabela para o mural do perfil
CREATE TABLE IF NOT EXISTS profile_wall (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position >= 0 AND position <= 2),
  photocard_instance_id TEXT,
  photocard_image_path TEXT,
  placed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Garante que cada usuário tenha no máximo um photocard por posição
  UNIQUE(user_id, position)
);

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_profile_wall_user_id ON profile_wall(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_wall_position ON profile_wall(position);
CREATE INDEX IF NOT EXISTS idx_profile_wall_photocard_instance_id ON profile_wall(photocard_instance_id);

-- Criar trigger para atualizar o updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profile_wall_updated_at 
    BEFORE UPDATE ON profile_wall 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Adicionar comentários
COMMENT ON TABLE profile_wall IS 'Mural do perfil do usuário onde podem ser exibidos até 3 photocards';
COMMENT ON COLUMN profile_wall.position IS 'Posição no mural (0, 1, ou 2)';
COMMENT ON COLUMN profile_wall.photocard_instance_id IS 'ID do photocard colocado nesta posição';
COMMENT ON COLUMN profile_wall.photocard_image_path IS 'Caminho da imagem do photocard';
