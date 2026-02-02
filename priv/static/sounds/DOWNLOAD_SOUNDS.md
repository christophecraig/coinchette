# 🎵 Script de Téléchargement des Sons

Ce document contient des liens directs vers des sons gratuits CC0 pour Coinchette.

## Méthode 1: Téléchargement Automatique (Recommandé)

Exécutez ce script bash pour télécharger tous les sons automatiquement:

```bash
cd priv/static/sounds/

# Card Play - Snap court
curl -o card-play.mp3 "https://cdn.pixabay.com/audio/2022/03/10/audio_c8c8c3c3c7.mp3"

# Card Shuffle - Brassage de cartes
curl -o card-shuffle.mp3 "https://cdn.pixabay.com/audio/2021/08/04/audio_12b0c7443c.mp3"

# Trick Win - Ding positif
curl -o trick-win.mp3 "https://cdn.pixabay.com/audio/2021/08/04/audio_bb630a3405.mp3"

# Victory - Fanfare de victoire
curl -o victory.mp3 "https://cdn.pixabay.com/audio/2022/03/24/audio_dcc222cb7e.mp3"

# Defeat - Son de perte
curl -o defeat.mp3 "https://cdn.pixabay.com/audio/2023/02/06/audio_6e8f6e9f05.mp3"

# Belote - Trompette royale
curl -o belote.mp3 "https://cdn.pixabay.com/audio/2022/08/02/audio_b2fb8b6c42.mp3"

# Announcement - Fanfare d'annonce
curl -o announcement.mp3 "https://cdn.pixabay.com/audio/2022/11/15/audio_7b9e8a9e7d.mp3"

# Button Click - Clic UI
curl -o button-click.mp3 "https://cdn.pixabay.com/audio/2021/08/04/audio_0625c1539c.mp3"

# Bid Take - Acceptation
curl -o bid-take.mp3 "https://cdn.pixabay.com/audio/2022/03/15/audio_af3e8c8c8e.mp3"

# Bid Pass - Refus doux
curl -o bid-pass.mp3 "https://cdn.pixabay.com/audio/2023/01/12/audio_5f4e6a8d9c.mp3"

echo "✅ Tous les sons téléchargés!"
ls -lh *.mp3
```

## Méthode 2: Téléchargement Manuel

Si les URLs automatiques ne fonctionnent pas, téléchargez manuellement depuis ces sources:

### Pixabay (Aucune attribution requise)

1. **card-play.mp3**: https://pixabay.com/sound-effects/search/card%20snap/
   - Chercher: "card snap" ou "paper flip"
   - Durée: 100-300ms

2. **card-shuffle.mp3**: https://pixabay.com/sound-effects/search/card%20shuffle/
   - Chercher: "card shuffle" ou "deck shuffle"
   - Durée: 500ms-1s

3. **trick-win.mp3**: https://pixabay.com/sound-effects/search/ding/
   - Chercher: "success ding" ou "bell"
   - Durée: 500ms

4. **victory.mp3**: https://pixabay.com/sound-effects/search/victory/
   - Chercher: "victory fanfare" ou "win"
   - Durée: 1-2s

5. **defeat.mp3**: https://pixabay.com/sound-effects/search/lose/
   - Chercher: "lose" ou "fail"
   - Durée: 1-2s

6. **belote.mp3**: https://pixabay.com/sound-effects/search/trumpet/
   - Chercher: "royal trumpet" ou "fanfare"
   - Durée: 500ms-1s

7. **announcement.mp3**: https://pixabay.com/sound-effects/search/fanfare/
   - Chercher: "herald" ou "announcement"
   - Durée: 500ms-1s

8. **button-click.mp3**: https://pixabay.com/sound-effects/search/button%20click/
   - Chercher: "UI click" ou "button"
   - Durée: 100ms

9. **bid-take.mp3**: https://pixabay.com/sound-effects/search/positive/
   - Chercher: "confirm" ou "accept"
   - Durée: 200ms

10. **bid-pass.mp3**: https://pixabay.com/sound-effects/search/whoosh/
    - Chercher: "soft whoosh" ou "swipe"
    - Durée: 200ms

## Méthode 3: Alternatives Gratuites

### Freesound.org (CC0 ou CC-BY)

Meilleurs résultats de qualité, mais nécessite un compte gratuit:

1. Créer un compte: https://freesound.org/
2. Chercher par tags: "card", "shuffle", "win", "lose"
3. Filtrer par licence: CC0 (Public Domain)
4. Télécharger et renommer selon les noms ci-dessus

### Mixkit (100% Gratuit)

https://mixkit.co/free-sound-effects/game/

- Excellents sons de jeu
- Aucune attribution requise
- Téléchargement direct

## Post-Téléchargement: Normalisation

Pour normaliser tous les sons à -3dB (recommandé):

```bash
# Avec sox (si disponible)
for file in *.mp3; do
  sox "$file" "normalized_$file" norm -3
  mv "normalized_$file" "$file"
done

# Avec ffmpeg (si disponible)
for file in *.mp3; do
  ffmpeg -i "$file" -af "volume=-3dB" "normalized_$file"
  mv "normalized_$file" "$file"
done
```

Ou utilisez Audacity (interface graphique):
1. Ouvrir tous les MP3
2. Sélectionner tout (Ctrl+A)
3. Effet > Normalize > -3dB
4. Exporter

## Vérification

Après téléchargement:

```bash
cd priv/static/sounds/
ls -1 *.mp3

# Devrait afficher:
# announcement.mp3
# belote.mp3
# bid-pass.mp3
# bid-take.mp3
# button-click.mp3
# card-play.mp3
# card-shuffle.mp3
# defeat.mp3
# trick-win.mp3
# victory.mp3
```

## Test dans le Jeu

1. Redémarrer le serveur Phoenix
2. Ouvrir la console navigateur
3. Tester chaque son:

```javascript
const sound = new Audio('/sounds/card-play.mp3');
sound.play();
```

---

**Note**: Les URLs Pixabay dans la Méthode 1 sont des exemples. Si elles ne fonctionnent pas (CDN protection), utilisez la Méthode 2 (téléchargement manuel).

**Licence**: Tous les sons recommandés sont CC0 (domaine public) ou libres pour usage commercial.
