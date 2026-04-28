// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BlockchainVoting
 * @author WI-Student Hochschule Reutlingen
 * @notice Prototyp eines dezentralen Wahlsystems mit Soulbound Token (SBT) als Wahlberechtigung.
 *
 * Hinweis zum Wahlgeheimnis:
 * Ohne Zero-Knowledge Proof ist die Verknüpfung zwischen Wallet und abgegebener Stimme
 * theoretisch rekonstruierbar. Dieser Prototyp demonstriert Transparenz und
 * Fälschungsschutz, nicht vollständige Anonymität.
 */
contract BlockchainVoting {

    // Repräsentiert einen Kandidaten
    struct Candidate {
        uint256 id;
        string  name;
        uint256 voteCount;
    }

    // Zustände der Wahl
    enum ElectionState {
        SETUP,   // Einrichtungsphase: Kandidaten und Wähler werden registriert
        ACTIVE,  // Stimmabgabe läuft
        CLOSED   // Wahl beendet
    }

    address public admin;
    string  public electionName;
    ElectionState public state;

    mapping(address => bool) public hasSBT;      // Wahlberechtigung
    mapping(address => bool) public hasVoted;    // Doppelwahl-Verhinderung
    mapping(uint256 => Candidate) public candidates;
    uint256 public candidateCount;
    uint256 public totalVotesCast;

    // Events werden dauerhaft auf der Blockchain gespeichert
    event SBTMinted(address indexed voter);
    event SBTRevoked(address indexed voter);
    event VoteCast(address indexed voter, uint256 indexed candidateId);
    event ElectionStateChanged(ElectionState newState);
    event CandidateAdded(uint256 indexed id, string name);

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

    constructor(string memory _electionName) {
        admin        = msg.sender;
        electionName = _electionName;
        state        = ElectionState.SETUP;
    }

    // Kandidat hinzufügen — nur in der Einrichtungsphase möglich
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

    // Wahlberechtigung an eine Wallet-Adresse vergeben
    function mintSBT(address _voter) external onlyAdmin {
        require(_voter != address(0), "Ungueltige Adresse.");
        require(!hasSBT[_voter],      "Waehler hat bereits einen SBT.");
        hasSBT[_voter] = true;
        emit SBTMinted(_voter);
    }

    // Wahlberechtigung entziehen (z.B. bei Fehler)
    function revokeSBT(address _voter) external onlyAdmin {
        require(hasSBT[_voter], "Waehler hat keinen SBT.");
        hasSBT[_voter] = false;
        emit SBTRevoked(_voter);
    }

    // Wahl starten
    function startElection()
        external
        onlyAdmin
        inState(ElectionState.SETUP)
    {
        require(candidateCount >= 2, "Mind. 2 Kandidaten erforderlich.");
        state = ElectionState.ACTIVE;
        emit ElectionStateChanged(ElectionState.ACTIVE);
    }

    // Wahl beenden
    function closeElection()
        external
        onlyAdmin
        inState(ElectionState.ACTIVE)
    {
        state = ElectionState.CLOSED;
        emit ElectionStateChanged(ElectionState.CLOSED);
    }

    // Stimme abgeben — prüft SBT, Doppelwahl und gültige Kandidaten-ID
    function castVote(uint256 _candidateId)
        external
        inState(ElectionState.ACTIVE)
        hasSoulboundToken
    {
        require(!hasVoted[msg.sender],          "Stimme wurde bereits abgegeben.");
        require(_candidateId >= 1 &&
                _candidateId <= candidateCount, "Ungueltige Kandidaten-ID.");

        hasVoted[msg.sender]                 = true;
        candidates[_candidateId].voteCount  += 1;
        totalVotesCast                      += 1;

        emit VoteCast(msg.sender, _candidateId);
    }

    // Ergebnis eines einzelnen Kandidaten abrufen
    // Prozentwert ist mit Faktor 100 skaliert (4250 = 42.50%)
    function getCandidateResult(uint256 _candidateId)
        external
        view
        returns (string memory name, uint256 voteCount, uint256 percentage)
    {
        require(_candidateId >= 1 && _candidateId <= candidateCount, "Ungueltige ID.");
        Candidate storage c = candidates[_candidateId];
        name       = c.name;
        voteCount  = c.voteCount;
        percentage = totalVotesCast > 0 ? (c.voteCount * 10000) / totalVotesCast : 0;
    }

    // Gewinner ermitteln — nur nach Wahlende aufrufbar
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
                maxVotes = candidates[i].voteCount;
                winnerId = i;
            }
        }
        winnerName  = candidates[winnerId].name;
        winnerVotes = candidates[winnerId].voteCount;
    }

    // Alle Kandidaten und Ergebnisse auf einmal abrufen
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

    // Aktuellen Status als lesbaren String zurückgeben
    function getElectionStatus() external view returns (string memory) {
        if (state == ElectionState.SETUP)   return "SETUP: Wahl wird vorbereitet";
        if (state == ElectionState.ACTIVE)  return "AKTIV: Stimmabgabe laeuft";
        return                                     "GESCHLOSSEN: Wahl beendet";
    }
}
