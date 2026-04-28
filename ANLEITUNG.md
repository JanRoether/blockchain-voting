# Ausführungsanleitung — Blockchain-Wahlsystem

Diese Anleitung beschreibt den vollständigen Ablauf: von der Einrichtung bis zur live laufenden Wahl auf GitHub Pages.

---

## Voraussetzungen

- Google Chrome (empfohlen)
- [MetaMask](https://metamask.io) Browser-Extension installiert
- Account auf [GitHub](https://github.com) und [Remix IDE](https://remix.ethereum.org)
- Sepolia-ETH (kostenlos via Faucet, siehe unten)

---

## Schritt 1 — MetaMask einrichten

1. MetaMask öffnen → oben auf den Netzwerknamen klicken
2. **Sepolia Test Network** auswählen
   - Falls nicht sichtbar: Einstellungen → Erweitert → Testnetzwerke anzeigen aktivieren
3. Wallet-Adresse kopieren (oben in MetaMask, Format `0x...`)

**Sepolia-ETH besorgen (kostenlos):**
- [sepoliafaucet.com](https://sepoliafaucet.com) aufrufen
- Wallet-Adresse eingeben → ETH anfordern
- Nach ~1 Minute erscheint das Guthaben in MetaMask

---

## Schritt 2 — Smart Contract in Remix deployen

1. [remix.ethereum.org](https://remix.ethereum.org) öffnen
2. Neue Datei anlegen: `VotingContract.sol`
3. Den Solidity-Code aus dem Repository (`contracts/VotingContract.sol`) einkopieren
4. Links auf **Solidity Compiler** klicken → Version `0.8.20` wählen → **Compile** klicken

**Deployen:**

1. Links auf **Deploy & Run Transactions** klicken
2. Environment: **Injected Provider – MetaMask** auswählen
3. MetaMask bestätigt die Verbindung → Netzwerk muss **Sepolia (11155111)** zeigen
4. Unter `_electionName` den Wahlnamen eingeben, z.B.:
   ```
   Bundestagswahl Simulation 2025
   ```
5. **Deploy** klicken → MetaMask-Popup bestätigen
6. Nach ~15 Sekunden erscheint der Contract unter **Deployed Contracts**
7. Contract-Adresse kopieren (kleines Kopiersymbol neben `BLOCKCHAINVOTING AT 0x...`)

---

## Schritt 3 — Wahl einrichten (Admin-Funktionen in Remix)

Den Contract unter **Deployed Contracts** aufklappen und folgende Funktionen der Reihe nach ausführen. Nach jeder Transaktion MetaMask bestätigen und warten bis der grüne Haken erscheint.

### Kandidaten hinzufügen

`addCandidate` → Namen eingeben → Button klicken (mehrfach wiederholen):

```
addCandidate → "SPD"
addCandidate → "CDU"
addCandidate → "Gruene"
```

### Wähler registrieren

`mintSBT` → Wallet-Adresse des Wählers eingeben (eigene Adresse aus MetaMask):

```
mintSBT → 0xDEINE_WALLET_ADRESSE
```

### Wahl starten

```
startElection → klicken → MetaMask bestätigen
```

Kontrolle: `getElectionStatus` aufrufen → muss `"AKTIV: Stimmabgabe laeuft"` zurückgeben.

---

## Schritt 4 — Frontend konfigurieren

1. `index.html` aus dem Repository öffnen (im Editor oder direkt auf GitHub)
2. Die Contract-Adresse eintragen:

```javascript
const CONTRACT_ADDRESS = "0xDEINE_CONTRACT_ADRESSE";
```

3. Datei speichern

---

## Schritt 5 — GitHub Pages einrichten

1. Neues Repository auf GitHub anlegen (Public)
2. `index.html`, `VotingContract.sol` (im Ordner `contracts/`) und `README.md` hochladen
3. Im Repository: **Settings → Pages → Branch: main → Save**
4. Nach ~1 Minute ist die Seite live unter:

```
https://DEIN-USERNAME.github.io/REPO-NAME
```

---

## Schritt 6 — Abstimmen über das Frontend

1. GitHub Pages URL im Browser öffnen
2. In MetaMask sicherstellen dass **Sepolia** aktiv ist und die korrekte Wallet ausgewählt ist
3. **"Wallet verbinden"** klicken → MetaMask bestätigen
4. Kandidaten werden geladen — grünes `✓ SBT` Badge muss erscheinen
5. Kandidaten auswählen → **Abstimmen** → MetaMask bestätigen
6. Nach Bestätigung aktualisieren sich die Balken automatisch

---

## Schritt 7 — Wahl beenden (optional)

In Remix unter Deployed Contracts:

```
closeElection → klicken → MetaMask bestätigen
```

Danach zeigt das Frontend den Gewinner mit Trophäen-Symbol.

---

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| "Bitte zu Sepolia wechseln" | In MetaMask das Netzwerk auf Sepolia umstellen, dann Seite neu laden und Wallet neu verbinden |
| Kein SBT Badge | Admin muss `mintSBT` mit der eigenen Wallet-Adresse in Remix ausführen |
| MetaMask öffnet sich nicht | Unten in MetaMask bei der Website das Netzwerk auf Sepolia umstellen |
| Transaktion schlägt fehl | Sepolia-ETH-Guthaben prüfen, ggf. neues ETH via Faucet holen |
| Contract nicht sichtbar | Seite neu laden, Wallet neu verbinden |

---

## Übersicht der verwendeten Adressen

| Bezeichnung | Adresse |
|---|---|
| Contract (Sepolia) | `0x58e5551f2046Cec98677Ba8861164460fB456a8C` |
| Admin-Wallet | `0xafbe12DfF64Cb60C800096449b93B928ba14FAF3` |
| Etherscan | [sepolia.etherscan.io/address/0x58e5551f2046Cec98677Ba8861164460fB456a8C](https://sepolia.etherscan.io/address/0x58e5551f2046Cec98677Ba8861164460fB456a8C) |
