CREATE TABLE IF NOT EXISTS profile_wall_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(profile_user_id, user_id)
);

ALTER TABLE user_profile
ADD COLUMN IF NOT EXISTS mural_likes_count INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_profile_wall_likes_profile_user_id ON profile_wall_likes(profile_user_id);
CREATE INDEX IF NOT EXISTS idx_profile_wall_likes_user_id ON profile_wall_likes(user_id);

CREATE OR REPLACE FUNCTION update_profile_wall_likes_count(profile_user_id_param UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_profile
  SET mural_likes_count = (
    SELECT COUNT(*)
    FROM profile_wall_likes
    WHERE profile_user_id = profile_user_id_param
  )
  WHERE user_id = profile_user_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
