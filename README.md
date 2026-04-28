# Blockchain-Wahlsystem

Prototyp eines dezentralen Wahlsystems auf Basis von Ethereum (Solidity), entwickelt im Rahmen des Wahlmoduls "Einführung in Blockchain Technologie und Anwendungen" an der Hochschule Reutlingen.

---

## Projektübersicht

**Ziel:** Politische Wahlen auf der Blockchain abbilden, um Bürokratie zu reduzieren, Ergebnisse öffentlich verifizierbar zu machen und Wahlbetrug zu verhindern — bei gleichzeitiger Wahrung der allgemeinen Wahlrechtsgrundsätze.

**Anwendungsfall:** Ein Smart Contract verwaltet den gesamten Wahlprozess: Kandidatenverwaltung, Wählerregistrierung via Soulbound Token (SBT) und Stimmabgabe mit Doppelwahl-Verhinderung.

**Testnetz:** Ethereum Sepolia  
**Contract-Adresse:** `0x58e5551f2046Cec98677Ba8861164460fB456a8C`  
**Etherscan:** [sepolia.etherscan.io/address/0x58e5551f2046Cec98677Ba8861164460fB456a8C](https://sepolia.etherscan.io/address/0x58e5551f2046Cec98677Ba8861164460fB456a8C)

---

## Architektur

```
┌─────────────────────────────────────────────────────┐
│                   Browser (Wähler)                  │
│              index.html + ethers.js v6              │
└─────────────────────┬───────────────────────────────┘
                      │ JSON-RPC
                      ▼
┌─────────────────────────────────────────────────────┐
│                    MetaMask                         │
│         Wallet / Transaktions-Signierung            │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│           Ethereum Sepolia Testnetz                 │
│                                                     │
│   ┌─────────────────────────────────────────────┐  │
│   │         BlockchainVoting.sol                │  │
│   │                                             │  │
│   │  State Machine: SETUP → AKTIV → GESCHLOSSEN │  │
│   │  SBT-Mapping: hasSBT[address] → bool        │  │
│   │  Doppelwahl: hasVoted[address] → bool       │  │
│   │  Kandidaten: candidates[id]                 │  │
│   │  Events: VoteCast, ElectionStarted, ...     │  │
│   └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Wahlprozess

```
Admin                          Smart Contract                    Wähler
  │                                  │                             │
  │── addCandidate("SPD") ──────────>│                             │
  │── addCandidate("CDU") ──────────>│                             │
  │── mintSBT(walletAdresse) ───────>│                             │
  │── startElection() ──────────────>│                             │
  │                                  │<── castVote(candidateId) ───│
  │                                  │    (prüft SBT + Duplikat)   │
  │── closeElection() ──────────────>│                             │
  │                                  │<── getAllResults() ──────────│
```

---

## Smart Contract

**Datei:** `VotingContract.sol`  
**Sprache:** Solidity `^0.8.20`  
**Compiler:** Remix IDE

### State Machine

| Zustand | Beschreibung |
|---|---|
| `SETUP` | Admin fügt Kandidaten hinzu und registriert Wähler |
| `AKTIV` | Stimmabgabe läuft |
| `GESCHLOSSEN` | Wahl beendet, Ergebnis abrufbar |

### Wichtige Funktionen

| Funktion | Typ | Beschreibung |
|---|---|---|
| `addCandidate(string)` | Admin | Kandidat hinzufügen (nur in SETUP) |
| `mintSBT(address)` | Admin | Wähler registrieren (Soulbound Token) |
| `startElection()` | Admin | Wahl starten |
| `castVote(uint256)` | Wähler | Stimme abgeben (prüft SBT + Duplikat) |
| `closeElection()` | Admin | Wahl beenden |
| `getAllResults()` | public | Alle Ergebnisse abrufen |
| `getWinner()` | public | Gewinner abrufen |
| `getElectionStatus()` | public | Aktuellen Status abrufen |

### Soulbound Token (SBT)

Statt eines vollständigen ERC-721-Contracts wird ein einfaches `mapping(address => bool) hasSBT` verwendet. Das ist für den Prototyp ausreichend und gas-effizienter. Der Admin mintet SBTs manuell an registrierte Wähler-Wallets.

### On-Chain Events

Jede Stimme erzeugt einen unveränderlichen Log-Eintrag auf der Blockchain — das ist das Hauptargument für Transparenz:

```solidity
event VoteCast(address indexed voter, uint256 indexed candidateId);
event ElectionStarted(uint256 timestamp);
event ElectionClosed(uint256 timestamp);
```

---

## Bekannte Limitation: Wahlgeheimnis

**Problem:** Die Verknüpfung `Wallet-Adresse → Kandidat` ist auf der Blockchain öffentlich einsehbar. Ohne Zero-Knowledge Proof (ZKP) ist vollständige Anonymität nicht gewährleistet.

**Einordnung:** Dieser Prototyp demonstriert die Transparenz- und Fälschungsschutz-Eigenschaften der Blockchain, nicht vollständige Anonymität.

**Konzeptuelle Erweiterung (ZKP):** Mit Zero-Knowledge Proofs (z.B. Semaphore-Protokoll) könnte ein Wähler beweisen, dass er wahlberechtigt ist, ohne seine Identität preiszugeben. Die Stimme würde verschlüsselt on-chain gespeichert, sodass die Zuordnung Wallet → Kandidat nicht rekonstruierbar ist. Die Implementierung würde erfordern:
- ZK-Circuit (z.B. mit circom)
- On-Chain Verifier Contract
- Angepasstes Frontend mit Proof-Generierung

Dies übersteigt den Umfang dieses Hochschulprojekts, ist aber eine realistische Erweiterung der bestehenden Architektur.

---

## Tech Stack

| Komponente | Technologie |
|---|---|
| Smart Contract | Solidity 0.8.20 |
| Entwicklungsumgebung | Remix IDE |
| Wallet | MetaMask |
| Testnetz | Ethereum Sepolia (chainId 11155111) |
| Frontend | HTML/JS, ethers.js v6 (CDN) |
| Hosting | GitHub Pages |

---

## Deployment-Anleitung

### Voraussetzungen

- MetaMask installiert und auf **Sepolia Testnetz** eingestellt
- Sepolia-ETH auf dem Account (via [Faucet](https://sepoliafaucet.com))
- Remix IDE ([remix.ethereum.org](https://remix.ethereum.org))

### Schritt 1 — Contract deployen

1. `VotingContract.sol` in Remix öffnen
2. **Compiler:** Version `0.8.20`, Compile klicken
3. **Deploy & Run Transactions:**
   - Environment: `Injected Provider – MetaMask`
   - Netzwerk: Sepolia (11155111) prüfen
   - `_electionName`: Wahlname eintragen
   - **Deploy** klicken → MetaMask bestätigen
4. Contract-Adresse aus "Deployed Contracts" kopieren

### Schritt 2 — Wahl einrichten

In Remix unter "Deployed Contracts":

```
addCandidate → "SPD"
addCandidate → "CDU"
addCandidate → "Gruene"
mintSBT → <Wallet-Adresse des Wählers>
startElection
```

### Schritt 3 — Frontend konfigurieren

In `index.html` die Contract-Adresse eintragen:

```javascript
const CONTRACT_ADDRESS = "0x58e5551f2046Cec98677Ba8861164460fB456a8C";
```

### Schritt 4 — Frontend deployen (GitHub Pages)

1. `index.html` ins Repository pushen
2. Settings → Pages → Branch: `main` → Save
3. Seite erreichbar unter: `https://janroether.github.io/blockchain-voting`

---

## Projektstruktur

```
blockchain-voting/
├── index.html          # Frontend (Wähler-Interface, ethers.js v6)
├── VotingContract.sol  # Smart Contract (Solidity)
└── README.md           # Diese Dokumentation
```

---

## Warum Blockchain?

| Problem (klassisch) | Lösung (Blockchain) |
|---|---|
| Zentrale Wahlbehörde als Single Point of Trust | Dezentraler, trustloser Smart Contract |
| Nachträgliche Manipulation möglich | Unveränderliche Transaktionshistorie |
| Ergebnis nur durch Behörde verifizierbar | Jeder kann Ergebnis on-chain prüfen |
| Doppelwahl durch technische Kontrolle | Doppelwahl kryptografisch ausgeschlossen |

---

*Hochschulprojekt — Wirtschaftsinformatik, Hochschule Reutlingen*  
*Modul: Blockchain und Anwendungsfälle*
