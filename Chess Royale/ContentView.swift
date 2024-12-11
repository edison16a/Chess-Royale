import SwiftUI

struct ShowDescriptionActionKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var showDescriptionAction: (String) -> Void {
        get { self[ShowDescriptionActionKey.self] }
        set { self[ShowDescriptionActionKey.self] = newValue }
    }
}

struct ContentView: View {
    // ADDED: GameMode enum for main menu and other modes
    enum GameMode {
        case menu
        case singleplayer
        case multiplayer
        case catalog
    }

    // MARK: - Enums and Structs
    
    enum Player: String {
        case playerOne, playerTwo
        
        var color: PieceColor {
            return self == .playerOne ? .white : .black
        }
        
        var opposite: Player {
            return self == .playerOne ? .playerTwo : .playerOne
        }
    }
    
    enum PieceType: String {
        case pawn, rook, knight, bishop, queen, king
    }
    
    enum PieceColor: String {
        case white, black
    }
    
    struct ChessPiece: Identifiable {
        let id = UUID()
        let type: PieceType
        let color: PieceColor
    }
    
    struct Position: Equatable {
        let row: Int
        let col: Int
    }
    
    struct PowerUp {
        let name: String
        let description: String
        let rarity: String // "Rare", "Epic", "Legendary", "Exotic"
        var cooldown: Int
        var isActive: Bool = true
    }
    
    // MARK: - Game State
    
    @State private var board: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var currentPlayer: Player = .playerOne
    @State private var selectedPosition: Position? = nil
    @State private var possibleMoves: [Position] = []
    
    @State private var playerOneRollsLeft = 5
    @State private var playerTwoRollsLeft = 5
    
    @State private var playerOnePowerUps: [PowerUp] = []
    @State private var playerTwoPowerUps: [PowerUp] = []
    
    @State private var atomicusActiveForWhite = false
    @State private var atomicusActiveForBlack = false
    @State private var extraTurnActiveForWhite = false
    @State private var extraTurnActiveForBlack = false
    @State private var tripleTurnActiveForWhite = false
    @State private var tripleTurnActiveForBlack = false
    @State private var tripleWhiteTurn = 0
    @State private var tripleBlackTurn = 0
    @State private var pawndimoniumActiveForWhite = false
    @State private var pawndimoniumActiveForBlack = false
    
    @State private var frozenEnemyPieces: [(Position, Int)] = []
    
    @State private var knightsMoveLikeQueensForWhite = 0
    @State private var knightsMoveLikeQueensForBlack = 0
    
    @State private var pieceOutEffects: [(Position, Int, Player)] = []
    @State private var pieceOutSelectionActive = false
    @State private var pieceOutSelectingPlayer: Player? = nil
    
    @State private var kingDeactivatedForWhite = 0
    @State private var kingDeactivatedForBlack = 0
    
    @State private var rookRollForWhite = 0
    @State private var rookRollForBlack = 0
    @State private var rookRollTransformedPiecesWhite: [(Position, PieceType)] = []
    @State private var rookRollTransformedPiecesBlack: [(Position, PieceType)] = []
    
    @State private var puppetStringsActiveForWhite = false
    @State private var puppetStringsActiveForBlack = false
    
    @State private var grandFinaleForWhite = 0
    @State private var grandFinaleForBlack = 0
    
    @State private var allPawnsRookForWhite = 0
    @State private var allPawnsRookForBlack = 0
    
    @State private var chainRemovalsForWhite = 0
    @State private var chainRemovalsForBlack = 0
    
    @State private var moveCounter: Int = 0
    
    @State private var showGameOverAlert = false
    @State private var gameOverMessage = ""
    
    @State private var showPowerUpDescription = false
    @State private var selectedPowerUpDescription: String? = nil

    // ADDED: New states for new abilities
    @State private var shieldWallForWhite = 0 // Protect white pieces from capture
    @State private var shieldWallForBlack = 0 // Protect black pieces from capture
    @State private var ironBootsAffectedPawns: [Position] = [] // Pawns that can't move for 1 turn
    
    // ADDED: We'll introduce a gameMode to handle menu, singleplayer, multiplayer, and catalog
    @State private var gameMode: GameMode = .menu
    
    @State private var currentLogoIndex = 0
    let logoImages = ["logo"] + (1...38).map { "logo \($0)" }

    let logoTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    // MARK: - Modified PowerUp Pools with new abilities
    
    var rarePowers = [
        ("Pawnzilla", "Finds one of your pawns and spawns a second pawn in the same row if space is available.", "Rare"),
        ("Backpedal", "Moves one of your pieces backward by one square if the space is free.", "Rare"),
        ("Pawndemic", "Selects one of your pawns, moves it backward by one square, and captures any adjacent enemy pieces.", "Rare"),
        ("Swap 'n' Go", "Swaps the positions of two of your own pieces.", "Rare"),
        ("Port-A-Piece", "Teleports one of your pieces to the first available free square found (top-left search).", "Rare"),
        ("Reboot", "Brings back a new pawn in your back row if space is available (like resurrecting a captured pawn).", "Rare"),
        ("Copycat", "Moves two of your pawns forward one square each, if possible.", "Rare"),
        ("Iron Boots", "Prevents 3 random enemy pawns from moving forward this turn. 🥾 symbol on affected pawns", "Rare"),
        ("Teleportation", "Choose one of your pieces and then choose an empty square to teleport it there.", "Rare"),
        ("Bargain Hunter", "Resets all your bishops and knights to their original positions and refreshes your powers.", "Rare")
    ]
    
    var epicPowers = [
        
        ("Extra Turn", "Lets you take two consecutive moves before the turn passes to your opponent.", "Epic"),
        ("Pawndimonium", "Your pawns can capture like a king for your next capture. 🤴 symbol on pawns.", "Epic"),
        ("Frozen Assets", "Freezes all enemy queens and rooks for TWO turns now, preventing them from moving. A ❄️ symbol will appear on them.", "Epic"),
        ("Knightmare Fuel", "All your knights move like queens for one turn and show a 👑 symbol.", "Epic"),
        ("Piece Out", "Select an enemy piece to remove immediately.", "Epic"),
        ("King's Sacrifice", "Your king cannot move for 2 rounds, and you delete 2 random enemy pieces instantly. Your king is marked with ⛔ symbol.", "Epic"),
        ("Rook 'n' Roll", "Two of your pieces move like rooks for one turn. 🗼 symbol shown.", "Epic"),
        ("Puppet Strings", "Moves an enemy knight or bishop next to your closest pawn diagonally so it can be captured.", "Epic"),
        ("Grand Finale", "Over the next 3 turns, one random enemy piece is killed each turn.", "Epic"),
        ("Pawno-Kinetic", "Moves all your pawns forward two squares if the spaces are free.", "Epic"),
        ("Shield Wall", "Protect all your pieces from being captured for 1 turn. 🛡️ symbol shown on your pieces.", "Epic"),
        
         
        ("Shapeshifter", "Select one of your own pieces to shapeshift into another piece type (Rook, Knight, Bishop) for 3 turns. 🦊 symbol.", "Epic"),
        ("Royal Jester", "Select one enemy piece and transform it into a pawn for 2 turns, marked with 🤡", "Epic"),
        ("Blitz Surge", "Randomly teleport 3 of your own pieces to empty squares on your side of the board, marked with ⚡ for 1 turn.", "Epic"),
        ("Ancient Guardian", "Choose one of your pieces to become immovable and invincible for 3 turns, marked with 🗿.", "Epic"),
        ("Mind Control", "Choose an enemy piece and move it this turn as if it were yours, showing 🌀 symbol.", "Epic")
    ]
    
    var legendaryPowers = [
        ("Atomicus!", "If one of your pieces is captured, it explodes and removes surrounding pieces in a 3x3 area.", "Legendary"),
        ("Triple Turn", "Allows you to take three consecutive moves before your opponent's turn.", "Legendary"),
        ("Rookie Mistake", "All your pawns move like rooks for 2 rounds. 🚀 symbol shown on them.", "Legendary"),
        ("Check That Out", "Deletes two random pieces around the enemy's king.", "Legendary"),
        ("I Ocean You", "Captures up to four random enemy pawns in a single wave.", "Legendary"),
        ("TimeStop", "Freezes 90% of enemy pieces for 2 turns.", "Legendary"),
        ("Aura", "Choose a piece on the board and all enemy pieces surrounding it will be frozen for 2 turns. ❄️ shown.", "Legendary"),
        ("Lock In", "Choose a piece on the board to lock it with a shield for 5 rounds. Shows 🏰 symbol. It can't be captured during this time.", "Legendary"),
        ("It Says Gullible", "Allows you to choose an enemy piece, and the 3x3 area around that piece will be frozen for 5 moves (show a 🥶 symbol).", "Legendary")
    ]
    
    var exoticPowers = [
        ("Shoot, Where, Where?", "Allows you to choose one of your own pieces, and all squares directly in front of that piece (in the piece’s forward direction) will be cleared of any pieces.", "Exotic"),
        ("Pawnder That", "For 1 turn, all your pawns become queens and explode in a 3x3 area upon capturing, showing 💣 symbol.", "Exotic"),
        ("Dark Reaper", "Select one piece and grant it a scythe ☠️ permanently, allowing it to also delete a 1x3 area in front each round.", "Exotic")
    ]
    
    // ADDED FOR REQUESTED CHANGES
    @State private var teleportSelectionActive = false
    @State private var teleportSelectingPlayer: Player? = nil
    @State private var teleportPhase = 0
    @State private var selectedTeleportPiecePosition: Position? = nil
    
    // ADDED FOR EXOTIC POWERS
    @State private var shootSelectionActive = false
    @State private var shootSelectingPlayer: Player? = nil
    @State private var shootPhase = 0
    @State private var shootSelectedPiece: Position? = nil
    
    @State private var gullibleSelectionActive = false
    @State private var gullibleSelectingPlayer: Player? = nil
    @State private var gulliblePhase = 0
    
    // ADDED: We'll treat singleplayer as playerOne=human, playerTwo=bot
    // Bot logic
    @State private var botThinking = false
    
    @State private var currentTipIndex = 0
    let tips = [
        "Tip 1: Activate powers at strategic moments to gain the greatest advantage.",
        "Tip 2: Save exotic and legendary powers for critical situations when you need a big swing.",
        "Tip 3: Keep track of cooldowns so you can plan your turns around when powers return.",
        "Tip 4: Combine offensive and defensive powers to surprise your opponent and protect your king.",
        "Tip 5: Use teleportation or repositioning powers to outmaneuver slower enemy pieces.",
        "Tip 6: Powers that freeze or immobilize enemy pieces can set up devastating attacks.",
        "Tip 7: Consider which piece benefits most from a power-up; sometimes a pawn can become a deadly weapon.",
        "Tip 8: If you don’t like your power options, refresh them before a crucial turn.",
        "Tip 9: Legendary and exotic powers can change the board in your favor—learn their synergies.",
        "Tip 10: Time your multi-move or extra-move powers to finish off enemies or secure checkmate.",
        "Tip 11: Defensive powers like Shield Wall can give you the breathing room to mount a strong offense.",
        "Tip 12: Some powers benefit knights or bishops more—think about which piece to enhance.",
        "Tip 13: Remember that controlling the center matters even more when you can boost or move pieces unexpectedly.",
        "Tip 14: Powers that disrupt enemy pawns can prevent them from promoting, tilting the late game in your favor.",
        "Tip 15: Atomic or explosive effects can clear space for your heavy pieces—just don’t blow up your own troops!",
        "Tip 16: Always consider the next turn: a power might be more useful if you wait one move before using it.",
        "Tip 17: Pairing a mobility power with a capture-focused power can create unstoppable threats.",
        "Tip 18: Powers that grant extra turns let you execute complex plans or deliver surprise checkmates.",
        "Tip 19: Keep an eye on your opponent’s powers, anticipating how they might counter your plans.",
        "Tip 20: Practice with different power combinations to learn subtle interactions and dominate the board."
    ]
    
    // ADDED: ELO and Global Ranking using @AppStorage for persistence
    @AppStorage("playerElo") private var playerElo: Int = 800
    @AppStorage("globalRanking") private var globalRanking: Int = 22943
    
    // ADDED: Cooldown states for Refresh abilities
    @State private var playerOneRefreshCooldown: Int = 0
    @State private var playerTwoRefreshCooldown: Int = 0
    
    // ADDED NEW POWER STATES:
    @State private var auraSelectionActive = false
    @State private var auraSelectingPlayer: Player? = nil
    @State private var auraPhase = 0
    
    @State private var lockInSelectionActive = false
    @State private var lockInSelectingPlayer: Player? = nil
    @State private var lockInPhase = 0
    @State private var lockedInPieces: [(Position, Int)] = []
    
    @State private var reaperSelectionActive = false
    @State private var reaperSelectingPlayer: Player? = nil
    @State private var reaperPhase = 0
    @State private var reaperPieces: [UUID] = []
    
    @State private var pawnderThatForWhite = 0
    @State private var pawnderThatForBlack = 0
    
    // ADDED NEW EPIC POWERS (5 new ones):
    // 1. Shapeshifter
    @State private var shapeshifterSelectionActive = false
    @State private var shapeshifterSelectingPlayer: Player? = nil
    @State private var shapeshifterPhase = 0
    // Store shapeshifted pieces as: position -> (originalType, turnsRemaining)
    @State private var shapeshiftedPieces: [(Position, PieceType, Int)] = []

    // 2. Royal Jester
    @State private var royalJesterSelectionActive = false
    @State private var royalJesterSelectingPlayer: Player? = nil
    @State private var royalJesterPhase = 0
    // Store royal jester transformed pieces: position -> (originalType, turnsRemaining)
    @State private var royalJesterPieces: [(Position, PieceType, Int)] = []

    // 3. Blitz Surge
    @State private var blitzSurgeForWhite = 0
    @State private var blitzSurgeForBlack = 0
    // Marked pieces with ⚡ for 1 turn - just store a turn count indicator if needed
    // We'll just mark them immediately and next turn they lose symbol

    // 4. Ancient Guardian
    @State private var ancientGuardianSelectionActive = false
    @State private var ancientGuardianSelectingPlayer: Player? = nil
    @State private var ancientGuardianPhase = 0
    // ancient guardians: position -> turns
    @State private var ancientGuardianPieces: [(Position, Int)] = []

    // 5. Mind Control
    @State private var mindControlSelectionActive = false
    @State private var mindControlSelectingPlayer: Player? = nil
    @State private var mindControlPhase = 0
    @State private var mindControlSelectedEnemy: Position? = nil
    // If a piece is under mind control this turn, we treat it as if it's player's piece until move done
    @State private var mindControlActive = false

    var body: some View {
        // ADDED: Main content now depends on gameMode and wrapped in ScrollView
        ScrollView {
            switch gameMode {
            case .menu:
                menuView
            case .singleplayer:
                singlePlayerView
            case .multiplayer:
                multiPlayerView
            case .catalog:
                catalogView
            }
        }
    }
    
    private var menuView: some View {
        VStack {
            Text("Ultimate Chess Royale")
                .font(.largeTitle)
                .padding()
            
            ZStack {
                ForEach(0..<logoImages.count, id: \.self) { index in
                    Image(logoImages[index])
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .cornerRadius(10)
                        .opacity(currentLogoIndex == index ? 1 : 0)
                        .animation(.easeInOut(duration: 1.0), value: currentLogoIndex)
                }
            }
            .frame(width: 300, height: 300)
            .padding(20)
            .onReceive(logoTimer) { _ in
                currentLogoIndex = (currentLogoIndex + 1) % logoImages.count
            }
            
            Text("Play Options")
                .font(.headline)
     
            
            Text(tips[currentTipIndex])
                .font(.subheadline)
                .padding()
                .multilineTextAlignment(.center)
                .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                    currentTipIndex = (currentTipIndex + 1) % tips.count
                }
            
            Text("ELO: \(playerElo)")
                .font(.headline)
                .padding(.top, 5)
            
            Text("Global Ranking: \(globalRanking)")
                .font(.subheadline)
                .padding(.bottom, 10)
            
            Button("Play Ranked 1v1") {
                setupInitialBoard()
                playerOnePowerUps = rollNewPowerUps(count: 3)
                playerTwoPowerUps = rollNewPowerUps(count: 3)
                currentPlayer = .playerOne
                gameMode = .singleplayer
                
                let eloGain = Int.random(in: 67...143)
                playerElo += eloGain
                globalRanking -= eloGain*(Int.random(in:6...14))
                if globalRanking < 1{
                    globalRanking = 1;
                }
            }
            .padding()
            .foregroundColor(.black)
            .background(Color.green.opacity(0.3))
            .cornerRadius(10)
            
            Button("2 Player Mode") {
                setupInitialBoard()
                playerOnePowerUps = rollNewPowerUps(count: 3)
                playerTwoPowerUps = rollNewPowerUps(count: 3)
                currentPlayer = .playerOne
                gameMode = .multiplayer
            }
            .padding()
            .foregroundColor(.black)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(10)
            
            Button("Power Catalog") {
                gameMode = .catalog
            }
            .padding()
            .foregroundColor(.black)
            .background(Color.purple.opacity(0.3))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
    }
    
    private var singlePlayerView: some View {
        VStack {
            Button("Ranked 1v1: Return To Menu") {
                gameMode = .menu
            }
            .multilineTextAlignment(.center)
 
            
            Spacer()
            
            VStack {
                Text("Black's Power-Ups (Bot)").font(.headline)
                powerUpBar(for: .playerTwo, powerUps: $playerTwoPowerUps, rollsLeft: $playerTwoRollsLeft, refreshCooldown: $playerTwoRefreshCooldown)
            }
            .rotationEffect(.degrees(180))
            
            Spacer()
            
            boardView
            
            Spacer()
            
            VStack {
                Text("White's Power-Ups").font(.headline)
                powerUpBar(for: .playerOne, powerUps: $playerOnePowerUps, rollsLeft: $playerOneRollsLeft, refreshCooldown: $playerOneRefreshCooldown)
            }
        }
        .padding()
        .alert(isPresented: $showGameOverAlert) {
            Alert(
                title: Text("Game Over"),
                message: Text(gameOverMessage),
                dismissButton: .default(Text("OK")) {
                    resetGame()
                    gameMode = .menu
                }
            )
        }
        .alert(isPresented: $showPowerUpDescription) {
            Alert(
                title: Text("Power-Up Description"),
                message: Text(selectedPowerUpDescription ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: currentPlayer) { newPlayer in
            if gameMode == .singleplayer && newPlayer == .playerTwo && !showGameOverAlert {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    doBotTurnIfNeeded()
                }
            }
        }
    }
    
    private var multiPlayerView: some View {
        VStack {
            Button("2 Player: Return To Menu") {
                gameMode = .menu
            }
 
            Button("Refresh Board") {
                refreshMultiplayerBoard()
            }
            .padding()
            
            VStack {
                Text("Black's Power-Ups").font(.headline)
                powerUpBar(for: .playerTwo, powerUps: $playerTwoPowerUps, rollsLeft: $playerTwoRollsLeft, refreshCooldown: $playerTwoRefreshCooldown)
            }
            .rotationEffect(.degrees(180))
            
            Spacer()
            
            boardView
            
            Spacer()
            
            VStack {
                Text("White's Power-Ups").font(.headline)
                powerUpBar(for: .playerOne, powerUps: $playerOnePowerUps, rollsLeft: $playerOneRollsLeft, refreshCooldown: $playerOneRefreshCooldown)
            }
        }
        .onAppear {
        }
        .padding()
        .alert(isPresented: $showGameOverAlert) {
            Alert(
                title: Text("Game Over"),
                message: Text(gameOverMessage),
                dismissButton: .default(Text("OK")) {
                    resetGame()
                    gameMode = .menu
                }
            )
        }
        .alert(isPresented: $showPowerUpDescription) {
            Alert(
                title: Text("Power-Up Description"),
                message: Text(selectedPowerUpDescription ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var catalogView: some View {
        VStack {
            Text("Power-Up Catalog")
                .font(.largeTitle)
                .padding()
            
            Text("Hold on a power to see its description")
                .font(.subheadline)
                .padding()
            
            ScrollView {
                Text("Rare Power-Ups").font(.headline).padding(.top)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(rarePowers.indices, id: \.self) { i in
                        let (n, d, r) = rarePowers[i]
                        PowerUpButtonView(powerUp: PowerUp(name: n, description: d, rarity: r, cooldown: 0))
                            .environment(\.showDescriptionAction, showDescription)
                            .padding(.bottom, 4)
                    }
                }

                Text("Epic Power-Ups").font(.headline).padding(.top)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(epicPowers.indices, id: \.self) { i in
                        let (n, d, r) = epicPowers[i]
                        PowerUpButtonView(powerUp: PowerUp(name: n, description: d, rarity: r, cooldown: 0))
                            .environment(\.showDescriptionAction, showDescription)
                            .padding(.bottom, 4)
                    }
                }

                Text("Legendary Power-Ups").font(.headline).padding(.top)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(legendaryPowers.indices, id: \.self) { i in
                        let (n, d, r) = legendaryPowers[i]
                        PowerUpButtonView(powerUp: PowerUp(name: n, description: d, rarity: r, cooldown: 0))
                            .environment(\.showDescriptionAction, showDescription)
                            .padding(.bottom, 4)
                    }
                }

                Text("Exotic Power-Ups").font(.headline).padding(.top)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(exoticPowers.indices, id: \.self) { i in
                        let (n, d, r) = exoticPowers[i]
                        PowerUpButtonView(powerUp: PowerUp(name: n, description: d, rarity: r, cooldown: 0))
                            .environment(\.showDescriptionAction, showDescription)
                            .padding(.bottom, 4)
                    }
                }
            }

            Button("Back to Menu") {
                gameMode = .menu
            }
            .padding()
        }
        .alert(isPresented: $showPowerUpDescription) {
            Alert(
                title: Text("Power-Up Description"),
                message: Text(selectedPowerUpDescription ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }


    private func showDescription(_ desc: String) {
        self.selectedPowerUpDescription = desc
        self.showPowerUpDescription = true
    }

    private func resetGame() {
        board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        setupInitialBoard()
        
        currentPlayer = .playerOne
        selectedPosition = nil
        possibleMoves = []
        
        playerOneRollsLeft = 5
        playerTwoRollsLeft = 5
        
        playerOnePowerUps = rollNewPowerUps(count: 3)
        playerTwoPowerUps = rollNewPowerUps(count: 3)
        
        atomicusActiveForWhite = false
        atomicusActiveForBlack = false
        extraTurnActiveForWhite = false
        extraTurnActiveForBlack = false
        pawndimoniumActiveForWhite = false
        pawndimoniumActiveForBlack = false
        
        frozenEnemyPieces = []
        knightsMoveLikeQueensForWhite = 0
        knightsMoveLikeQueensForBlack = 0
        pieceOutEffects = []
        pieceOutSelectionActive = false
        pieceOutSelectingPlayer = nil
        
        kingDeactivatedForWhite = 0
        kingDeactivatedForBlack = 0
        
        rookRollForWhite = 0
        rookRollForBlack = 0
        rookRollTransformedPiecesWhite = []
        rookRollTransformedPiecesBlack = []
        
        puppetStringsActiveForWhite = false
        puppetStringsActiveForBlack = false
        
        grandFinaleForWhite = 0
        grandFinaleForBlack = 0
        
        allPawnsRookForWhite = 0
        allPawnsRookForBlack = 0
        
        chainRemovalsForWhite = 0
        chainRemovalsForBlack = 0
        
        moveCounter = 0
        showGameOverAlert = false
        gameOverMessage = ""
        
        shieldWallForWhite = 0
        shieldWallForBlack = 0
        ironBootsAffectedPawns = []
        
        teleportSelectionActive = false
        teleportSelectingPlayer = nil
        teleportPhase = 0
        selectedTeleportPiecePosition = nil
        
        shootSelectionActive = false
        shootSelectingPlayer = nil
        shootPhase = 0
        shootSelectedPiece = nil
        
        gullibleSelectionActive = false
        gullibleSelectingPlayer = nil
        gulliblePhase = 0
        
        playerOneRefreshCooldown = 0
        playerTwoRefreshCooldown = 0
        
        auraSelectionActive = false
        auraSelectingPlayer = nil
        auraPhase = 0
        
        lockInSelectionActive = false
        lockInSelectingPlayer = nil
        lockInPhase = 0
        lockedInPieces = []
        
        reaperSelectionActive = false
        reaperSelectingPlayer = nil
        reaperPhase = 0
        reaperPieces = []
        
        pawnderThatForWhite = 0
        pawnderThatForBlack = 0

        // ADDED NEW EPIC POWERS RESET
        shapeshifterSelectionActive = false
        shapeshifterSelectingPlayer = nil
        shapeshifterPhase = 0
        shapeshiftedPieces = []
        
        royalJesterSelectionActive = false
        royalJesterSelectingPlayer = nil
        royalJesterPhase = 0
        royalJesterPieces = []
        
        blitzSurgeForWhite = 0
        blitzSurgeForBlack = 0
        
        ancientGuardianSelectionActive = false
        ancientGuardianSelectingPlayer = nil
        ancientGuardianPhase = 0
        ancientGuardianPieces = []
        
        mindControlSelectionActive = false
        mindControlSelectingPlayer = nil
        mindControlPhase = 0
        mindControlSelectedEnemy = nil
        mindControlActive = false
    }
    
    private func refreshMultiplayerBoard() {
        board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        setupInitialBoard()
        
        currentPlayer = .playerOne
        selectedPosition = nil
        possibleMoves = []
        
        playerOneRollsLeft = 5
        playerTwoRollsLeft = 5
        
        playerOnePowerUps = rollNewPowerUps(count: 3)
        playerTwoPowerUps = rollNewPowerUps(count: 3)
        
        atomicusActiveForWhite = false
        atomicusActiveForBlack = false
        extraTurnActiveForWhite = false
        extraTurnActiveForBlack = false
        tripleTurnActiveForWhite = false
        tripleTurnActiveForBlack = false
        tripleWhiteTurn = 0
        tripleBlackTurn = 0
        pawndimoniumActiveForWhite = false
        pawndimoniumActiveForBlack = false
        
        frozenEnemyPieces = []
        knightsMoveLikeQueensForWhite = 0
        knightsMoveLikeQueensForBlack = 0
        pieceOutEffects = []
        pieceOutSelectionActive = false
        pieceOutSelectingPlayer = nil
        
        kingDeactivatedForWhite = 0
        kingDeactivatedForBlack = 0
        
        rookRollForWhite = 0
        rookRollForBlack = 0
        rookRollTransformedPiecesWhite = []
        rookRollTransformedPiecesBlack = []
        
        puppetStringsActiveForWhite = false
        puppetStringsActiveForBlack = false
        
        grandFinaleForWhite = 0
        grandFinaleForBlack = 0
        
        allPawnsRookForWhite = 0
        allPawnsRookForBlack = 0
        
        chainRemovalsForWhite = 0
        chainRemovalsForBlack = 0
        
        shieldWallForWhite = 0
        shieldWallForBlack = 0
        ironBootsAffectedPawns = []
        
        teleportSelectionActive = false
        teleportSelectingPlayer = nil
        teleportPhase = 0
        selectedTeleportPiecePosition = nil
        
        shootSelectionActive = false
        shootSelectingPlayer = nil
        shootPhase = 0
        shootSelectedPiece = nil
        
        gullibleSelectionActive = false
        gullibleSelectingPlayer = nil
        gulliblePhase = 0
        
        playerOneRefreshCooldown = 0
        playerTwoRefreshCooldown = 0
        
        auraSelectionActive = false
        auraSelectingPlayer = nil
        auraPhase = 0
        
        lockInSelectionActive = false
        lockInSelectingPlayer = nil
        lockInPhase = 0
        lockedInPieces = []
        
        reaperSelectionActive = false
        reaperSelectingPlayer = nil
        reaperPhase = 0
        reaperPieces = []
        
        pawnderThatForWhite = 0
        pawnderThatForBlack = 0
        
        gameOverMessage = ""
        showGameOverAlert = false

        // NEW EPIC POWER resets:
        shapeshifterSelectionActive = false
        shapeshifterSelectingPlayer = nil
        shapeshifterPhase = 0
        shapeshiftedPieces = []
        
        royalJesterSelectionActive = false
        royalJesterSelectingPlayer = nil
        royalJesterPhase = 0
        royalJesterPieces = []
        
        blitzSurgeForWhite = 0
        blitzSurgeForBlack = 0
        
        ancientGuardianSelectionActive = false
        ancientGuardianSelectingPlayer = nil
        ancientGuardianPhase = 0
        ancientGuardianPieces = []
        
        mindControlSelectionActive = false
        mindControlSelectingPlayer = nil
        mindControlPhase = 0
        mindControlSelectedEnemy = nil
        mindControlActive = false
    }
    
    private var boardView: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        ZStack {
                            Rectangle()
                                .fill((row + col).isMultiple(of: 2) ? Color.gray.opacity(0.4) : Color.white)
                            if possibleMoves.contains(Position(row: row, col: col)) {
                                Color.green.opacity(0.3)
                            }
                            if let piece = board[row][col] {
                                // Determine symbol
                                Text(pieceSymbol(piece))
                                    .font(.system(size: 35))
                                    .foregroundColor(piece.color == .white ? .blue : .red)
                                    .overlay(
                                        // ADDED: Overlapping emojis for power effects on top
                                        ZStack {
                                            if isPieceFrozen(Position(row: row, col: col)) {
                                                if let freezeInfo = frozenEnemyPieces.first(where: {$0.0 == Position(row: row, col: col)}) {
                                                    if freezeInfo.1 > 2 {
                                                        Text("🥶")
                                                            .font(.system(size: 20))
                                                            .offset(x: 15, y: -15)
                                                    } else {
                                                        Text("❄️")
                                                            .font(.system(size: 20))
                                                            .offset(x: 15, y: -15)
                                                    }
                                                }
                                            }
                                            
                                            if piece.type == .king && ((piece.color == .white && kingDeactivatedForWhite > 0) || (piece.color == .black && kingDeactivatedForBlack > 0)) {
                                                Text("⛔")
                                                    .font(.system(size: 20))
                                                    .offset(x: -15, y: -15)
                                            }

                                            if piece.type == .knight {
                                                if (piece.color == .white && knightsMoveLikeQueensForWhite > 0) || (piece.color == .black && knightsMoveLikeQueensForBlack > 0) {
                                                    Text("👑")
                                                        .font(.system(size: 20))
                                                        .offset(x: 15, y: 15)
                                                }
                                            }

                                            if (piece.color == .white && rookRollForWhite > 0 && rookRollTransformedPiecesWhite.contains(where: {$0.0 == Position(row: row, col: col)})) ||
                                                (piece.color == .black && rookRollForBlack > 0 && rookRollTransformedPiecesBlack.contains(where: {$0.0 == Position(row: row, col: col)})) {
                                                Text("🗼")
                                                    .font(.system(size: 20))
                                                    .offset(x: -15, y: 15)
                                            }

                                            if piece.type == .pawn {
                                                if (piece.color == .white && pawndimoniumActiveForWhite) || (piece.color == .black && pawndimoniumActiveForBlack) {
                                                    Text("🤴")
                                                        .font(.system(size: 20))
                                                        .offset(x: 0, y: -25)
                                                }
                                            }

                                            if piece.type == .pawn && ironBootsAffectedPawns.contains(Position(row: row, col: col)) {
                                                Text("⛓️")
                                                    .font(.system(size: 20))
                                                    .offset(x: -15, y: -25)
                                            }

                                            if (piece.color == .white && shieldWallForWhite > 0) || (piece.color == .black && shieldWallForBlack > 0) {
                                                Text("🛡️")
                                                    .font(.system(size: 20))
                                                    .offset(x: 0, y: 25)
                                            }

                                            if piece.type == .pawn {
                                                if (piece.color == .white && allPawnsRookForWhite > 0) || (piece.color == .black && allPawnsRookForBlack > 0) {
                                                    Text("🚀")
                                                        .font(.system(size: 20))
                                                        .offset(x: 15, y: -15)
                                                }
                                            }

                                            // Locked-in pieces
                                            if lockedInPieces.contains(where: {$0.0 == Position(row: row, col: col)}) {
                                                Text("🏰")
                                                    .font(.system(size: 20))
                                                    .offset(x: -15, y: 25)
                                            }

                                            // Reaper piece
                                            if isReaperPiece(piece) {
                                                Text("☠️")
                                                    .font(.system(size: 20))
                                                    .offset(x: 15, y: -25)
                                            }

                                            // Pawnder That
                                            if piece.type == .pawn {
                                                if (piece.color == .white && pawnderThatForWhite > 0) || (piece.color == .black && pawnderThatForBlack > 0) {
                                                    Text("💣")
                                                        .font(.system(size: 20))
                                                        .offset(x: -15, y: -15)
                                                }
                                            }

                                            // ADDED NEW EPIC POWERS SYMBOLS:
                                            // Shapeshifter (🦊)
                                            if shapeshiftedPieces.contains(where: {$0.0 == Position(row: row, col: col)}) {
                                                Text("🦊")
                                                    .font(.system(size: 20))
                                                    .offset(x: -20, y: -20)
                                            }

                                            // Royal Jester (🤡)
                                            if royalJesterPieces.contains(where: {$0.0 == Position(row: row, col: col)}) {
                                                Text("🤡")
                                                    .font(.system(size: 20))
                                                    .offset(x: 20, y: -20)
                                            }

                                            // Blitz Surge (⚡)
                                            if (piece.color == .white && blitzSurgeForWhite > 0) || (piece.color == .black && blitzSurgeForBlack > 0) {
                                                // Just show ⚡ on pieces that got teleported?
                                                // We can just show on all pieces of that player for that turn or no?
                                                // Let's show ⚡ on all player's pieces for simplicity
                                                Text("⚡")
                                                    .font(.system(size: 20))
                                                    .offset(x: -20, y: 20)
                                            }

                                            // Ancient Guardian (🗿)
                                            if ancientGuardianPieces.contains(where: {$0.0 == Position(row: row, col: col)}) {
                                                Text("🗿")
                                                    .font(.system(size: 20))
                                                    .offset(x: 20, y: 20)
                                            }

                                            // Mind Control (🌀)
                                            if mindControlActive, let sel = mindControlSelectedEnemy, sel == Position(row: row, col: col) {
                                                Text("🌀")
                                                    .font(.system(size: 20))
                                                    .offset(x: -25, y: 0)
                                            }
                                        }
                                    )

                            }
                            
                            if pieceOutSelectionActive, let piece = board[row][col], piece.color != currentPlayer.color {
                                Color.red.opacity(0.3)
                            }
                            
                            if teleportSelectionActive {
                                if teleportPhase == 1 {
                                    if let piece = board[row][col], piece.color == teleportSelectingPlayer?.color {
                                        Color.yellow.opacity(0.3)
                                    }
                                } else if teleportPhase == 2 {
                                    if board[row][col] == nil {
                                        Color.yellow.opacity(0.3)
                                    }
                                }
                            }
                            
                            if shootSelectionActive {
                                if shootPhase == 1 {
                                    if let piece = board[row][col], piece.color == shootSelectingPlayer?.color {
                                        Color.orange.opacity(0.3)
                                    }
                                }
                            }
                            
                            if gullibleSelectionActive {
                                if gulliblePhase == 1 {
                                    if let piece = board[row][col], piece.color != gullibleSelectingPlayer?.color {
                                        Color.blue.opacity(0.3)
                                    }
                                }
                            }

                            if auraSelectionActive && auraPhase == 1 {
                                if let _ = board[row][col] {
                                    Color.pink.opacity(0.3)
                                }
                            }

                            if lockInSelectionActive && lockInPhase == 1 {
                                if let piece = board[row][col], piece.color == lockInSelectingPlayer?.color {
                                    Color.yellow.opacity(0.3)
                                }
                            }

                            if reaperSelectionActive && reaperPhase == 1 {
                                if let piece = board[row][col], piece.color == reaperSelectingPlayer?.color {
                                    Color.green.opacity(0.3)
                                }
                            }

                            // ADDED NEW EPIC POWERS SELECTION HIGHLIGHTS:
                            // Shapeshifter selection
                            if shapeshifterSelectionActive && shapeshifterPhase == 1 {
                                if let piece = board[row][col], piece.color == shapeshifterSelectingPlayer?.color {
                                    Color.orange.opacity(0.3)
                                }
                            }

                            // Royal Jester selection
                            if royalJesterSelectionActive && royalJesterPhase == 1 {
                                if let piece = board[row][col], piece.color != royalJesterSelectingPlayer?.color {
                                    Color.purple.opacity(0.3)
                                }
                            }

                            // Ancient Guardian selection
                            if ancientGuardianSelectionActive && ancientGuardianPhase == 1 {
                                if let piece = board[row][col], piece.color == ancientGuardianSelectingPlayer?.color {
                                    Color.brown.opacity(0.3)
                                }
                            }

                            // Mind Control selection
                            if mindControlSelectionActive && mindControlPhase == 1 {
                                if let piece = board[row][col], piece.color != mindControlSelectingPlayer?.color {
                                    Color.cyan.opacity(0.3)
                                }
                            }
                        }
                        .frame(width: 44, height: 44)
                        .border(Color.black, width: 1)
                        .onTapGesture {
                            cellTapped(row: row, col: col)
                        }
                    }
                }
            }
        }
    }
    
    private func powerUpBar(for player: Player, powerUps: Binding<[PowerUp]>, rollsLeft: Binding<Int>, refreshCooldown: Binding<Int>) -> some View {
        let isCurrentPlayer = (player == currentPlayer && (gameMode != .singleplayer || player == .playerOne))
        
        return HStack {
            ForEach(powerUps.wrappedValue.indices, id: \.self) { i in
                let pUp = powerUps.wrappedValue[i]
                Button {
                    activatePowerUp(for: player, index: i)
                } label: {
                    PowerUpButtonView(powerUp: pUp)
                        .environment(\.showDescriptionAction, showDescription)

                }
                .disabled(!isCurrentPlayer || pUp.cooldown > 0 || pieceOutSelectionActive || teleportSelectionActive || shootSelectionActive || gullibleSelectionActive || auraSelectionActive || lockInSelectionActive || reaperSelectionActive || shapeshifterSelectionActive || royalJesterSelectionActive || ancientGuardianSelectionActive || mindControlSelectionActive)
            }
            
            Button(action: {
                if rollsLeft.wrappedValue > 0 && isCurrentPlayer && refreshCooldown.wrappedValue == 0 {
                    rollsLeft.wrappedValue -= 1
                    let newUps = rollNewPowerUps(count: 3)
                    if player == .playerOne {
                        playerOnePowerUps = newUps
                        playerOneRefreshCooldown = 2
                    } else {
                        playerTwoPowerUps = newUps
                        playerTwoRefreshCooldown = 2
                    }
                }
            }) {
                VStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(8)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                    Text("Refresh (\(rollsLeft.wrappedValue))")
                        .font(.caption2)
                }
            }
            .disabled(!isCurrentPlayer || rollsLeft.wrappedValue == 0 || refreshCooldown.wrappedValue > 0 || pieceOutSelectionActive || teleportSelectionActive || shootSelectionActive || gullibleSelectionActive || auraSelectionActive || lockInSelectionActive || reaperSelectionActive || shapeshifterSelectionActive || royalJesterSelectionActive || ancientGuardianSelectionActive || mindControlSelectionActive)
        }
        .padding()
        .background(isCurrentPlayer ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    struct PowerUpButtonView: View {
        let powerUp: ContentView.PowerUp
        
        @Environment(\.showDescriptionAction) var showDescriptionAction

        private var backgroundColor: Color {
            switch powerUp.rarity.lowercased() {
            case "rare":
                return Color.blue
            case "epic":
                return Color.purple
            case "legendary":
                return Color.orange
            case "exotic":
                return Color.clear
            default:
                return Color.yellow
            }
        }
        
        var body: some View {
            VStack {
                Image(powerUp.name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .clipped()
                
                Text(powerUp.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.black)
                Text(powerUp.rarity)
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.black)
                
                if powerUp.cooldown > 0 {
                    Text("CD: \(powerUp.cooldown)")
                        .font(.caption2)
                        .foregroundColor(.black)
                }
            }
            .padding(8)
            .background(
                powerUp.rarity == "Exotic" ?
                AnyView(
                    LinearGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                        .opacity(powerUp.cooldown == 0 ? 0.8 : 0.4)
                )
                :
                AnyView(
                    backgroundColor
                        .opacity(powerUp.cooldown == 0 ? 0.8 : 0.4)
                )
            )
            .cornerRadius(10)
            .onLongPressGesture(minimumDuration: 0.3) {
                showDescriptionAction(powerUp.description)
            }
        }

    }
    
    private func setupInitialBoard() {
        board[7][0] = ChessPiece(type: .rook, color: .white)
        board[7][1] = ChessPiece(type: .knight, color: .white)
        board[7][2] = ChessPiece(type: .bishop, color: .white)
        board[7][3] = ChessPiece(type: .queen, color: .white)
        board[7][4] = ChessPiece(type: .king, color: .white)
        board[7][5] = ChessPiece(type: .bishop, color: .white)
        board[7][6] = ChessPiece(type: .knight, color: .white)
        board[7][7] = ChessPiece(type: .rook, color: .white)
        for c in 0..<8 {
            board[6][c] = ChessPiece(type: .pawn, color: .white)
        }
        
        board[0][0] = ChessPiece(type: .rook, color: .black)
        board[0][1] = ChessPiece(type: .knight, color: .black)
        board[0][2] = ChessPiece(type: .bishop, color: .black)
        board[0][3] = ChessPiece(type: .queen, color: .black)
        board[0][4] = ChessPiece(type: .king, color: .black)
        board[0][5] = ChessPiece(type: .bishop, color: .black)
        board[0][6] = ChessPiece(type: .knight, color: .black)
        board[0][7] = ChessPiece(type: .rook, color: .black)
        for c in 0..<8 {
            board[1][c] = ChessPiece(type: .pawn, color: .black)
        }
    }
    
    private func cellTapped(row: Int, col: Int) {
        let tappedPos = Position(row: row, col: col)
        
        // Teleportation selection
        if teleportSelectionActive, let selPlayer = teleportSelectingPlayer {
            if teleportPhase == 1 {
                if let piece = board[row][col], piece.color == selPlayer.color {
                    selectedTeleportPiecePosition = tappedPos
                    teleportPhase = 2
                }
                return
            } else if teleportPhase == 2 {
                if board[row][col] == nil, let fromPos = selectedTeleportPiecePosition, board[fromPos.row][fromPos.col] != nil {
                    board[row][col] = board[fromPos.row][fromPos.col]
                    board[fromPos.row][fromPos.col] = nil
                    teleportSelectionActive = false
                    teleportSelectingPlayer = nil
                    teleportPhase = 0
                    selectedTeleportPiecePosition = nil
                    handleMoveEnd()
                }
                return
            }
        }
        
        // Shoot, Where, Where?
        if shootSelectionActive, let selPlayer = shootSelectingPlayer {
            if shootPhase == 1 {
                if let piece = board[row][col], piece.color == selPlayer.color {
                    shootSelectedPiece = tappedPos
                    clearInFront(of: tappedPos, for: piece.color)
                    shootSelectionActive = false
                    shootSelectingPlayer = nil
                    shootPhase = 0
                    shootSelectedPiece = nil
                    handleMoveEnd()
                }
                return
            }
        }
        
        // It Says Gullible
        if gullibleSelectionActive, let selPlayer = gullibleSelectingPlayer {
            if gulliblePhase == 1 {
                if let piece = board[row][col], piece.color != selPlayer.color {
                    freezeAreaAround(pos: tappedPos, turns: 5)
                    gullibleSelectionActive = false
                    gullibleSelectingPlayer = nil
                    gulliblePhase = 0
                    handleMoveEnd()
                }
                return
            }
        }
        
        // Piece Out
        if pieceOutSelectionActive, let selPlayer = pieceOutSelectingPlayer {
            if let piece = board[row][col], piece.color != selPlayer.color {
                board[row][col] = nil
                pieceOutSelectionActive = false
                pieceOutSelectingPlayer = nil
                return
            } else {
                return
            }
        }

        // Aura selection
        if auraSelectionActive, let selPlayer = auraSelectingPlayer {
            if auraPhase == 1 {
                // Choose ANY piece
                if let _ = board[row][col] {
                    freezeAround(pos: tappedPos, for: selPlayer, turns: 2)
                    auraSelectionActive = false
                    auraSelectingPlayer = nil
                    auraPhase = 0
                    handleMoveEnd()
                }
                return
            }
        }

        // Lock In selection
        if lockInSelectionActive, let selPlayer = lockInSelectingPlayer {
            if lockInPhase == 1 {
                if let piece = board[row][col], piece.color == selPlayer.color {
                    lockedInPieces.append((tappedPos,5))
                    lockInSelectionActive = false
                    lockInSelectingPlayer = nil
                    lockInPhase = 0
                    handleMoveEnd()
                }
                return
            }
        }

        // Reaper selection
        if reaperSelectionActive, let selPlayer = reaperSelectingPlayer {
            if reaperPhase == 1 {
                if let piece = board[row][col], piece.color == selPlayer.color {
                    reaperPieces.append(piece.id)
                    reaperSelectionActive = false
                    reaperSelectingPlayer = nil
                    reaperPhase = 0
                    handleMoveEnd()
                }
                return
            }
        }

        // Shapeshifter selection
        if shapeshifterSelectionActive, let selPlayer = shapeshifterSelectingPlayer {
            if shapeshifterPhase == 1 {
                if let piece = board[row][col], piece.color == selPlayer.color {
                    // shapeshift this piece
                    let originalType = piece.type
                    let newType: PieceType = [.rook, .knight, .bishop].randomElement()!
                    board[row][col] = ChessPiece(type: newType, color: piece.color)
                    shapeshiftedPieces.append((Position(row: row, col: col), originalType, 3))
                    shapeshifterSelectionActive = false
                    shapeshifterSelectingPlayer = nil
                    shapeshifterPhase = 0
                    handleMoveEnd()
                }
                return
            }
        }

        // Royal Jester selection
        if royalJesterSelectionActive, let selPlayer = royalJesterSelectingPlayer {
            if royalJesterPhase == 1 {
                if let piece = board[row][col], piece.color != selPlayer.color {
                    // turn into a pawn for 2 turns
                    let originalType = piece.type
                    let newPiece = ChessPiece(type: .pawn, color: piece.color)
                    board[row][col] = newPiece
                    royalJesterPieces.append((Position(row: row, col: col), originalType, 2))
                    royalJesterSelectionActive = false
                    royalJesterSelectingPlayer = nil
                    royalJesterPhase = 0
                    handleMoveEnd()
                }
                return
            }
        }

        // Ancient Guardian selection
        if ancientGuardianSelectionActive, let selPlayer = ancientGuardianSelectingPlayer {
            if ancientGuardianPhase == 1 {
                if let piece = board[row][col], piece.color == selPlayer.color {
                    ancientGuardianPieces.append((Position(row: row, col: col),3))
                    ancientGuardianSelectionActive = false
                    ancientGuardianSelectingPlayer = nil
                    ancientGuardianPhase = 0
                    handleMoveEnd()
                }
                return
            }
        }

        // Mind Control selection
        if mindControlSelectionActive, let selPlayer = mindControlSelectingPlayer {
            if mindControlPhase == 1 {
                if let piece = board[row][col], piece.color != selPlayer.color {
                    // Select enemy piece to control
                    mindControlSelectedEnemy = Position(row: row, col: col)
                    mindControlActive = true
                    mindControlSelectionActive = false
                    mindControlSelectingPlayer = nil
                    mindControlPhase = 0
                    // Now we can move it as if ours
                    return
                }
                return
            }
        }
        
        if let selected = selectedPosition {
            if possibleMoves.contains(tappedPos) {
                movePiece(from: selected, to: tappedPos)
                selectedPosition = nil
                possibleMoves = []
            } else {
                selectedPosition = selectIfCurrentPlayersPiece(position: tappedPos)
                possibleMoves = selectedPosition != nil ? validMoves(for: selectedPosition!) : []
            }
        } else {
            selectedPosition = selectIfCurrentPlayersPiece(position: tappedPos)
            possibleMoves = selectedPosition != nil ? validMoves(for: selectedPosition!) : []
        }
    }
    
    private func selectIfCurrentPlayersPiece(position: Position) -> Position? {
        if mindControlActive, let enemy = mindControlSelectedEnemy, position == enemy {
            // Mind controlled piece selected as if ours
            return position
        }
        if let piece = board[position.row][position.col], piece.color == currentPlayer.color {
            if piece.type == .king {
                if (piece.color == .white && kingDeactivatedForWhite > 0) || (piece.color == .black && kingDeactivatedForBlack > 0) {
                    return nil
                }
            }
            if isPieceFrozen(position) {
                return nil
            }
            if isPieceOutBlocked(position) {
                return nil
            }
            return position
        }
        return nil
    }
    
    private func movePiece(from: Position, to: Position) {
        guard let piece = board[from.row][from.col] else { return }
        let originalPiece = piece
        let isCapture = board[to.row][to.col] != nil
        
        let pawndimoniumActive = (currentPlayer == .playerOne && pawndimoniumActiveForWhite) || (currentPlayer == .playerTwo && pawndimoniumActiveForBlack)
        let wasPawndimoniumCapture = pawndimoniumActive && isPawnCaptureMoveLike(from: from, to: to, piece: piece)
        
        let capturedPiece = board[to.row][to.col]
        
        // Check Lock In
        if isCapture, let defender = capturedPiece {
            if lockedInPieces.contains(where: {$0.0 == Position(row: to.row, col: to.col)}) {
                return
            }
            if ((defender.color == .white && shieldWallForWhite > 0) || (defender.color == .black && shieldWallForBlack > 0)) {
                return
            }
            // Check Ancient Guardian (immovable & invincible)
            if ancientGuardianPieces.contains(where: {$0.0 == Position(row: to.row, col: to.col)}) {
                return
            }
        }

        // Pawnder That logic
        let pawnderActive = (piece.color == .white && pawnderThatForWhite > 0) || (piece.color == .black && pawnderThatForBlack > 0)
        board[to.row][to.col] = piece
        board[from.row][from.col] = nil
        
        if wasPawndimoniumCapture && isCapture {
            board[to.row][to.col] = nil
            board[from.row][from.col] = originalPiece
            deactivatePawndimonium(for: currentPlayer)
        }
        
        if let deadPiece = capturedPiece, deadPiece.type == .king {
            gameOverMessage = deadPiece.color == .white ? "Black wins!" : "White wins!"
            showGameOverAlert = true
            return
        }
        
        if isCapture && !wasPawndimoniumCapture, let deadPiece = capturedPiece {
            let opponentHasAtomicus = (deadPiece.color == .white && atomicusActiveForWhite) || (deadPiece.color == .black && atomicusActiveForBlack)
            if opponentHasAtomicus {
                explodeAt(row: to.row, col: to.col)
            }
        }

        if isCapture && piece.type == .pawn && pawnderActive {
            explodeAt(row: to.row, col: to.col)
        }
        
        // If mind control was active, after move disable it
        if mindControlActive {
            mindControlActive = false
            mindControlSelectedEnemy = nil
        }

        handleMoveEnd()
    }
    
    private func handleMoveEnd() {
        moveCounter += 1
        
        if currentPlayer == .playerOne && grandFinaleForWhite > 0 {
            removeRandomEnemyPiece(for: .playerOne)
            grandFinaleForWhite -= 1
        }
        if currentPlayer == .playerTwo && grandFinaleForBlack > 0 {
            removeRandomEnemyPiece(for: .playerTwo)
            grandFinaleForBlack -= 1
        }
        
        if currentPlayer == .playerOne {
            if knightsMoveLikeQueensForBlack > 0 { knightsMoveLikeQueensForBlack -= 1 }
            if allPawnsRookForBlack > 0 { allPawnsRookForBlack -= 1 }
        } else {
            if knightsMoveLikeQueensForWhite > 0 { knightsMoveLikeQueensForWhite -= 1 }
            if allPawnsRookForWhite > 0 { allPawnsRookForWhite -= 1 }
        }

        if currentPlayer == .playerOne && pawnderThatForBlack > 0 {
            pawnderThatForBlack -= 1
        } else if currentPlayer == .playerTwo && pawnderThatForWhite > 0 {
            pawnderThatForWhite -= 1
        }

        if currentPlayer == .playerOne && extraTurnActiveForWhite {
            extraTurnActiveForWhite = false
        } else if currentPlayer == .playerOne && (tripleTurnActiveForWhite && tripleWhiteTurn != 2) {
            if tripleWhiteTurn == 2 {
                tripleTurnActiveForWhite = false
            }
            tripleWhiteTurn += 1
        } else if currentPlayer == .playerTwo && (tripleTurnActiveForBlack && tripleBlackTurn != 2) {
            if tripleBlackTurn == 2 {
                tripleTurnActiveForBlack = false
            }
            tripleBlackTurn += 1
        } else if currentPlayer == .playerTwo && extraTurnActiveForBlack {
            extraTurnActiveForBlack = false
        } else {
            currentPlayer = currentPlayer.opposite
        }
        
        decrementCooldowns(for: &playerOnePowerUps)
        decrementCooldowns(for: &playerTwoPowerUps)
        
        if playerOneRefreshCooldown > 0 {
            playerOneRefreshCooldown -= 1
        }
        if playerTwoRefreshCooldown > 0 {
            playerTwoRefreshCooldown -= 1
        }
        
        advanceFrozenTurns()
        advancePieceOutEffects()

        if currentPlayer == .playerTwo && shieldWallForWhite > 0 {
            shieldWallForWhite -= 1
        } else if currentPlayer == .playerOne && shieldWallForBlack > 0 {
            shieldWallForBlack -= 1
        }
        
        if currentPlayer == .playerOne {
            // After black moves done
        } else {
            ironBootsAffectedPawns.removeAll()
        }

        for i in lockedInPieces.indices {
            if lockedInPieces[i].1 > 0 {
                lockedInPieces[i].1 -= 1
            }
        }
        lockedInPieces = lockedInPieces.filter {$0.1 > 0}

        applyReaperEffect(for: currentPlayer)
        
        // ADDED: Decrement Shapeshifted pieces
        for i in shapeshiftedPieces.indices {
            shapeshiftedPieces[i].2 -= 1
        }
        let revertShape = shapeshiftedPieces.filter {$0.2 == 0}
        for rev in revertShape {
            // revert piece type
            if let p = board[rev.0.row][rev.0.col], p.color == currentPlayer.color || p.color == currentPlayer.opposite.color {
                board[rev.0.row][rev.0.col] = ChessPiece(type: rev.1, color: p.color)
            }
        }
        shapeshiftedPieces.removeAll(where: {$0.2 == 0})

        // Royal Jester revert
        for i in royalJesterPieces.indices {
            royalJesterPieces[i].2 -= 1
        }
        let revertJester = royalJesterPieces.filter {$0.2 == 0}
        for rj in revertJester {
            if let p = board[rj.0.row][rj.0.col], p.type == .pawn {
                board[rj.0.row][rj.0.col] = ChessPiece(type: rj.1, color: p.color)
            }
        }
        royalJesterPieces.removeAll(where: {$0.2 == 0})

        // Blitz Surge: lasts 1 turn
        if currentPlayer == .playerOne && blitzSurgeForWhite > 0 {
            blitzSurgeForWhite -= 1
        } else if currentPlayer == .playerTwo && blitzSurgeForBlack > 0 {
            blitzSurgeForBlack -= 1
        }

        // Ancient Guardian
        for i in ancientGuardianPieces.indices {
            ancientGuardianPieces[i].1 -= 1
        }
        ancientGuardianPieces = ancientGuardianPieces.filter {$0.1 > 0}

        checkForKingCapture()
        checkForAllPiecesCaptured()
    }
    
    private func checkForKingCapture() {
        let whiteKingExists = pieceExists(.king, .white)
        let blackKingExists = pieceExists(.king, .black)
        
        if !whiteKingExists {
            gameOverMessage = "Black wins!"
            showGameOverAlert = true
        } else if !blackKingExists {
            gameOverMessage = "White wins!"
            showGameOverAlert = true
        }
    }
    
    private func pieceExists(_ type: PieceType, _ color: PieceColor) -> Bool {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.type == type, piece.color == color {
                    return true
                }
            }
        }
        return false
    }
    
    private func decrementCooldowns(for powerUps: inout [PowerUp]) {
        for i in powerUps.indices {
            if powerUps[i].cooldown > 0 {
                powerUps[i].cooldown -= 1
            }
        }
    }
    
    private func explodeAt(row: Int, col: Int) {
        for r in max(0, row-1)...min(7, row+1) {
            for c in max(0, col-1)...min(7, col+1) {
                board[r][c] = nil
            }
        }
    }
    
    private func validMoves(for pos: Position) -> [Position] {
        guard let piece = board[pos.row][pos.col] else { return [] }
        
        if mindControlActive, let enemy = mindControlSelectedEnemy, enemy == pos {
            // Treat as current player's piece (already done by color check)
        }

        let isWhite = (piece.color == .white)
        let knightsAsQueens = ((isWhite && knightsMoveLikeQueensForWhite > 0) || (!isWhite && knightsMoveLikeQueensForBlack > 0)) && piece.type == .knight
        let isTransformedRook = isTransformedIntoRook(pos, piece.color)
        let pawnsAsRooks = (piece.type == .pawn) && ((isWhite && allPawnsRookForWhite > 0) || (!isWhite && allPawnsRookForBlack > 0))

        let pawnderActive = (piece.color == .white && pawnderThatForWhite > 0) || (piece.color == .black && pawnderThatForBlack > 0)
        
        let moves: [Position] = {
            if pawnderActive && piece.type == .pawn {
                return queenMoves(pos: pos, piece: piece)
            } else if knightsAsQueens {
                return queenMoves(pos: pos, piece: piece)
            } else if isTransformedRook {
                return rookMoves(pos: pos, piece: piece)
            } else if pawnsAsRooks {
                return rookMoves(pos: pos, piece: piece)
            } else {
                switch piece.type {
                case .pawn:
                    return pawnMoves(pos: pos, piece: piece)
                case .rook:
                    return rookMoves(pos: pos, piece: piece)
                case .knight:
                    return knightMoves(pos: pos, piece: piece)
                case .bishop:
                    return bishopMoves(pos: pos, piece: piece)
                case .queen:
                    return queenMoves(pos: pos, piece: piece)
                case .king:
                    return kingMoves(pos: pos, piece: piece)
                }
            }
        }()

        // Ancient Guardian cannot move
        if ancientGuardianPieces.contains(where: {$0.0 == pos}) {
            return []
        }

        return moves
    }
    
    private func isPieceFrozen(_ pos: Position) -> Bool {
        return frozenEnemyPieces.contains(where: { $0.0 == pos && $0.1 > 0 })
    }
    
    private func isPieceOutBlocked(_ pos: Position) -> Bool {
        return pieceOutEffects.contains(where: { $0.0 == pos && $0.1 > 0 })
    }
    
    private func isTransformedIntoRook(_ pos: Position, _ color: PieceColor) -> Bool {
        if color == .white {
            return rookRollTransformedPiecesWhite.contains(where: {$0.0 == pos})
        } else {
            return rookRollTransformedPiecesBlack.contains(where: {$0.0 == pos})
        }
    }
    
    private func pawnMoves(pos: Position, piece: ChessPiece) -> [Position] {
        let direction: Int = piece.color == .white ? -1 : 1
        let startRow = piece.color == .white ? 6 : 1
        var moves: [Position] = []
        
        if !ironBootsAffectedPawns.contains(pos) {
            let forwardOne = Position(row: pos.row + direction, col: pos.col)
            if inBounds(forwardOne.row, forwardOne.col) && board[forwardOne.row][forwardOne.col] == nil {
                moves.append(forwardOne)
                let forwardTwo = Position(row: pos.row + direction*2, col: pos.col)
                if pos.row == startRow && inBounds(forwardTwo.row, forwardTwo.col) && board[forwardTwo.row][forwardTwo.col] == nil {
                    moves.append(forwardTwo)
                }
            }
        }
        
        let diagPositions = [
            Position(row: pos.row + direction, col: pos.col - 1),
            Position(row: pos.row + direction, col: pos.col + 1)
        ]
        
        let pawndimoniumActive = (piece.color == .white && pawndimoniumActiveForWhite) || (piece.color == .black && pawndimoniumActiveForBlack)
        if pawndimoniumActive {
            let kingOffsets = [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]
            for off in kingOffsets {
                let r = pos.row + off.0
                let c = pos.col + off.1
                if inBounds(r,c), let cap = board[r][c], cap.color != piece.color {
                    moves.append(Position(row:r,col:c))
                }
            }
        } else {
            for dp in diagPositions {
                if inBounds(dp.row, dp.col), let cap = board[dp.row][dp.col], cap.color != piece.color {
                    moves.append(dp)
                }
            }
        }
        
        return moves
    }
    
    private func rookMoves(pos: Position, piece: ChessPiece) -> [Position] {
        var moves: [Position] = []
        let directions = [(1,0),(-1,0),(0,1),(0,-1)]
        for d in directions {
            var r = pos.row + d.0
            var c = pos.col + d.1
            while inBounds(r, c) {
                if board[r][c] == nil {
                    moves.append(Position(row: r, col: c))
                } else {
                    if board[r][c]!.color != piece.color {
                        moves.append(Position(row: r, col: c))
                    }
                    break
                }
                r += d.0
                c += d.1
            }
        }
        return moves
    }
    
    private func knightMoves(pos: Position, piece: ChessPiece) -> [Position] {
        var moves: [Position] = []
        let offsets = [(2,1),(2,-1),(-2,1),(-2,-1),(1,2),(1,-2),(-1,2),(-1,-2)]
        for off in offsets {
            let r = pos.row + off.0
            let c = pos.col + off.1
            if inBounds(r,c) && !isOccupiedBySameColor(position: Position(row: r, col: c), color: piece.color) {
                moves.append(Position(row: r, col: c))
            }
        }
        return moves
    }
    
    private func bishopMoves(pos: Position, piece: ChessPiece) -> [Position] {
        var moves: [Position] = []
        let directions = [(1,1),(1,-1),(-1,1),(-1,-1)]
        for d in directions {
            var r = pos.row + d.0
            var c = pos.col + d.1
            while inBounds(r, c) {
                if board[r][c] == nil {
                    moves.append(Position(row: r, col: c))
                } else {
                    if board[r][c]!.color != piece.color {
                        moves.append(Position(row: r, col: c))
                    }
                    break
                }
                r += d.0
                c += d.1
            }
        }
        return moves
    }
    
    private func queenMoves(pos: Position, piece: ChessPiece) -> [Position] {
        return rookMoves(pos: pos, piece: piece) + bishopMoves(pos: pos, piece: piece)
    }
    
    private func kingMoves(pos: Position, piece: ChessPiece) -> [Position] {
        var moves: [Position] = []
        let offsets = [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]
        for off in offsets {
            let r = pos.row + off.0
            let c = pos.col + off.1
            if inBounds(r,c) && !isOccupiedBySameColor(position: Position(row: r, col: c), color: piece.color) {
                moves.append(Position(row: r, col: c))
            }
        }
        return moves
    }
    
    private func isOccupiedBySameColor(position: Position, color: PieceColor) -> Bool {
        if let piece = board[position.row][position.col] {
            return piece.color == color
        }
        return false
    }
    
    private func inBounds(_ r: Int, _ c: Int) -> Bool {
        return r >= 0 && r < 8 && c >= 0 && c < 8
    }
    
    private func rollNewPowerUps(count: Int) -> [PowerUp] {

        var result: [PowerUp] = []
        for _ in 0..<count {
            let roll = Double.random(in: 0...1)
            if roll < 0.05 {
                let (name, desc, rarity) = exoticPowers.randomElement()!
                result.append(PowerUp(name: name, description: desc, rarity: rarity, cooldown: 0))
            } else if roll < 0.6 {
                let (name, desc, rarity) = rarePowers.randomElement()!
                result.append(PowerUp(name: name, description: desc, rarity: rarity, cooldown: 0))
            } else if roll < 0.9 {
                let (name, desc, rarity) = epicPowers.randomElement()!
                result.append(PowerUp(name: name, description: desc, rarity: rarity, cooldown: 0))
            } else {
                let (name, desc, rarity) = legendaryPowers.randomElement()!
                result.append(PowerUp(name: name, description: desc, rarity: rarity, cooldown: 0))
            }
        }
        return result
    }
    
    private func cooldownForRarity(_ rarity: String) -> Int {
        switch rarity {
        case "Rare": return 4
        case "Epic": return 6
        case "Legendary": return 9
        case "Exotic": return 12
        default: return 3
        }
    }
    
    private func activatePowerUp(for player: Player, index: Int) {
        if gameMode == .singleplayer && player == .playerTwo {
            return
        }
        if player == .playerOne {
            applyPowerUp(&playerOnePowerUps[index], for: .playerOne)
        } else {
            applyPowerUp(&playerTwoPowerUps[index], for: .playerTwo)
        }
    }
    
    private func applyPowerUp(_ powerUp: inout PowerUp, for player: Player) {
        switch powerUp.name {
        case "Atomicus!":
            if player == .playerOne { atomicusActiveForWhite = true } else { atomicusActiveForBlack = true }
        case "Extra Turn":
            if player == .playerOne { extraTurnActiveForWhite = true } else { extraTurnActiveForBlack = true }
        case "Triple Turn":
            if player == .playerOne { tripleTurnActiveForWhite = true; tripleWhiteTurn = 0 } else { tripleTurnActiveForBlack = true; tripleBlackTurn = 0 }
        case "Pawndimonium":
            if player == .playerOne { pawndimoniumActiveForWhite = true } else { pawndimoniumActiveForBlack = true }
        case "Pawnzilla":
            spawnExtraPawn(for: player)
        case "Backpedal":
            backpedalMove(for: player)
        case "Pawndemic":
            pawndemicEffect(for: player)
        case "Swap 'n' Go":
            swapAndGo(for: player)
        case "Port-A-Piece":
            portAPiece(for: player)
        case "Reboot":
            rebootPawn(for: player)
        case "Copycat":
            copycatMove(for: player)
        case "Pawno-Kinetic":
            pawnoKineticEffect(for: player)
        case "Frozen Assets":
            freezeAllEnemyQueensAndRooks(for: player)
        case "Knightmare Fuel":
            if player == .playerOne { knightsMoveLikeQueensForWhite = 1 } else { knightsMoveLikeQueensForBlack = 1 }
        case "Piece Out":
            pieceOutSelectionActive = true
            pieceOutSelectingPlayer = player
        case "King's Sacrifice":
            if player == .playerOne { kingDeactivatedForWhite = 2 } else { kingDeactivatedForBlack = 2 }
            removeMultipleEnemyPieces(for: player, count: 2)
        case "Rook 'n' Roll":
            transformTwoPiecesIntoRooks(for: player)
        case "Puppet Strings":
            puppetStrings(for: player)
        case "Grand Finale":
            if player == .playerOne { grandFinaleForWhite = 3 } else { grandFinaleForBlack = 3 }
        case "Rookie Mistake":
            if player == .playerOne { allPawnsRookForWhite = 2 } else { allPawnsRookForBlack = 2 }
        case "Check That Out":
            checkThatOutDouble(for: player)
        case "I Ocean You":
            iOceanYou(for: player)
        case "TimeStop":
            timeStopModified(for: player)
        case "Shield Wall":
            if player == .playerOne { shieldWallForWhite = 1 } else { shieldWallForBlack = 1 }
        case "Teleportation":
            teleportSelectionActive = true
            teleportSelectingPlayer = player
            teleportPhase = 1
        case "Iron Boots":
            ironBoots(for: player)
        case "Bargain Hunter":
            bargainHunterModified(for: player)
        case "Shoot, Where, Where?":
            shootSelectionActive = true
            shootSelectingPlayer = player
            shootPhase = 1
        case "It Says Gullible":
            gullibleSelectionActive = true
            gullibleSelectingPlayer = player
            gulliblePhase = 1

        // NEW LEGENDARY/EXOTIC done above

        // ADDED NEW EPIC POWERS:
        case "Shapeshifter":
            shapeshifterSelectionActive = true
            shapeshifterSelectingPlayer = player
            shapeshifterPhase = 1
        case "Royal Jester":
            royalJesterSelectionActive = true
            royalJesterSelectingPlayer = player
            royalJesterPhase = 1
        case "Blitz Surge":
            blitzSurge(for: player)
        case "Ancient Guardian":
            ancientGuardianSelectionActive = true
            ancientGuardianSelectingPlayer = player
            ancientGuardianPhase = 1
        case "Mind Control":
            mindControlSelectionActive = true
            mindControlSelectingPlayer = player
            mindControlPhase = 1

        default:
            break
        }
        
        powerUp.cooldown = cooldownForRarity(powerUp.rarity)
    }

    private func blitzSurge(for player: Player) {
        // Teleport 3 of your own pieces to empty squares on your side
        // PlayerOne = white side rows 4..7, PlayerTwo = black side rows 0..3
        let rowsRange = (player == .playerOne) ? 4...7 : 0...3
        var playerPieces: [Position] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == player.color {
                    playerPieces.append(Position(row: r, col: c))
                }
            }
        }
        playerPieces.shuffle()

        var emptyPositions: [Position] = []
        for r in rowsRange {
            for c in 0..<8 {
                if board[r][c] == nil {
                    emptyPositions.append(Position(row: r, col: c))
                }
            }
        }
        emptyPositions.shuffle()

        let toMove = playerPieces.prefix(3)
        for (i,pos) in toMove.enumerated() {
            if i < emptyPositions.count {
                let target = emptyPositions[i]
                board[target.row][target.col] = board[pos.row][pos.col]
                board[pos.row][pos.col] = nil
            }
        }

        if player == .playerOne {
            blitzSurgeForWhite = 1
        } else {
            blitzSurgeForBlack = 1
        }
    }

    
    private func clearInFront(of pos: Position, for color: PieceColor) {
        let direction = (color == .white) ? -1 : 1
        var r = pos.row + direction
        let c = pos.col
        while inBounds(r,c) {
            board[r][c] = nil
            r += direction
        }
    }
    
    private func freezeAreaAround(pos: Position, turns: Int) {
        for rr in max(0, pos.row-1)...min(7, pos.row+1) {
            for cc in max(0, pos.col-1)...min(7, pos.col+1) {
                if let _ = board[rr][cc] {
                    frozenEnemyPieces.append((Position(row:rr,col:cc), turns))
                }
            }
        }
    }

    private func freezeAround(pos: Position, for player: Player, turns: Int) {
        let enemyColor = (player.color == .white) ? PieceColor.black : PieceColor.white
        for rr in max(0, pos.row-1)...min(7, pos.row+1) {
            for cc in max(0, pos.col-1)...min(7, pos.col+1) {
                if let p = board[rr][cc], p.color == enemyColor {
                    frozenEnemyPieces.append((Position(row: rr, col: cc), turns))
                }
            }
        }
    }

    private func timeStopModified(for player: Player) {
        let enemyColor: PieceColor = (player.color == .white) ? .black : .white
        var enemyPositions: [Position] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == enemyColor {
                    enemyPositions.append(Position(row:r,col:c))
                }
            }
        }
        enemyPositions.shuffle()
        let freezeCount = Int(Double(enemyPositions.count) * 0.9)
        for i in 0..<freezeCount {
            frozenEnemyPieces.append((enemyPositions[i],2))
        }
    }
    
    private func ironBoots(for player: Player) {
        let enemyColor: PieceColor = (player == .playerOne) ? .black : .white
        var enemyPawns: [Position] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == enemyColor, p.type == .pawn {
                    enemyPawns.append(Position(row: r, col: c))
                }
            }
        }
        enemyPawns.shuffle()
        for p in enemyPawns.prefix(3) {
            ironBootsAffectedPawns.append(p)
        }
    }

    private func bargainHunterModified(for player: Player) {
        let newUps = rollNewPowerUps(count: 3)
        if player == .playerOne {
            playerOnePowerUps = newUps
        } else {
            playerTwoPowerUps = newUps
        }
        
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], (p.type == .bishop || p.type == .knight) {
                    board[r][c] = nil
                }
            }
        }
        
        board[7][1] = ChessPiece(type: .knight, color: .white)
        board[7][6] = ChessPiece(type: .knight, color: .white)
        board[7][2] = ChessPiece(type: .bishop, color: .white)
        board[7][5] = ChessPiece(type: .bishop, color: .white)
        
        board[0][1] = ChessPiece(type: .knight, color: .black)
        board[0][6] = ChessPiece(type: .knight, color: .black)
        board[0][2] = ChessPiece(type: .bishop, color: .black)
        board[0][5] = ChessPiece(type: .bishop, color: .black)
    }
    
    private func puppetStrings(for player: Player) {
        let enemyColor: PieceColor = (player.color == .white) ? .black : .white
        let playerColor = player.color
        var enemyCandidates: [(Position, ChessPiece)] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == enemyColor, (p.type == .knight || p.type == .bishop) {
                    enemyCandidates.append((Position(row:r,col:c), p))
                }
            }
        }
        if enemyCandidates.isEmpty { return }
        
        var playerPawns: [Position] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let pp = board[r][c], pp.color == playerColor, pp.type == .pawn {
                    playerPawns.append(Position(row:r,col:c))
                }
            }
        }
        if playerPawns.isEmpty { return }
        
        let enemyToMove = enemyCandidates[0].0
        if let closestPawn = playerPawns.min(by: {dist($0,enemyToMove) < dist($1,enemyToMove)}) {
            let diagonals = [(1,1),(1,-1),(-1,1),(-1,-1)]
            for d in diagonals {
                let nr = closestPawn.row + d.0
                let nc = closestPawn.col + d.1
                if inBounds(nr,nc) && board[nr][nc] == nil {
                    board[nr][nc] = board[enemyToMove.row][enemyToMove.col]
                    board[enemyToMove.row][enemyToMove.col] = nil
                    break
                }
            }
        }
    }
    
    private func dist(_ a: Position, _ b: Position) -> Int {
        return abs(a.row - b.row) + abs(a.col - b.col)
    }
    
    private func spawnExtraPawn(for player: Player) {
        if let (r,c) = findPawn(for: player) {
            if let freeCol = findFreeCol(inRow: r) {
                board[r][freeCol] = ChessPiece(type: .pawn, color: player.color)
            }
        }
    }
    
    private func findPawn(for player: Player) -> (Int, Int)? {
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == player.color, p.type == .pawn {
                    return (r,c)
                }
            }
        }
        return nil
    }
    
    private func findFreeCol(inRow row: Int) -> Int? {
        for c in 0..<8 {
            if board[row][c] == nil {
                return c
            }
        }
        return nil
    }
    
    private func backpedalMove(for player: Player) {
        let direction = (player == .playerOne) ? 1 : -1
        if let pos = findPieceForPlayer(player) {
            let newPos = Position(row: pos.row + direction, col: pos.col)
            if inBounds(newPos.row, newPos.col) && board[newPos.row][newPos.col] == nil {
                board[newPos.row][newPos.col] = board[pos.row][pos.col]
                board[pos.row][pos.col] = nil
            }
        }
    }
    
    private func findPieceForPlayer(_ player: Player) -> Position? {
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == player.color {
                    return Position(row: r, col: c)
                }
            }
        }
        return nil
    }
    
    private func pawndemicEffect(for player: Player) {
        if let (r,c) = findPawn(for: player) {
            let direction = (player == .playerOne) ? 1 : -1
            let newRow = r + direction
            if inBounds(newRow, c) && board[newRow][c] == nil {
                board[newRow][c] = board[r][c]
                board[r][c] = nil
                for dc in [-1,1] {
                    let adjCol = c+dc
                    if inBounds(newRow, adjCol), let enemy = board[newRow][adjCol], enemy.color != player.color {
                        board[newRow][adjCol] = nil
                    }
                }
            }
        }
    }
    
    private func swapAndGo(for player: Player) {
        var positions: [Position] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == player.color {
                    positions.append(Position(row: r, col: c))
                }
            }
        }
        if positions.count >= 2 {
            let pos1 = positions[0]
            let pos2 = positions[1]
            let temp = board[pos1.row][pos1.col]
            board[pos1.row][pos1.col] = board[pos2.row][pos2.col]
            board[pos2.row][pos2.col] = temp
        }
    }
    
    private func portAPiece(for player: Player) {
        if let pos = findPieceForPlayer(player), let free = findFirstFreeSquare() {
            board[free.row][free.col] = board[pos.row][pos.col]
            board[pos.row][pos.col] = nil
        }
    }
    
    private func findFirstFreeSquare() -> Position? {
        for r in 0..<8 {
            for c in 0..<8 {
                if board[r][c] == nil {
                    return Position(row: r, col: c)
                }
            }
        }
        return nil
    }
    
    private func rebootPawn(for player: Player) {
        let backRow = player == .playerOne ? 7 : 0
        if let freeCol = findFreeCol(inRow: backRow) {
            board[backRow][freeCol] = ChessPiece(type: .pawn, color: player.color)
        }
    }
    
    private func copycatMove(for player: Player) {
        let direction = player == .playerOne ? -1 : 1
        var pawns: [(Int,Int)] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == player.color, p.type == .pawn {
                    pawns.append((r,c))
                }
            }
        }
        var movesDone = 0
        for (r,c) in pawns {
            if movesDone == 2 { break }
            let nr = r+direction
            if inBounds(nr,c) && board[nr][c] == nil {
                board[nr][c] = board[r][c]
                board[r][c] = nil
                movesDone += 1
            }
        }
    }
    
    private func pawnoKineticEffect(for player: Player) {
        let direction = player == .playerOne ? -1 : 1
        let rows = direction == -1 ? Array(0..<8) : Array((0..<8).reversed())
        for r in rows {
            for c in 0..<8 {
                if let p = board[r][c], p.color == player.color, p.type == .pawn {
                    let nr = r+direction*2
                    if inBounds(nr,c) && board[nr][c] == nil {
                        board[nr][c] = p
                        board[r][c] = nil
                    }
                }
            }
        }
    }
    
    private func freezeAllEnemyQueensAndRooks(for player: Player) {
        let enemyColor = player == .playerOne ? PieceColor.black : PieceColor.white
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == enemyColor, (p.type == .queen || p.type == .rook) {
                    frozenEnemyPieces.append((Position(row:r,col:c), 2))
                }
            }
        }
    }
    
    private func removeMultipleEnemyPieces(for player: Player, count: Int) {
        for _ in 0..<count {
            removeRandomEnemyPiece(for: player)
        }
    }
    
    private func findKing(for color: PieceColor) -> Position? {
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == color, p.type == .king {
                    return Position(row: r, col: c)
                }
            }
        }
        return nil
    }
    
    private func checkThatOutDouble(for player: Player) {
        let enemyColor = player == .playerOne ? PieceColor.black : PieceColor.white
        if let kingPos = findKing(for: enemyColor) {
            var candidates: [Position] = []
            for rr in max(0, kingPos.row-1)...min(7, kingPos.row+1) {
                for cc in max(0, kingPos.col-1)...min(7, kingPos.col+1) {
                    if !(rr == kingPos.row && cc == kingPos.col), board[rr][cc] != nil {
                        candidates.append(Position(row: rr, col: cc))
                    }
                }
            }
            candidates.shuffle()
            for i in 0..<min(2, candidates.count) {
                let target = candidates[i]
                board[target.row][target.col] = nil
            }
        }
    }
    
    private func iOceanYou(for player: Player) {
        let enemyColor = player == .playerOne ? PieceColor.black : PieceColor.white
        var enemyPawns: [Position] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == enemyColor, p.type == .pawn {
                    enemyPawns.append(Position(row: r, col: c))
                }
            }
        }
        enemyPawns.shuffle()
        for i in 0..<min(4, enemyPawns.count) {
            let pos = enemyPawns[i]
            board[pos.row][pos.col] = nil
        }
    }
    
    private func deactivatePawndimonium(for player: Player) {
        if player == .playerOne {
            pawndimoniumActiveForWhite = false
        } else {
            pawndimoniumActiveForBlack = false
        }
    }
    
    private func isPawnCaptureMoveLike(from: Position, to: Position, piece: ChessPiece) -> Bool {
        guard let targetPiece = board[to.row][to.col], targetPiece.color != piece.color else {
            return false
        }
        let direction: Int = piece.color == .white ? -1 : 1
        if to.row == from.row + direction && (to.col == from.col + 1 || to.col == from.col - 1) {
            return true
        }
        return false
    }
    
    private func pieceSymbol(_ piece: ChessPiece) -> String {
        switch (piece.type, piece.color) {
        case (.pawn, .white): return "♟︎"
        case (.rook, .white): return "♜"
        case (.knight, .white): return "♞"
        case (.bishop, .white): return "♝"
        case (.queen, .white): return "♛"
        case (.king, .white): return "♚"
        case (.pawn, .black): return "♟︎"
        case (.rook, .black): return "♜"
        case (.knight, .black): return "♞"
        case (.bishop, .black): return "♝"
        case (.queen, .black): return "♛"
        case (.king, .black): return "♚"
        }
    }
    
    private func advanceFrozenTurns() {
        for i in frozenEnemyPieces.indices {
            if frozenEnemyPieces[i].1 > 0 {
                frozenEnemyPieces[i].1 -= 1
            }
        }
        frozenEnemyPieces = frozenEnemyPieces.filter {$0.1 > 0}
    }
    
    private func advancePieceOutEffects() {
        for i in pieceOutEffects.indices {
            if pieceOutEffects[i].1 > 0 {
                pieceOutEffects[i].1 -= 1
            }
        }
        pieceOutEffects = pieceOutEffects.filter {$0.1 > 0}
    }
    
    private func removeRandomEnemyPiece(for player: Player) {
        let enemyColor = player == .playerOne ? PieceColor.black : PieceColor.white
        var enemyPieces: [Position] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == enemyColor {
                    enemyPieces.append(Position(row: r, col: c))
                }
            }
        }
        if !enemyPieces.isEmpty {
            let target = enemyPieces.randomElement()!
            board[target.row][target.col] = nil
        }
    }
    
    private func transformTwoPiecesIntoRooks(for player: Player) {
        var playerPieces: [(Position, ChessPiece)] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == player.color {
                    playerPieces.append((Position(row:r,col:c), p))
                }
            }
        }
        
        var pawns = playerPieces.filter {$0.1.type == .pawn}
        if pawns.count < 2 {
            pawns.append(contentsOf: playerPieces.filter {$0.1.type != .pawn})
        }
        
        pawns.shuffle()
        let toTransform = pawns.prefix(2)
        
        for (pos, piece) in toTransform {
            if player == .playerOne {
                rookRollTransformedPiecesWhite.append((pos, piece.type))
            } else {
                rookRollTransformedPiecesBlack.append((pos, piece.type))
            }
        }
        
        if player == .playerOne {
            rookRollForWhite = 1
        } else {
            rookRollForBlack = 1
        }
    }
    
    private func doBotTurnIfNeeded() {
        guard gameMode == .singleplayer && currentPlayer == .playerTwo && !showGameOverAlert else { return }
        
        var usablePowers = playerTwoPowerUps.enumerated().filter { $0.element.cooldown == 0 }
        usablePowers.shuffle()
        
        if let (idx, pow) = usablePowers.first(where: { !["Piece Out","Teleportation","Shoot, Where, Where?","It Says Gullible","Aura","Lock In","Reaper","Shapeshifter","Royal Jester","Blitz Surge","Ancient Guardian","Mind Control"].contains($0.element.name) }) {
            applyPowerUp(&playerTwoPowerUps[idx], for: .playerTwo)
        }
        
        let moves = allPossibleMoves(for: .black)
        if let randomMove = moves.randomElement() {
            movePiece(from: randomMove.0, to: randomMove.1)
        } else {
            handleMoveEnd()
        }
    }
    
    private func allPossibleMoves(for color: PieceColor) -> [(Position, Position)] {
        var result: [(Position,Position)] = []
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == color {
                    let fromPos = Position(row: r, col: c)
                    let moves = validMoves(for: fromPos)
                    for m in moves {
                        result.append((fromPos, m))
                    }
                }
            }
        }
        return result
    }
    
    private func countPieces(for color: PieceColor) -> Int {
        var count = 0
        for row in 0..<8 {
            for col in 0..<8 {
                if let p = board[row][col], p.color == color {
                    count += 1
                }
            }
        }
        return count
    }
    
    private func checkForAllPiecesCaptured() {
        let whitePieces = countPieces(for: .white)
        let blackPieces = countPieces(for: .black)
        
        if whitePieces == 0 && blackPieces == 0 {
            gameOverMessage = "It's a draw!"
            showGameOverAlert = true
        } else if whitePieces == 0 {
            gameOverMessage = "Black wins by capturing all white pieces!"
            showGameOverAlert = true
        } else if blackPieces == 0 {
            gameOverMessage = "White wins by capturing all black pieces!"
            showGameOverAlert = true
        }
    }

    private func isReaperPiece(_ piece: ChessPiece) -> Bool {
        return reaperPieces.contains(piece.id)
    }

    private func applyReaperEffect(for player: Player) {
        let direction = (player == .playerOne) ? -1 : 1
        for reaperID in reaperPieces {
            if let (pos,p) = findPieceByID(reaperID), p.color == player.color {
                let frontRow = pos.row + direction
                if inBounds(frontRow, pos.col) {
                    for cc in max(0,pos.col-1)...min(7,pos.col+1) {
                        board[frontRow][cc] = nil
                    }
                }
            }
        }
    }

    private func findPieceByID(_ id: UUID) -> (Position,ChessPiece)? {
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.id == id {
                    return (Position(row:r,col:c), p)
                }
            }
        }
        return nil
    }

}
