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
    
    // MARK: - Modified PowerUp Pools with new abilities
    // 1 Legendary: "TimeStop"
    // 2 Epic: "Shield Wall", "Teleportation"
    // 2 Rare: "Iron Boots", "Bargain Hunter"
    // ADDED: Exotic Powers
    
    var rarePowers = [
        ("Extra Turn", "Lets you take two consecutive moves before the turn passes to your opponent.", "Rare"),
        ("Pawnzilla", "Finds one of your pawns and spawns a second pawn in the same row if space is available.", "Rare"),
        ("Backpedal", "Moves one of your pieces backward by one square if the space is free.", "Rare"),
        ("Pawndemic", "Selects one of your pawns, moves it backward by one square, and captures any adjacent enemy pieces.", "Rare"),
        ("Swap 'n' Go", "Swaps the positions of two of your own pieces.", "Rare"),
        ("Port-A-Piece", "Teleports one of your pieces to the first available free square found (top-left search).", "Rare"),
        ("Reboot", "Brings back a new pawn in your back row if space is available (like resurrecting a captured pawn).", "Rare"),
        ("Copycat", "Moves two of your pawns forward one square each, if possible.", "Rare"),
        ("Iron Boots", "Prevents 3 random enemy pawns from moving forward this turn. 🥾 symbol on affected pawns", "Rare"),
        ("Bargain Hunter", "Resets all your bishops and knights to their original positions and refreshes your powers.", "Rare")
    ]
    
    var epicPowers = [
        ("Pawndimonium", "Your pawns can capture like a king for your next capture. 🤴 symbol on pawns.", "Epic"),
        ("Frozen Assets", "Freezes all enemy queens and rooks for TWO turns now, preventing them from moving. A ❄️ symbol will appear on them.", "Epic"),
        ("Knightmare Fuel", "All your knights move like queens for one turn and show a 👑 symbol.", "Epic"),
        ("Piece Out", "Select an enemy piece to remove immediately.", "Epic"),
        ("King's Sacrifice", "Your king cannot move for 2 rounds, and you delete 2 random enemy pieces instantly. Your king is marked with ⛔ symbol.", "Epic"),
        ("Rook 'n' Roll", "Two of your pieces move like rooks for one turn. 🗼 symbol shown.", "Epic"),
        ("Puppet Strings", "Moves an enemy knight or bishop next to your closest pawn diagonally so it can be captured.", "Epic"),
        ("Grand Finale", "Over the next 3 turns, one random enemy piece is killed each turn.", "Epic"),
        ("Triple Turn", "Allows you to take three consecutive moves before your opponent's turn.", "Epic"),
        ("Pawno-Kinetic", "Moves all your pawns forward two squares if the spaces are free.", "Epic"),
        ("Shield Wall", "Protect all your pieces from being captured for 1 turn. 🛡️ symbol shown on your pieces.", "Epic"),
        ("Teleportation", "Choose one of your pieces and then choose an empty square to teleport it there.", "Epic")
    ]
    
    var legendaryPowers = [
        ("Atomicus!", "If one of your pieces is captured, it explodes and removes surrounding pieces in a 3x3 area.", "Legendary"),
        ("Rookie Mistake", "All your pawns move like rooks for 2 rounds. 🚀 symbol shown on them.", "Legendary"),
        ("Check That Out", "Deletes two random pieces around the enemy's king.", "Legendary"),
        ("I Ocean You", "Captures up to four random enemy pawns in a single wave.", "Legendary"),
        ("TimeStop", "Freezes 90% of enemy pieces for 2 turns.", "Legendary")
    ]
    
    // ADDED: Exotic Powers
    var exoticPowers = [
        ("Shoot, Where, Where?", "Allows you to choose one of your own pieces, and all squares directly in front of that piece (in the piece’s forward direction) will be cleared of any pieces.", "Exotic"),
        ("It Says Gullible", "Allows you to choose an enemy piece, and the 3x3 area around that piece will be frozen for 5 moves (show a 🥶 symbol).", "Exotic")
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


    var body: some View {
        // ADDED: Main content now depends on gameMode
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
    
    // ADDED: Main menu view
    private var menuView: some View {
        VStack {
            Text("Ultimate Chess Royale")
                .font(.largeTitle)
                .padding()
            
            Image("logo") // Assuming logo.png is in assets
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .cornerRadius(10)
                .padding(20)
            
            Text("Play Options")
                .font(.headline)
     
            
            Text(tips[currentTipIndex])
                .font(.subheadline)
                .padding()
                .multilineTextAlignment(.center)
                // Every 3 seconds, update the currentTipIndex
                .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                    currentTipIndex = (currentTipIndex + 1) % tips.count
                }
            
            Button("Play Online 1v1") {
                // Set up singleplayer mode (White = Human, Black = Bot)
                setupInitialBoard()
                playerOnePowerUps = rollNewPowerUps(count: 3)
                playerTwoPowerUps = rollNewPowerUps(count: 3)
                currentPlayer = .playerOne
                gameMode = .singleplayer
            }
            .padding()
            .background(Color.green.opacity(0.3))
            .cornerRadius(10)
            
            Button("2 Player Mode") {
                // This is the original mode
                setupInitialBoard()
                playerOnePowerUps = rollNewPowerUps(count: 3)
                playerTwoPowerUps = rollNewPowerUps(count: 3)
                currentPlayer = .playerOne
                gameMode = .multiplayer
            }
            .padding()
            .background(Color.blue.opacity(0.3))
            .cornerRadius(10)
            
            Button("Power Catalog") {
                gameMode = .catalog
            }
            .padding()
            .background(Color.purple.opacity(0.3))
            .cornerRadius(10)
            
            
            Spacer()
        }
        .padding()
    }
    
    private var singlePlayerView: some View {
        VStack {
            Button("Singleplayer: Return To Menu") {
                gameMode = .menu
            }
            .multilineTextAlignment(.center)

            
            Spacer()
            
            VStack {
                Text("Black's Power-Ups (Bot)").font(.headline)
                powerUpBar(for: .playerTwo, powerUps: $playerTwoPowerUps, rollsLeft: $playerTwoRollsLeft)
            }
            .rotationEffect(.degrees(180))
            
            Spacer()
            
            boardView
            
            Spacer()
            
            VStack {
                Text("White's Power-Ups").font(.headline)
                powerUpBar(for: .playerOne, powerUps: $playerOnePowerUps, rollsLeft: $playerOneRollsLeft)
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
            .padding()
            
            VStack {
                Text("Black's Power-Ups").font(.headline)
                powerUpBar(for: .playerTwo, powerUps: $playerTwoPowerUps, rollsLeft: $playerTwoRollsLeft)
            }
            .rotationEffect(.degrees(180))
            
            Spacer()
            
            boardView
            
            Spacer()
            
            VStack {
                Text("White's Power-Ups").font(.headline)
                powerUpBar(for: .playerOne, powerUps: $playerOnePowerUps, rollsLeft: $playerOneRollsLeft)
            }
        }
        .onAppear {
            // Already handled in menu
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
            
            Text("Hold on a power to see it's description")
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
                                Text(pieceSymbol(piece))
                                    .font(.system(size: 35))
                                    .foregroundColor(piece.color == .white ? .blue : .red)
                                
                                if isPieceFrozen(Position(row: row, col: col)) {
                                    // Show ❄️ or 🥶 depending on origin of freeze
                                    // We'll show 🥶 if freeze > 2 turns or from gullible effect
                                    // For gullible we freeze 5 moves, let's distinguish by longer freeze:
                                    if let freezeInfo = frozenEnemyPieces.first(where: {$0.0 == Position(row: row, col: col)}) {
                                        if freezeInfo.1 > 2 { // If we used gullible freeze of 5 moves
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
                                
                            }
                            
                            if pieceOutSelectionActive, let piece = board[row][col], piece.color != currentPlayer.color {
                                Color.red.opacity(0.3)
                            }
                            
                            if teleportSelectionActive {
                                if teleportPhase == 1 {
                                    // Selecting piece to teleport - highlight player's pieces
                                    if let piece = board[row][col], piece.color == teleportSelectingPlayer?.color {
                                        Color.yellow.opacity(0.3)
                                    }
                                } else if teleportPhase == 2 {
                                    // Selecting destination - highlight empty squares
                                    if board[row][col] == nil {
                                        Color.yellow.opacity(0.3)
                                    }
                                }
                            }
                            
                            // ADDED: Highlighting for exotic power "Shoot, Where, Where?"
                            if shootSelectionActive {
                                if shootPhase == 1 {
                                    // Highlight user's pieces
                                    if let piece = board[row][col], piece.color == shootSelectingPlayer?.color {
                                        Color.orange.opacity(0.3)
                                    }
                                }
                            }
                            
                            // ADDED: Highlighting for exotic power "It Says Gullible"
                            if gullibleSelectionActive {
                                if gulliblePhase == 1 {
                                    // Highlight enemy pieces (to freeze area)
                                    if let piece = board[row][col], piece.color != gullibleSelectingPlayer?.color {
                                        Color.blue.opacity(0.3)
                                    }
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
    
    private func powerUpBar(for player: Player, powerUps: Binding<[PowerUp]>, rollsLeft: Binding<Int>) -> some View {
        let isCurrentPlayer = (player == currentPlayer && (gameMode != .singleplayer || player == .playerOne)) // In singleplayer only white is controlled by user
        
        return HStack {
            ForEach(powerUps.wrappedValue.indices, id: \.self) { i in
                let pUp = powerUps.wrappedValue[i]
                Button {
                    activatePowerUp(for: player, index: i)
                } label: {
                    PowerUpButtonView(powerUp: pUp)
                        .environment(\.showDescriptionAction, showDescription)

                }
                .disabled(!isCurrentPlayer || pUp.cooldown > 0 || pieceOutSelectionActive || teleportSelectionActive || shootSelectionActive || gullibleSelectionActive)
            }
            
            Button(action: {
                if rollsLeft.wrappedValue > 0 && isCurrentPlayer {
                    rollsLeft.wrappedValue -= 1
                    let newUps = rollNewPowerUps(count: 3)
                    if player == .playerOne {
                        playerOnePowerUps = newUps
                    } else {
                        playerTwoPowerUps = newUps
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
            .disabled(!isCurrentPlayer || rollsLeft.wrappedValue == 0 || pieceOutSelectionActive || teleportSelectionActive || shootSelectionActive || gullibleSelectionActive)
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
                // rainbow gradient
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
        
        // Shoot, Where, Where? selection
        if shootSelectionActive, let selPlayer = shootSelectingPlayer {
            if shootPhase == 1 {
                // Choose player's piece
                if let piece = board[row][col], piece.color == selPlayer.color {
                    shootSelectedPiece = tappedPos
                    // Perform the effect: clear everything in front of this piece
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
        
        // It Says Gullible selection
        if gullibleSelectionActive, let selPlayer = gullibleSelectingPlayer {
            if gulliblePhase == 1 {
                // Choose enemy piece
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
        
        // Shield Wall logic
        if isCapture, let defender = capturedPiece, ((defender.color == .white && shieldWallForWhite > 0) || (defender.color == .black && shieldWallForBlack > 0)) {
            // Can't capture this piece
            return
        }
        
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
        
        if currentPlayer == .playerOne && rookRollForBlack > 0 {
            rookRollForBlack = 0
            rookRollTransformedPiecesBlack.removeAll()
        } else if currentPlayer == .playerTwo && rookRollForWhite > 0 {
            rookRollForWhite = 0
            rookRollTransformedPiecesWhite.removeAll()
        }
        
        if currentPlayer == .playerOne {
            if knightsMoveLikeQueensForBlack > 0 { knightsMoveLikeQueensForBlack -= 1 }
            if allPawnsRookForBlack > 0 { allPawnsRookForBlack -= 1 }
        } else {
            if knightsMoveLikeQueensForWhite > 0 { knightsMoveLikeQueensForWhite -= 1 }
            if allPawnsRookForWhite > 0 { allPawnsRookForWhite -= 1 }
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

        checkForKingCapture()
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
        
        let isWhite = (piece.color == .white)
        let knightsAsQueens = ((isWhite && knightsMoveLikeQueensForWhite > 0) || (!isWhite && knightsMoveLikeQueensForBlack > 0)) && piece.type == .knight
        let isTransformedRook = isTransformedIntoRook(pos, piece.color)
        let pawnsAsRooks = (piece.type == .pawn) && ((isWhite && allPawnsRookForWhite > 0) || (!isWhite && allPawnsRookForBlack > 0))
        
        let moves: [Position] = {
            if knightsAsQueens {
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
            // Exotic chance: 1/20 = 0.05
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
        case "Rare": return 3
        case "Epic": return 6
        case "Legendary": return 9
        case "Exotic": return 12
        default: return 3
        }
    }
    
    private func activatePowerUp(for player: Player, index: Int) {
        // In singleplayer: If player == .playerTwo and gameMode == .singleplayer, ignore user activation (bot only)
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
            // Exotic power
            shootSelectionActive = true
            shootSelectingPlayer = player
            shootPhase = 1
        case "It Says Gullible":
            // Exotic power
            gullibleSelectionActive = true
            gullibleSelectingPlayer = player
            gulliblePhase = 1
        default:
            break
        }
        
        powerUp.cooldown = cooldownForRarity(powerUp.rarity)
    }
    
    // Exotic power: Shoot, Where, Where?
    private func clearInFront(of pos: Position, for color: PieceColor) {
        let direction = (color == .white) ? -1 : 1
        // Clear all squares in front (same column)
        var r = pos.row + direction
        let c = pos.col
        while inBounds(r,c) {
            board[r][c] = nil
            r += direction
        }
    }
    
    // Exotic power: It Says Gullible
    private func freezeAreaAround(pos: Position, turns: Int) {
        for rr in max(0, pos.row-1)...min(7, pos.row+1) {
            for cc in max(0, pos.col-1)...min(7, pos.col+1) {
                if let p = board[rr][cc] {
                    // Freeze that piece
                    frozenEnemyPieces.append((Position(row:rr,col:cc), turns))
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
        
        // Reset all bishops and knights
        for r in 0..<8 {
            for c in 0..<8 {
                if let piece = board[r][c], (piece.type == .bishop || piece.type == .knight) {
                    board[r][c] = nil
                }
            }
        }
        
        // Place white knights and bishops in original positions
        board[7][1] = ChessPiece(type: .knight, color: .white)
        board[7][6] = ChessPiece(type: .knight, color: .white)
        board[7][2] = ChessPiece(type: .bishop, color: .white)
        board[7][5] = ChessPiece(type: .bishop, color: .white)
        
        // Place black knights and bishops in original positions
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
    
    // ADDED: Bot logic for singleplayer
    private func doBotTurnIfNeeded() {
        guard gameMode == .singleplayer && currentPlayer == .playerTwo && !showGameOverAlert else { return }
        
        // Bot uses powers randomly if available
        var usablePowers = playerTwoPowerUps.enumerated().filter { $0.element.cooldown == 0 }
        usablePowers.shuffle()
        
        // If a power requires selection and is complicated, we might skip. For demonstration let's just use simple powers or random moves:
        // We'll just try a few times to pick a power that doesn't require manual selection:
        // If we pick a complex one, we skip it to avoid blocking the bot.
        // Powers that require selection: Piece Out, Teleportation, Shoot, Where, Where?, It Says Gullible
        // Let's skip those from bot usage for simplicity.
        
        if let (idx, pow) = usablePowers.first(where: { !["Piece Out","Teleportation","Shoot, Where, Where?","It Says Gullible"].contains($0.element.name) }) {
            // Use that power
            applyPowerUp(&playerTwoPowerUps[idx], for: .playerTwo)
        } else {
            // No easy power, skip power usage
        }
        
        // Make a random move
        let moves = allPossibleMoves(for: .black)
        if let randomMove = moves.randomElement() {
            movePiece(from: randomMove.0, to: randomMove.1)
        } else {
            // No moves: just end turn if possible
            handleMoveEnd()
        }
    }
    
    // Helper for bot
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
}
