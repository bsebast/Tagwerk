# So arbeitest du mit Tagwerk (GitHub + Xcode)

Diese Anleitung ist für den Mac geschrieben und setzt keine Vorkenntnisse voraus.

## Das Prinzip in einem Satz

Der Code liegt auf GitHub. Claude ändert ihn dort, und du holst die Änderungen mit einem Klick in Xcode auf deinen Mac.

```
Du (Wunsch im Chat) → Claude (ändert Code, legt Pull Request an) → du (prüfst & „Merge“ auf GitHub) → Xcode „Pull“ → App testen
```

---

## Einmalig: Einrichtung (ca. 15 Minuten)

### 1. Xcode installieren
App Store öffnen → nach **Xcode** suchen → *Laden*. Das dauert eine Weile (ca. 10 GB).
Danach Xcode einmal starten und die Zusatzkomponenten installieren lassen (inkl. **iOS-Simulator**).

### 2. GitHub-Konto in Xcode hinterlegen
1. Xcode → Menü **Xcode → Settings…** (⌘,) → Reiter **Accounts**.
2. Unten links **+** → **GitHub** → *Continue*.
3. Benutzername `bsebast` und ein **Token** eintragen. Den Token erzeugst du so:
   github.com → Profilbild oben rechts → **Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token (classic)**.
   Haken bei **repo** setzen, Ablaufdatum wählen, *Generate* → Token kopieren und in Xcode einfügen.

### 3. Projekt auf den Mac holen („klonen“)
1. Xcode-Startfenster → **Clone Git Repository…**
   (oder Menü **Integrate → Clone…**)
2. Oben `tagwerk` suchen bzw. `https://github.com/bsebast/tagwerk.git` einfügen → **Clone**.
3. Speicherort wählen, z. B. *Dokumente/Entwicklung*. Xcode öffnet danach das Projekt.

### 4. App starten
1. Oben in der Mitte das Ziel **Tagwerk** und daneben einen Simulator wählen, z. B. *iPhone 16*.
2. **▶︎ (⌘R)** drücken. Der Simulator startet mit der App.

> Steht oben „Any iOS Device (arm64)“, kann Xcode die App nur bauen, nicht starten. Dann auf den Namen klicken und unter **iOS Simulators** ein Gerät wählen. Sind dort keine aufgelistet: **Xcode → Settings → Components** → bei *iOS* auf *Get* klicken.

**iPad testen:** Statt eines iPhones einfach einen iPad-Simulator wählen, z. B. *iPad Air 13-inch*. Dort erscheinen die Tags links in einer Seitenleiste. Im Simulator mit ⌘← / ⌘→ drehen.

**Auf deinem echten iPhone:**
1. iPhone per Kabel anschließen, „Diesem Computer vertrauen“ bestätigen.
2. In Xcode links ganz oben auf das blaue **Tagwerk**-Projekt klicken → Target **Tagwerk** → Reiter **Signing & Capabilities**.
3. Bei **Team** deine Apple-ID auswählen (ggf. *Add an Account…*). Falls ein Fehler zur Bundle-ID kommt: `de.tagwerk.app` z. B. in `de.bsebast.tagwerk` ändern.
4. Oben dein iPhone als Ziel wählen → ▶︎.
5. Beim ersten Mal auf dem iPhone: **Einstellungen → Allgemein → VPN & Geräteverwaltung** → deinem Entwicklerprofil vertrauen. Außerdem unter **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus** einschalten.

> Mit einer kostenlosen Apple-ID läuft die App 7 Tage, danach einfach erneut aus Xcode starten. Mit dem Apple Developer Program (99 €/Jahr) entfällt das, und du könntest TestFlight nutzen.

---

## Im Alltag: Änderungen bekommen

### Etwas ändern lassen
Schreib deinen Wunsch einfach in diesen Projekt-Chat, z. B.:
- „Füge Orts-Tags hinzu.“
- „Der Erledigt-Kreis soll größer sein.“
- „Beim Build kommt Fehler X“ → **Fehlermeldung kopieren** (in Xcode links im Fehler-Navigator ⚠︎, Rechtsklick → *Copy*) oder Screenshot schicken.

Claude legt dafür auf GitHub einen **Pull Request** (PR) an: einen Änderungsvorschlag, den du ansehen kannst.

### Änderung übernehmen
1. Link zum Pull Request öffnen → Reiter **Files changed** zeigt, was sich ändert (optional).
2. Grüner Button **Merge pull request** → **Confirm merge**. Jetzt ist die Änderung im Hauptzweig `main`.
3. In Xcode: Menü **Integrate → Pull…** (⌥⌘X) → **Pull**.
4. **⌘R** → die neue Version läuft.

> Alternative ohne Merge: Du kannst Claude auch sagen „Merge direkt“ – dann bestätigst du das einmal im Chat.

### Wenn du selbst etwas änderst
Du kannst Texte oder Farben auch direkt in Xcode anpassen. Danach:
**Integrate → Commit…** (⌥⌘C) → kurze Beschreibung → Haken bei **Push to remote** → *Commit*.
So landet deine Änderung auf GitHub und Claude arbeitet beim nächsten Wunsch mit deinem Stand weiter.

---

## Wo ist was?

| Ordner/Datei | Inhalt |
|---|---|
| `Tagwerk/Views/` | Alle Bildschirme (Liste, Editor, Tags, Einstellungen) |
| `Tagwerk/Models/` | Datenmodell: Aufgabe, Tag, Priorität, Wiederholung |
| `Tagwerk/Logic/` | Sortierung, Filter, Tag-Vorschläge, Erinnerungen |
| `Tagwerk/Support/` | Farben, Symbole, Start-Tags, Einstellungen |
| `Tagwerk/Assets.xcassets` | App-Icon und Akzentfarbe |
| `TagwerkTests/` | Automatische Tests (⌘U) |

## Hilfe bei Problemen

| Problem | Lösung |
|---|---|
| „Signing for Tagwerk requires a development team“ | Schritt *Auf deinem echten iPhone*, Punkt 2–3 |
| Pull schlägt fehl wegen lokaler Änderungen | **Integrate → Discard All Changes…** (verwirft deine lokalen Änderungen) oder vorher committen |
| Seltsame Build-Fehler nach einem Pull | Menü **Product → Clean Build Folder** (⇧⌘K), dann erneut ⌘R |
| Simulator fehlt | **Xcode → Settings → Components** → iOS-Plattform laden |
