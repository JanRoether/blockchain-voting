// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BlockchainVoting
 * @author WI-Student Hochschule Reutlingen
 * @notice Prototyp: Dezentrale Wahl mit Soulbound Token (SBT) als Wahlberechtigung
 *
 * ARCHITEKTUR-ÜBERBLICK:
 * ┌─────────────────────────────────────────────────────────────┐
 * │  1. Admin registriert Wähler  → SBT wird gemintet           │
 * │  2. Wähler gibt Stimme ab     → Contract prüft SBT + Duplikat│
 * │  3. Jeder kann Ergebnis lesen → Transparenz on-chain        │
 * └─────────────────────────────────────────────────────────────┘
 *
 * BEKANNTE LIMITATION (Wahlgeheimnis):
 * Ohne Zero-Knowledge Proof ist die Verknüpfung Wallet ↔ Stimme
 * theoretisch rekonstruierbar. Dieser Prototyp demonstriert die
 * Transparenz- und Fälschungsschutz-Eigenschaften, nicht die
 * vollständige Anonymität. Siehe Dokumentation Abschnitt "Ausblick ZKP".
 */
contract BlockchainVoting {

    // =========================================================
    // TYPEN & STRUKTUREN
    // =========================================================

    /// @notice Repräsentiert einen Kandidaten auf dem Stimmzettel
    struct Candidate {
        uint256 id;
        string  name;
        uint256 voteCount;
    }

    /// @notice Mögliche Zustände der Wahl (State Machine)
    enum ElectionState {
        SETUP,      // Admin richtet Wahl ein, keine Stimmabgabe möglich
        ACTIVE,     // Stimmabgabe läuft
        CLOSED      // Wahl beendet, nur noch Ergebnisabruf möglich
    }

    // =========================================================
    // ZUSTANDSVARIABLEN
    // =========================================================

    address public admin;
    string  public electionName;
    ElectionState public state;

    // SBT-Tracking: Wallet → hat einen Wahlberechtigungstoken
    mapping(address => bool) public hasSBT;

    // Verhindert Doppelwahl: Wallet → hat bereits gewählt
    mapping(address => bool) public hasVoted;

    // Kandidaten: ID (1-basiert) → Candidate-Struct
    mapping(uint256 => Candidate) public candidates;
    uint256 public candidateCount;

    // Gesamte abgegebene Stimmen (für Auswertung / Wahlbeteiligung)
    uint256 public totalVotesCast;

    // =========================================================
    // EVENTS (werden in der Blockchain gespeichert und sind
    //         extern abrufbar — wichtig für Transparenz-Nachweis)
    // =========================================================

    event SBTMinted(address indexed voter);
    event SBTRevoked(address indexed voter);
    event VoteCast(address indexed voter, uint256 indexed candidateId);
    event ElectionStateChanged(ElectionState newState);
    event CandidateAdded(uint256 indexed id, string name);

    // =========================================================
    // MODIFIER (Zugriffskontrolle & Zustandsvalidierung)
    // =========================================================

    modifier onlyAdmin() {
        require(msg.sender == admin, "Nur der Admin darf das.");
        _;
    }

    modifier inState(ElectionState _state) {
        require(state == _state, "Aktion im aktuellen Wahlzustand nicht erlaubt.");
        _;
    }

    modifier hasSoulboundToken() {
        require(hasSBT[msg.sender], "Keine Wahlberechtigung (kein SBT).");
        _;
    }

    // =========================================================
    // KONSTRUKTOR
    // =========================================================

    /**
     * @param _electionName Name der Wahl, z.B. "Bundestagswahl 2025 - Simulaton"
     */
    constructor(string memory _electionName) {
        admin        = msg.sender;
        electionName = _electionName;
        state        = ElectionState.SETUP;
    }

    // =========================================================
    // ADMIN-FUNKTIONEN: SETUP-PHASE
    // =========================================================

    /**
     * @notice Kandidaten können nur im SETUP-Zustand hinzugefügt werden.
     * @param _name Name des Kandidaten / der Partei
     */
    function addCandidate(string memory _name)
        external
        onlyAdmin
        inState(ElectionState.SETUP)
    {
        candidateCount++;
        candidates[candidateCount] = Candidate({
            id:        candidateCount,
            name:      _name,
            voteCount: 0
        });
        emit CandidateAdded(candidateCount, _name);
    }

    /**
     * @notice Mintet einen Soulbound Token an eine verifizierte Wallet.
     *         Außerhalb dieses Prototyps würde hier eine Identitätsprüfung
     *         (z.B. via Ausweis-Oracle oder verifiable Credential) stattfinden.
     * @param _voter Wallet-Adresse des wahlberechtigten Bürgers
     */
    function mintSBT(address _voter)
        external
        onlyAdmin
    {
        require(_voter != address(0),  "Ungueltige Adresse.");
        require(!hasSBT[_voter],       "Waehler hat bereits einen SBT.");
        hasSBT[_voter] = true;
        emit SBTMinted(_voter);
    }

    /**
     * @notice Entzieht einem Wähler die Berechtigung (z.B. bei Tod oder Fehler).
     *         Bereits abgegebene Stimmen bleiben gültig (unveränderlich).
     */
    function revokeSBT(address _voter)
        external
        onlyAdmin
    {
        require(hasSBT[_voter], "Waehler hat keinen SBT.");
        hasSBT[_voter] = false;
        emit SBTRevoked(_voter);
    }

    // =========================================================
    // ADMIN-FUNKTIONEN: ZUSTANDSSTEUERUNG
    // =========================================================

    /// @notice Öffnet die Wahl — ab jetzt können Stimmen abgegeben werden.
    function startElection()
        external
        onlyAdmin
        inState(ElectionState.SETUP)
    {
        require(candidateCount >= 2, "Mind. 2 Kandidaten erforderlich.");
        state = ElectionState.ACTIVE;
        emit ElectionStateChanged(ElectionState.ACTIVE);
    }

    /// @notice Schließt die Wahl — keine weiteren Stimmen möglich.
    function closeElection()
        external
        onlyAdmin
        inState(ElectionState.ACTIVE)
    {
        state = ElectionState.CLOSED;
        emit ElectionStateChanged(ElectionState.CLOSED);
    }

    // =========================================================
    // WÄHLER-FUNKTION: STIMMABGABE
    // =========================================================

    /**
     * @notice Gibt eine Stimme für einen Kandidaten ab.
     *
     * Prüfkette (wird in dieser Reihenfolge validiert):
     *   1. Wahl ist aktiv
     *   2. Wähler besitzt einen SBT (ist wahlberechtigt)
     *   3. Wähler hat noch nicht gewählt (kein Doppelwahl)
     *   4. Kandidaten-ID ist gültig
     *
     * @param _candidateId ID des gewählten Kandidaten (1-basiert)
     */
    function castVote(uint256 _candidateId)
        external
        inState(ElectionState.ACTIVE)
        hasSoulboundToken
    {
        require(!hasVoted[msg.sender],               "Stimme wurde bereits abgegeben.");
        require(_candidateId >= 1 &&
                _candidateId <= candidateCount,      "Ungueltige Kandidaten-ID.");

        hasVoted[msg.sender]                  = true;
        candidates[_candidateId].voteCount   += 1;
        totalVotesCast                       += 1;

        // HINWEIS ZUM WAHLGEHEIMNIS:
        // Das Event verknüpft msg.sender mit _candidateId — on-chain nachvollziehbar.
        // In einer produktiven Lösung würde hier ein ZKP die Anonymität sicherstellen.
        emit VoteCast(msg.sender, _candidateId);
    }

    // =========================================================
    // LESEFUNKTIONEN: ERGEBNISSE (öffentlich, kein Gas-Verbrauch)
    // =========================================================

    /**
     * @notice Gibt den Stimmanteil eines einzelnen Kandidaten zurück.
     * @return name       Name des Kandidaten
     * @return voteCount  Absolute Stimmanzahl
     * @return percentage Prozentualer Anteil (skaliert mit 100 für 2 Dezimalstellen,
     *                    d.h. 4250 = 42.50%)
     */
    function getCandidateResult(uint256 _candidateId)
        external
        view
        returns (string memory name, uint256 voteCount, uint256 percentage)
    {
        require(_candidateId >= 1 && _candidateId <= candidateCount, "Ungueltige ID.");
        Candidate storage c = candidates[_candidateId];
        name      = c.name;
        voteCount = c.voteCount;
        percentage = totalVotesCast > 0
            ? (c.voteCount * 10000) / totalVotesCast
            : 0;
    }

    /**
     * @notice Gibt die ID des Gewinners zurück (Kandidat mit den meisten Stimmen).
     *         Nur nach Wahlende aufrufbar.
     * @dev Bei Stimmengleichheit gewinnt der Kandidat mit der niedrigeren ID.
     *      Für echte Wahlen müsste ein Stichwahl-Mechanismus implementiert werden.
     */
    function getWinner()
        external
        view
        inState(ElectionState.CLOSED)
        returns (uint256 winnerId, string memory winnerName, uint256 winnerVotes)
    {
        require(totalVotesCast > 0, "Keine Stimmen abgegeben.");

        uint256 maxVotes = 0;
        for (uint256 i = 1; i <= candidateCount; i++) {
            if (candidates[i].voteCount > maxVotes) {
                maxVotes  = candidates[i].voteCount;
                winnerId  = i;
            }
        }
        winnerName  = candidates[winnerId].name;
        winnerVotes = candidates[winnerId].voteCount;
    }

    /**
     * @notice Vollständige Ergebnisübersicht — alle Kandidaten auf einmal.
     *         Praktisch für eine Frontend-Integration.
     */
    function getAllResults()
        external
        view
        returns (
            uint256[] memory ids,
            string[]  memory names,
            uint256[] memory voteCounts
        )
    {
        ids        = new uint256[](candidateCount);
        names      = new string[](candidateCount);
        voteCounts = new uint256[](candidateCount);

        for (uint256 i = 1; i <= candidateCount; i++) {
            ids[i-1]        = candidates[i].id;
            names[i-1]      = candidates[i].name;
            voteCounts[i-1] = candidates[i].voteCount;
        }
    }

    // =========================================================
    // HILFSFUNKTIONEN
    // =========================================================

    /**
     * @notice Gibt den aktuellen Zustand der Wahl als lesbaren String zurück.
     *         Nützlich für Frontend-Anzeige.
     */
    function getElectionStatus()
        external
        view
        returns (string memory)
    {
        if (state == ElectionState.SETUP)   return "SETUP: Wahl wird vorbereitet";
        if (state == ElectionState.ACTIVE)  return "AKTIV: Stimmabgabe laeuft";
        return                                     "GESCHLOSSEN: Wahl beendet";
    }
}
