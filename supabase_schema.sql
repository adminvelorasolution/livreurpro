-- ═══════════════════════════════════════════════════════════
-- LIVEURPRO — Supabase SQL Schema
-- Atao run ao amin'ny Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════

-- ─── 1. PROFILES TABLE ───
-- Miaro ny mombamomba ny users (livreur, admin)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    nom TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'livreur')) DEFAULT 'livreur',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 2. ZONES_PRIX TABLE ───
-- Prix livraison araka ny zone
CREATE TABLE IF NOT EXISTS public.zones_prix (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone TEXT NOT NULL,
    secteur TEXT,
    prix INTEGER NOT NULL DEFAULT 3000,
    distance NUMERIC(5,1),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 3. LIVRAISONS TABLE ───
CREATE TABLE IF NOT EXISTS public.livraisons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero TEXT UNIQUE,
    livreur_id UUID REFERENCES public.profiles(id),
    livreur_nom TEXT,
    client_nom TEXT NOT NULL,
    tel_client TEXT,
    adresse TEXT NOT NULL,
    article TEXT NOT NULL,
    zone TEXT,
    zone_id UUID REFERENCES public.zones_prix(id),
    prix INTEGER DEFAULT 0,
    date DATE,
    heure TIME,
    statut TEXT NOT NULL CHECK (statut IN ('pending', 'encours', 'livree')) DEFAULT 'pending',
    remarque TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 4. CONFIG TABLE ───
-- Configuration de l'entreprise
CREATE TABLE IF NOT EXISTS public.config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom TEXT DEFAULT 'Rapid Livraison Mada',
    slogan TEXT DEFAULT 'Livraison rapide — Antananarivo',
    tel TEXT,
    email TEXT,
    adresse TEXT DEFAULT 'Antanimena, Antananarivo 101',
    footer TEXT DEFAULT 'Merci de votre confiance !',
    mention TEXT DEFAULT 'BON DE LIVRAISON',
    policy TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 5. AUTO-NUMERO LIVRAISON ───
CREATE OR REPLACE FUNCTION generate_livraison_numero()
RETURNS TRIGGER AS $$
DECLARE
    next_num INTEGER;
    new_numero TEXT;
BEGIN
    SELECT COUNT(*) + 1 INTO next_num FROM public.livraisons;
    new_numero := 'LIV-' || LPAD(next_num::TEXT, 4, '0');
    NEW.numero := new_numero;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_livraison_numero
BEFORE INSERT ON public.livraisons
FOR EACH ROW
WHEN (NEW.numero IS NULL)
EXECUTE FUNCTION generate_livraison_numero();

-- ─── 6. AUTO-UPDATE updated_at ───
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER livraisons_updated_at
BEFORE UPDATE ON public.livraisons
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

-- ─── 7. ROW LEVEL SECURITY ───
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.livraisons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zones_prix ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.config ENABLE ROW LEVEL SECURITY;

-- Profiles: chacun voit son profil, admin voit tout
CREATE POLICY "profiles_select" ON public.profiles
    FOR SELECT USING (true);

CREATE POLICY "profiles_insert" ON public.profiles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "profiles_update" ON public.profiles
    FOR UPDATE USING (true);

CREATE POLICY "profiles_delete" ON public.profiles
    FOR DELETE USING (true);

-- Livraisons: admin voit tout, livreur voit ses livraisons
CREATE POLICY "livraisons_admin_all" ON public.livraisons
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.email = auth.jwt()->>'email'
            AND profiles.role = 'admin'
        )
    );

CREATE POLICY "livraisons_livreur_select" ON public.livraisons
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.email = auth.jwt()->>'email'
            AND profiles.id = livraisons.livreur_id
        )
    );

CREATE POLICY "livraisons_livreur_update_statut" ON public.livraisons
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.email = auth.jwt()->>'email'
            AND profiles.id = livraisons.livreur_id
        )
    )
    WITH CHECK (true);

-- Zones prix: lecture pour tous, modification admin seulement
CREATE POLICY "zones_prix_select" ON public.zones_prix
    FOR SELECT USING (true);

CREATE POLICY "zones_prix_admin" ON public.zones_prix
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.email = auth.jwt()->>'email'
            AND profiles.role = 'admin'
        )
    );

-- Config: admin seulement
CREATE POLICY "config_select" ON public.config
    FOR SELECT USING (true);

CREATE POLICY "config_admin" ON public.config
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.email = auth.jwt()->>'email'
            AND profiles.role = 'admin'
        )
    );

-- ─── 8. PREMIER ADMIN (OPTIONNEL) ───
-- Ajanao ny email sy password
-- Ao amin'ny Supabase Auth: créez d'abord l'utilisateur via Authentication > Users
-- Ensuite, insérez son profil ici:
/*
INSERT INTO public.profiles (user_id, nom, email, role)
VALUES (
    '00000000-0000-0000-0000-000000000000', -- remplacer par l'UUID de l'utilisateur Auth
    'Admin Principal',
    'admin@votreentreprise.mg',
    'admin'
);

INSERT INTO public.config (nom, slogan, adresse, tel, footer, mention)
VALUES (
    'Rapid Livraison Mada',
    'Livraison rapide — Antananarivo',
    'Antanimena, Antananarivo 101',
    '+261 34 00 000 00',
    'Merci de votre confiance !',
    'BON DE LIVRAISON'
);
*/

-- ─── 9. INDEX pour performances ───
CREATE INDEX IF NOT EXISTS idx_livraisons_statut ON public.livraisons(statut);
CREATE INDEX IF NOT EXISTS idx_livraisons_date ON public.livraisons(date);
CREATE INDEX IF NOT EXISTS idx_livraisons_livreur ON public.livraisons(livreur_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
