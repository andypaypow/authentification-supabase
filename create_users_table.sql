-- Création de la table users pour les informations supplémentaires des utilisateurs
-- Cette table étend les informations d'authentification de base de Supabase

CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    username TEXT UNIQUE,
    avatar_url TEXT,
    phone TEXT,
    bio TEXT,
    role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'moderator', 'user')),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activer Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Politiques de sécurité
-- 1. Les utilisateurs peuvent voir leur propre profil
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

-- 2. Les utilisateurs peuvent mettre à jour leur propre profil
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- 3. Les utilisateurs peuvent insérer leur propre profil (après inscription)
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 4. Les administrateurs peuvent voir tous les profils
CREATE POLICY "Admins can view all profiles" ON public.users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- 5. Les administrateurs peuvent mettre à jour tous les profils
CREATE POLICY "Admins can update all profiles" ON public.users
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Trigger pour créer automatiquement un profil utilisateur après inscription
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users(created_at);

-- Commentaires
COMMENT ON TABLE public.users IS 'Table contenant les informations supplémentaires des utilisateurs';
COMMENT ON COLUMN public.users.id IS 'Référence à l''ID d''authentification Supabase';
COMMENT ON COLUMN public.users.email IS 'Adresse email de l''utilisateur';
COMMENT ON COLUMN public.users.full_name IS 'Nom complet de l''utilisateur';
COMMENT ON COLUMN public.users.username IS 'Pseudo unique de l''utilisateur';
COMMENT ON COLUMN public.users.avatar_url IS 'URL de la photo de profil';
COMMENT ON COLUMN public.users.role IS 'Rôle de l''utilisateur (admin, moderator, user)';
COMMENT ON COLUMN public.users.is_active IS 'Indique si le compte est actif';
COMMENT ON COLUMN public.users.last_login IS 'Date du dernier login';
COMMENT ON COLUMN public.users.created_at IS 'Date de création du compte';
COMMENT ON COLUMN public.users.updated_at IS 'Date de dernière mise à jour';