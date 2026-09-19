OK, ich möchte es gerne versuchen, ein minimales Mod. Die Logik soll dies sein: NPC's nähern sich dem Player. 
Das kann 1.) entweder eine Anäherung sein, die mit Baka's BackHug/FrontHug Animationen beginnt (ich glaube, dass sind unabhängige Resourcen von Baka, die benutzt werden dürfen). 
Während die Animation läuft, passiert ein "Struggle" Minigame (ich glaube dafür kann die modders resource/mod "Flash Games - Struggling QTE" verwendet werden). 
Falls der Spieler verliert, kommt es zu einer Sex Szene. 
Die 2.) Möglickkeit ist, dass der NPC den Spieler in einen Dialog verwickelt, und den Spieler nach "Sex" fragt. 
Falls der Spieler ablehnt, kann der NPC dem Spieler Geld bieten, oder es kommt zu dem "Struggle Mini Game", oder es kann gar nichts passieren. 
Falls der Spieler das Geld Angebot ablehnt, kann ebenfalls gar nichts oder das "Struggle Game" passieren. 
Die Chancen für die jeweiligen Fälle können über eine .ini/.json konfiguriert werden (erstmal keine GUI dafür nötig). 
Kannst du einen Plan dafür erstellen ?  




Ja. Ein minimales, eigenständiges Mod lässt sich dafür sauber planen, ohne Baka’s Dialogtexte zu übernehmen.

**Zielarchitektur**

1. **NPC-Auswahl**
   - NPCs werden in Reichweite des Players geprüft.
   - Ausschluss: Kinder, Kreaturen, Händler/Quest-NPCs optional, bereits laufende Szenen, Begleiter optional.
   - Nur erwachsene Actors mit gültiger SexLab-Unterstützung.
   - Cooldown pro NPC und globaler Cooldown gegen Spam.

2. **Zwei Ereignistypen**

   **A. Körperliche Annäherung**
   - NPC nähert sich von vorne oder hinten.
   - Start einer vorhandenen, separat erlaubten Hug-Animation.
   - Währenddessen startet das Struggle-QTE.
   - QTE-Ergebnis:
     - Player gewinnt: Animation endet, NPC-Reaktion, Cooldown.
     - Player verliert: SexLab-Szene startet.
     - Abbruch/Timeout: Animation wird sauber beendet.

   **B. Dialog-Anbahnung**
   - NPC startet einen eigenen Dialogbaum.
   - NPC fragt den Player nach Sex.
   - Player-Antworten:
     - Zustimmung: SexLab-Szene.
     - Ablehnung: zufällige Folgeentscheidung:
       - Geldangebot
       - Struggle-QTE
       - Ende ohne weitere Aktion
   - Geldangebot:
     - Player akzeptiert: NPC zahlt, danach SexLab-Szene.
     - Player lehnt ab: zufällig Struggle-QTE oder Ende.
     - NPC-Geld wird vor Annahme geprüft.

3. **Zentraler Zustandsautomat**

```text
Idle
  -> CandidateFound
  -> Approaching
  -> HugOrDialogue
  -> PlayerResponse
  -> MoneyOffer
  -> StruggleQTE
  -> SexScene
  -> SuccessOrEscape
  -> Cooldown
```

Alle Übergänge laufen über eine zentrale Quest-/Managerlogik. Dadurch gibt es keine verstreuten Flags wie im alten Mod.

**Konfiguration**

Eine einfache INI wäre für Skyrim/Papyrus am passendsten:

```ini
[General]
Enabled=true
GlobalCooldown=180
NpcCooldown=600
DetectionDistance=700.0
AllowFollowers=false
AllowGuards=true

[Chances]
PhysicalApproach=35
DialogueApproach=65
MoneyAfterRejection=35
StruggleAfterMoneyReject=50
StruggleAfterSexReject=30

[Struggle]
Enabled=true
LoseStartsSex=true
TimeoutResult=escape

[Sex]
AllowMaleNpc=true
AllowFemaleNpc=true
AllowSameSex=true
AllowCreatures=false
```

JSON wäre möglich, aber INI ist für Papyrus einfacher und robuster. Die Prozentwerte sollten beim Laden validiert und auf $0$ bis $100$ begrenzt werden.

**Technische Module**

- `MinimalApproachQuest.psc`: Quest-Lebenszyklus und Zustände
- `MinimalApproachManager.psc`: NPC-Auswahl, Chancen, Cooldowns
- `MinimalApproachScene.psc`: Hug-/SexLab-Szenen
- `MinimalApproachDialogue.psc`: Dialogzustand und Antworten
- `MinimalApproachStruggle.psc`: Schnittstelle zum QTE
- `MinimalApproachConfig.psc`: INI-Laden und Validierung
- eigene Quest-Aliase für Player und aktuellen NPC

**Wichtige Abhängigkeiten**

- Skyrim SE/AE
- SKSE
- SexLab Framework
- eine erlaubte Hug-/Front-Hug-Animationsressource
- `Flash Games - Struggling QTE`, sofern es eine öffentliche Modder-API oder dokumentierte Events bereitstellt

Die Animationen dürfen nicht einfach aus Baka’s Mod kopiert werden. Vor der Implementierung müsste geprüft werden, ob die Animationen separat installiert werden und welche Nutzungsbedingungen gelten. Dasselbe gilt für die QTE-Ressource: Wir sollten deren öffentliche Schnittstelle verwenden, nicht deren Skripte kopieren.

**Entwicklungsreihenfolge**

1. Minimaler Manager mit einem NPC und Debug-Ausgaben.
2. SexLab-Szene nach einem festen Testdialog.
3. Dialogpfad mit Zustimmung/Ablehnung.
4. INI-Konfiguration und Wahrscheinlichkeiten.
5. Hug-Animation als eigener Ereignistyp.
6. QTE-Anbindung.
7. Geldangebot und Zahlungsprüfung.
8. Cooldowns, Ausschlüsse und Abbruchbehandlung.
9. Tests mit Save/Load, Zellwechsel, Kampf, Dialogabbruch und laufenden SexLab-Szenen.

Für die erste Version würde ich nur erwachsene humanoide NPCs, einen festen Dialogbaum, eine Hug-Animation, ein QTE und eine SexLab-Szene implementieren. Erst wenn dieser Kern stabil ist, sollten die vielen Varianten und Wahrscheinlichkeiten hinzukommen.


