#!/bin/bash
# Script de téléchargement automatique des sons pour Coinchette
# Sources: Pixabay, Freesound.org, OpenGameArt (CC0)

set -e  # Exit on error

SOUNDS_DIR="priv/static/sounds"
cd "$(dirname "$0")/.."  # Aller à la racine du projet

echo "🎵 Téléchargement des effets sonores pour Coinchette..."
echo "📁 Destination: $SOUNDS_DIR"
echo ""

mkdir -p "$SOUNDS_DIR"
cd "$SOUNDS_DIR"

# Fonction de téléchargement avec fallback
download_sound() {
    local name=$1
    local url=$2

    if [ -f "$name" ]; then
        echo "⏭️  $name existe déjà, skip"
        return 0
    fi

    echo "⬇️  Téléchargement: $name..."
    if curl -L -f -o "$name" "$url" 2>/dev/null; then
        echo "✅ $name téléchargé ($(du -h "$name" | cut -f1))"
    else
        echo "❌ Échec: $name (URL invalide ou protégée)"
        # Créer un placeholder silencieux minimal
        echo "   Création d'un placeholder..."
        create_placeholder "$name"
    fi
}

# Fonction pour créer un MP3 placeholder (silence 0.5s)
create_placeholder() {
    local name=$1
    # MP3 minimal valide (22050Hz, mono, 0.5s de silence)
    # En production, remplacer par de vrais sons
    base64 -d > "$name" << 'EOF'
//uQxAAAAAAAAAAAAAAAAAAAAAAAWGluZwAAAA8AAAACAAADhAC7u7u7u7u7u7u7u7u7u7u7u7u7
u7u7u7u7u7u7u7u7u7u7u7v///////////////////////8AAAAATGF2YzU4LjkxAAAAAAAAAAAA
AAAAJAAAAAAAAAAABIQfPvGRAAAAAAD/+0DEAAAH3AAAACBAAIABEnD/4QAAA8QAAAB4AAAAB//
AAAAA8QAAAB4AAAAB//AAAAA8QAAAB4AAAAB
EOF
    echo "   📦 Placeholder créé: $name (fichier test)"
}

echo "════════════════════════════════════════════════"
echo "Note: Certains CDN peuvent bloquer les téléchargements."
echo "Si échec, téléchargez manuellement depuis Pixabay.com"
echo "Voir: DOWNLOAD_SOUNDS.md pour les instructions"
echo "════════════════════════════════════════════════"
echo ""

# Tentative de téléchargement depuis URLs publiques
# Note: Ces URLs peuvent ne pas fonctionner (protection CDN)
# En cas d'échec, des placeholders seront créés

download_sound "card-play.mp3" "https://www.soundjay.com/card/sounds/card-flip-1.mp3"
download_sound "card-shuffle.mp3" "https://www.soundjay.com/card/sounds/card-shuffle-1.mp3"
download_sound "trick-win.mp3" "https://www.soundjay.com/button/sounds/beep-07.mp3"
download_sound "victory.mp3" "https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3"
download_sound "defeat.mp3" "https://www.soundjay.com/misc/sounds/fail-buzzer-01.mp3"
download_sound "belote.mp3" "https://www.soundjay.com/misc/sounds/bell-ringing-02.mp3"
download_sound "announcement.mp3" "https://www.soundjay.com/misc/sounds/bell-ringing-03.mp3"
download_sound "button-click.mp3" "https://www.soundjay.com/button/sounds/button-3.mp3"
download_sound "bid-take.mp3" "https://www.soundjay.com/button/sounds/beep-01.mp3"
download_sound "bid-pass.mp3" "https://www.soundjay.com/button/sounds/button-16.mp3"

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Processus terminé!"
echo ""
echo "📊 Fichiers téléchargés:"
ls -lh *.mp3 2>/dev/null || echo "Aucun fichier .mp3 trouvé"
echo ""
echo "🎯 Prochaines étapes:"
echo "   1. Vérifier les sons (ouvrir dans un lecteur audio)"
echo "   2. Remplacer les placeholders par de vrais sons si nécessaire"
echo "   3. Redémarrer le serveur Phoenix"
echo "   4. Tester dans le jeu: http://localhost:4000"
echo ""
echo "📚 Ressources gratuites:"
echo "   - Pixabay: https://pixabay.com/sound-effects/"
echo "   - Mixkit: https://mixkit.co/free-sound-effects/"
echo "   - Freesound: https://freesound.org/ (compte requis)"
echo "════════════════════════════════════════════════"
