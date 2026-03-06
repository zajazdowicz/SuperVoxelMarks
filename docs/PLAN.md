# SuperVoxelMarks - Plan Rozwoju

## Faza 1: Core Game (CURRENT)

### Gotowe
- [x] Track editor z toolbar UI, eraser, snap system
- [x] Segmenty: Prosta, Zakret, Rampa, Szykana, Boost, Checkpoint, Lod, Ziemia
- [x] Smooth rampy (ConvexPolygonShape3D) ze stackowaniem wysokosci
- [x] Fizyka pojazdu: acceleration, drift, boost, surface-based grip/friction
- [x] System wyscigu: timer okrazen (2 min limit), checkpointy, ghost recording, best lap time
- [x] Eksplozja auta na off-track + respawn z grace period
- [x] HUD: czas okrazenia, remaining time, predkosc, lista okrazen
- [x] Menu: wybor trasy, nick gracza, flaga (257 SVG z Neon Patrol)
- [x] PlayerData autoload (nick, flaga, zapis lokalny)
- [x] Git repo: github.com/zajazdowicz/SuperVoxelMarks

### Do zrobienia
- [ ] Fix: przetestowac system okrazen w grze (F5)
- [ ] Ghost replay playback (nagrywanie dziala)
- [ ] Daily track z serwera (pula predefiniowanych tras)

## Faza 2: Backend + Online

### Backend (Symfony na seohost.pl)
Adaptacja z Neon Patrol (`~/moonPatrol_backend/`):
- [ ] Nowa baza danych: `srv101355_voxelmarks`
- [ ] Nowy routing prefix: `/api/voxel/` (obok istniejacego `/api/` dla Neon Patrol)
- [ ] Encje (adaptacja): Player, LeaderboardEntry, GhostData, DailySeed, TrackData
- [ ] Nowa encja `TrackData`: przechowuje JSON trasy na serwerze (tworzone przez deva)
- [ ] Endpoint `/api/voxel/daily-track` - zwraca JSON trasy dnia
- [ ] Endpoint `/api/voxel/score` - upload best lap time + ghost
- [ ] Endpoint `/api/voxel/leaderboard/{track_id}` - top czasy
- [ ] Endpoint `/api/voxel/player/{id}/stats` - statystyki gracza
- [ ] Endpoint `/api/voxel/rankings/top` - globalny ranking

### Klient Godot (online)
- [ ] `api_client.gd` - autoload, HTTPRequest z retry + queue (wzor z Neon Patrol)
- [ ] Fetch daily track JSON z serwera → budowanie toru w race scene
- [ ] Upload best lap time + ghost po zakonczeniu wyscigu
- [ ] Leaderboard modal (dzisiejszy track + globalny)
- [ ] Player stats modal (total runs, best times, rankingi)
- [ ] Offline mode fallback (gra bez internetu na trasach lokalnych)

## Faza 3: Track Builder v2

### Nowe segmenty
- [ ] Wall Ride (pochylona/pionowa sciana z droga) - zmiana grawitacji
- [ ] Loop (petla 360) - zmiana grawitacji na gorze
- [ ] Tunel (zamkniety z sufitem)
- [ ] Mostek (nad inna czescia trasy)
- [ ] Zakret pochylony (banked turn)

### Edytor v2
- [ ] Community tracks: upload tras na serwer
- [ ] Serwer wybiera najlepsze trasy jako daily
- [ ] Track validation (czy trasa jest przejezdna, czy ma start/meta)
- [ ] Track preview/thumbnail

## Faza 4: Polish + Mobile

### Grafika
- [ ] Lepsze modele auta (voxelowe, nie BoxMesh)
- [ ] Particle effects: kurz, iskry, boost flame
- [ ] Skybox / lepsze tlo
- [ ] Cienie, ambient occlusion

### Audio
- [ ] Dzwiek silnika
- [ ] Muzyka menu + in-game
- [ ] SFX: boost, checkpoint, eksplozja, finish

### Mobile
- [ ] Touch controls (steering, gas/brake)
- [ ] Android export z godot_voxel
- [ ] Google Play listing
- [ ] Performance optimization dla mobile GPU

## Faza 5: Social + Monetization

### Social
- [ ] Ghost race vs najlepszy czas (widoczne auto-duch)
- [ ] Daily challenge notification
- [ ] Share wynik (screenshot/link)

### Monetization (opcjonalnie)
- [ ] Skiny aut (kolorystyka, czapki, flagi na aucie)
- [ ] Qdos (waluta w grze) za wyniki
- [ ] Shop z customizacja
- [ ] Buy me a coffee / wsparcie

## Faza C: Proceduralne tory (przyszlosc)
- [ ] Generator proceduralny z seeda (losowe segmenty)
- [ ] Walidacja: czy trasa jest przejezdna
- [ ] Seed synchronizowany z serwera (daily challenge)

---

## Architektura daily track

### Flow:
1. Dev buduje trasy w edytorze → zapisuje JSON
2. Dev uploaduje JSON tras na serwer (admin endpoint)
3. Serwer codziennie o 03:00 UTC wybiera losowa trase z puli
4. Klient przy starcie gry: GET /api/voxel/daily-track → pobiera JSON
5. Klient buduje tor z JSON (tak jak track_loader.gd)
6. Gracz jedzie okrazenia przez 2 minuty
7. Best lap time + ghost uploadowany na serwer
8. Leaderboard pokazuje najlepsze czasy wszystkich graczy na dzisiejszy track

### Daily track JSON format:
```json
{
  "id": "track_001",
  "name": "Serpentyna",
  "author": "Lukasz",
  "pieces": [
    {"gx": 0, "gz": 0, "piece": 5, "rotation": 0, "bh": 0},
    {"gx": 1, "gz": 0, "piece": 0, "rotation": 0, "bh": 0},
    ...
  ]
}
```

---

*Ostatnia aktualizacja: 2026-03-06*
