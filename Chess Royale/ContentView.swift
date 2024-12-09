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
        let rarity: String // "Rare", "Epic", "Legendary"
        var cooldown: Int
        var isActive: Bool = true
    }
    
    // MARK: - Game State
    
    @State private var board: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    @State private var currentPlayer: Player = .playerOne
    @State private var selectedPosition: Position? = nil
    @State private var possibleMoves: [Position] = []
    
    // Each player’s roll count
    @State private var playerOneRollsLeft = 50
    @State private var playerTwoRollsLeft = 50
    
    // Power-up states
    @State private var playerOnePowerUps: [PowerUp] = []
    @State private var playerTwoPowerUps: [PowerUp] = []
    
    // Track if certain power-ups are currently active
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
    
    @State private var frozenEnemyPieces: [(Position, Int)] = [] // Store positions of frozen pieces and how many turns left they remain frozen
    @State private var knightsMoveLikeQueensForWhite = 0
    @State private var knightsMoveLikeQueensForBlack = 0
    @State private var pieceOutEffects: [(Position, Int, Player)] = []
    @State private var kingDeactivatedForWhite = 0
    @State private var kingDeactivatedForBlack = 0
    @State private var rookRollForWhite = 0
    @State private var rookRollForBlack = 0
    @State private var puppetStringsActiveForWhite = false
    @State private var puppetStringsActiveForBlack = false
    @State private var grandFinaleForWhite = 0
    @State private var grandFinaleForBlack = 0
    @State private var allPawnsRookForWhite = 0
    @State private var allPawnsRookForBlack = 0
    @State private var chainRemovalsForWhite = 0
    @State private var chainRemovalsForBlack = 0
    
    // A move counter just for cooldown purposes
    @State private var moveCounter: Int = 0
    
    @State private var showGameOverAlert = false
    @State private var gameOverMessage = ""
    
    @State private var showPowerUpDescription = false
    @State private var selectedPowerUpDescription: String? = nil

    
    // MARK: - PowerUp Pools
    
    let rarePowers = [
        ("Extra Turn", "Lets you take two consecutive moves before the turn passes to your opponent.", "Rare"),
        ("Pawnzilla", "Finds one of your pawns and spawns a second pawn in the same row if space is available.", "Rare"),
        ("Backpedal", "Moves one of your pieces backward by one square if the space is free.", "Rare"),
        ("Pawndemic", "Selects one of your pawns, moves it backward by one square, and captures any adjacent enemy pieces.", "Rare"),
        ("Swap 'n' Go", "Swaps the positions of two of your own pieces.", "Rare"),
        ("Port-A-Piece", "Teleports one of your pieces to the first available free square found (top-left search).", "Rare"),
        ("Reboot", "Brings back a new pawn in your back row if space is available (like resurrecting a captured pawn).", "Rare"),
        ("Copycat", "Moves two of your pawns forward one square each, if possible.", "Rare")
    ]
    
    let epicPowers = [
        ("Pawndimonium", "Your next capture can act like a pawn's diagonal capture, then the piece returns to its original square after capture.", "Epic"),
        ("Frozen Assets", "Freezes 3 enemy pieces for one turn, preventing them from moving.", "Epic"),
        ("Knightmare Fuel", "All your knights move like queens for one turn.", "Epic"),
        ("Piece Out", "Selects an enemy piece and prevents it from moving or attacking for two turns.", "Epic"),
        ("King's Sacrifice", "Removes your king from the board for 3 rounds and instantly removes one enemy piece.", "Epic"),
        ("Rook 'n' Roll", "Two of your pieces move like rooks for one turn.", "Epic"),
        ("Puppet Strings", "Allows you to control one enemy pawn for one turn.", "Epic"),
        ("Grand Finale", "Triggers a chain reaction that removes one random enemy piece each turn for the next 3 turns, after you sacrifice one of your pieces.", "Epic"),
        ("Triple Turn", "Allows you to take three consecutive moves before your opponent's turn.", "Epic"),
        ("Pawno-Kinetic", "Moves all your pawns forward two squares if the spaces are free.", "Epic")
    ]
    
    let legendaryPowers = [
        ("Atomicus!", "If one of your pieces is captured, it explodes and removes surrounding pieces in a 3x3 area.", "Legendary"),
        ("Rookie Mistake", "All your pawns move like rooks this turn.", "Legendary"),
        ("Check That Out", "Deletes one random piece around the enemy's king.", "Legendary"),
        ("I Ocean You", "Captures up to four random enemy pawns in a single wave.", "Legendary")
    ]
    
    var body: some View {
        VStack {
            // Black's power-up bar at the top, rotated 180°
            VStack {
                Text("Black's Power-Ups").font(.headline)
                powerUpBar(for: .playerTwo, powerUps: $playerTwoPowerUps, rollsLeft: $playerTwoRollsLeft)
            }
            .rotationEffect(.degrees(180))
            
            Spacer()
            
            boardView
            
            Spacer()
            
            // White's power-up bar at the bottom
            VStack {
                Text("White's Power-Ups").font(.headline)
                powerUpBar(for: .playerOne, powerUps: $playerOnePowerUps, rollsLeft: $playerOneRollsLeft)
            }
        }
        .onAppear {
            setupInitialBoard()
            // Initialize each player with random power-ups at start (cooldown=0 so they can be used immediately)
            playerOnePowerUps = rollNewPowerUps(count: 3)
            playerTwoPowerUps = rollNewPowerUps(count: 3)
        }
        .padding()
        .alert(isPresented: $showGameOverAlert) {
            Alert(
                title: Text("Game Over"),
                message: Text(gameOverMessage),
                dismissButton: .default(Text("OK")) {
                    resetGame()
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
    
    private func showDescription(_ desc: String) {
        self.selectedPowerUpDescription = desc
        self.showPowerUpDescription = true
    }

    
    private func resetGame() {
        // Reset board and states
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
        kingDeactivatedForWhite = 0
        kingDeactivatedForBlack = 0
        rookRollForWhite = 0
        rookRollForBlack = 0
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
    }
    // MARK: - Views
    
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
                                    .font(.system(size: 24))
                                    .foregroundColor(piece.color == .white ? .blue : .red)
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
        let isCurrentPlayer = (player == currentPlayer)
        
        return HStack {
            ForEach(powerUps.wrappedValue.indices, id: \.self) { i in
                let pUp = powerUps.wrappedValue[i]
                Button {
                    activatePowerUp(for: player, index: i)
                } label: {
                    PowerUpButtonView(powerUp: pUp)
                        .environment(\.showDescriptionAction, showDescription)

                }
                .disabled(!isCurrentPlayer || pUp.cooldown > 0)
            }
            
            Button(action: {
                if rollsLeft.wrappedValue > 0 {
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
            .disabled(!isCurrentPlayer || rollsLeft.wrappedValue == 0)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    struct PowerUpButtonView: View {
        let powerUp: ContentView.PowerUp
        
        @Environment(\.showDescriptionAction) var showDescriptionAction

        
        // Computed property to determine background color based on rarity
        private var backgroundColor: Color {
            switch powerUp.rarity.lowercased() {
            case "rare":
                return Color.blue
            case "epic":
                return Color.purple
            case "legendary":
                return Color.orange
            default:
                return Color.yellow // Fallback color
            }
        }
        
        var body: some View {
            VStack {
                // Power-Up Image
                Image(powerUp.name)
                    .resizable()
                    .scaledToFill() // Ensures the image fills the frame
                    .frame(width: 40, height: 40) // Adjusted size
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8)) // Rounded corners
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1) // Border
                    )
                    .clipped() // Ensures the image stays within the frame
                
                // Power-Up Name
                Text(powerUp.name)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.black) // Set text color to black
                
                // Power-Up Rarity
                Text(powerUp.rarity)
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.black) // Set text color to black
                
                // Cooldown Indicator (if applicable)
                if powerUp.cooldown > 0 {
                    Text("CD: \(powerUp.cooldown)")
                        .font(.caption2)
                        .foregroundColor(.black) // Set text color to black
                }
            }
            .padding(8)
            .background(backgroundColor.opacity(powerUp.cooldown == 0 ? 0.8 : 0.4))
            .cornerRadius(10) // Slightly increased corner radius for better aesthetics
            .onLongPressGesture(minimumDuration: 0.5) {
                showDescriptionAction(powerUp.description)
            }
        }
    }


    
    // MARK: - Setup
    
    private func setupInitialBoard() {
        // Setup standard chess
        // White (Player One)
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
        
        // Black (Player Two)
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
    
    // MARK: - Interaction
    
    private func cellTapped(row: Int, col: Int) {
        let tappedPos = Position(row: row, col: col)
        if let selected = selectedPosition {
            // A piece is already selected
            if possibleMoves.contains(tappedPos) {
                // Move
                movePiece(from: selected, to: tappedPos)
                selectedPosition = nil
                possibleMoves = []
            } else {
                // Reselect
                selectedPosition = selectIfCurrentPlayersPiece(position: tappedPos)
                possibleMoves = selectedPosition != nil ? validMoves(for: selectedPosition!) : []
            }
        } else {
            // No piece selected yet
            selectedPosition = selectIfCurrentPlayersPiece(position: tappedPos)
            possibleMoves = selectedPosition != nil ? validMoves(for: selectedPosition!) : []
        }
    }
    
    private func selectIfCurrentPlayersPiece(position: Position) -> Position? {
        if let piece = board[position.row][position.col], piece.color == currentPlayer.color {
            return position
        }
        return nil
    }
    
    // MARK: - Movement and Rules
    
    private func movePiece(from: Position, to: Position) {
        guard let piece = board[from.row][from.col] else { return }
        let originalPiece = piece
        let isCapture = board[to.row][to.col] != nil
        
        // Check Pawndimonium
        let pawndimoniumActive = (currentPlayer == .playerOne && pawndimoniumActiveForWhite) || (currentPlayer == .playerTwo && pawndimoniumActiveForBlack)
        let wasPawndimoniumCapture = pawndimoniumActive && isPawnCaptureMoveLike(from: from, to: to, piece: piece)
        
        let capturedPiece = board[to.row][to.col]
        board[to.row][to.col] = piece
        board[from.row][from.col] = nil
        
        if wasPawndimoniumCapture && isCapture {
            // Revert piece back after capture
            board[to.row][to.col] = nil
            board[from.row][from.col] = originalPiece
            deactivatePawndimonium(for: currentPlayer)
        }
        
        // If it was a normal capture, check if atomicus triggers
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
        
        // Check extra turn
        if currentPlayer == .playerOne && extraTurnActiveForWhite {
            extraTurnActiveForWhite = false
            // Don't switch player
        } else if currentPlayer == .playerOne && (tripleTurnActiveForWhite && tripleWhiteTurn != 2){
            if tripleWhiteTurn == 2{
                tripleTurnActiveForWhite = false
            }
            tripleWhiteTurn += 1
            
        } else if currentPlayer == .playerTwo && (tripleTurnActiveForBlack && tripleBlackTurn != 2){
            if tripleBlackTurn == 2{
                tripleTurnActiveForBlack = false
            }
            tripleBlackTurn += 1
        } else if currentPlayer == .playerTwo && extraTurnActiveForBlack {
            extraTurnActiveForBlack = false
            // Don't switch player
        } else {
            currentPlayer = currentPlayer.opposite

        }
        
        // Decrement cooldowns
        decrementCooldowns(for: &playerOnePowerUps)
        decrementCooldowns(for: &playerTwoPowerUps)
        
        checkForKingCapture()
    }
    
    private func checkForKingCapture() {
        let whiteKingExists = pieceExists(.king, .white)
        let blackKingExists = pieceExists(.king, .black)
        
        if !whiteKingExists {
            // White king gone => Black wins
            gameOverMessage = "Black wins!"
            showGameOverAlert = true
        } else if !blackKingExists {
            // Black king gone => White wins
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
    
    // MARK: - Valid Moves
    
    private func validMoves(for pos: Position) -> [Position] {
        guard let piece = board[pos.row][pos.col] else { return [] }
        let moves: [Position] = {
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
        }()
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
    
    // MARK: - Piece Moves
    
    private func pawnMoves(pos: Position, piece: ChessPiece) -> [Position] {
        var moves: [Position] = []
        let direction: Int = piece.color == .white ? -1 : 1
        let startRow = piece.color == .white ? 6 : 1
        let forwardOne = Position(row: pos.row + direction, col: pos.col)
        
        if inBounds(forwardOne.row, forwardOne.col) && board[forwardOne.row][forwardOne.col] == nil {
            moves.append(forwardOne)
            let forwardTwo = Position(row: pos.row + direction*2, col: pos.col)
            if pos.row == startRow && inBounds(forwardTwo.row, forwardTwo.col) && board[forwardTwo.row][forwardTwo.col] == nil {
                moves.append(forwardTwo)
            }
        }
        
        let diagLeft = Position(row: pos.row + direction, col: pos.col - 1)
        if inBounds(diagLeft.row, diagLeft.col), let cap = board[diagLeft.row][diagLeft.col], cap.color != piece.color {
            moves.append(diagLeft)
        }
        
        let diagRight = Position(row: pos.row + direction, col: pos.col + 1)
        if inBounds(diagRight.row, diagRight.col), let cap = board[diagRight.row][diagRight.col], cap.color != piece.color {
            moves.append(diagRight)
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
    
    // MARK: - Power-Ups Logic
    
    private func rollNewPowerUps(count: Int) -> [PowerUp] {
        var result: [PowerUp] = []
        for _ in 0..<count {
            let roll = Double.random(in: 0...1)
            let (name, desc, rarity): (String, String, String)
            if roll < 0.6 {
                // Rare
                (name, desc, rarity) = rarePowers.randomElement()!
            } else if roll < 0.9 {
                // Epic
                (name, desc, rarity) = epicPowers.randomElement()!
            } else {
                // Legendary
                (name, desc, rarity) = legendaryPowers.randomElement()!
            }
            
            // Initially set cooldown to 0 so the power-up can be used right away
            result.append(PowerUp(name: name, description: desc, rarity: rarity, cooldown: 0))
        }
        return result
    }
    
    private func cooldownForRarity(_ rarity: String) -> Int {
        switch rarity {
        case "Rare": return 3
        case "Epic": return 6
        case "Legendary": return 9
        default: return 3
        }
    }
    
    private func activatePowerUp(for player: Player, index: Int) {
        if player == .playerOne {
            applyPowerUp(&playerOnePowerUps[index], for: .playerOne)
        } else {
            applyPowerUp(&playerTwoPowerUps[index], for: .playerTwo)
        }
    }
    
    private func applyPowerUp(_ powerUp: inout PowerUp, for player: Player) {
        // Activate the power-up effect
        switch powerUp.name {
        case "Atomicus!":
            // Already implemented: If captured, explode in 3x3
            if player == .playerOne {
                atomicusActiveForWhite = true
            } else {
                atomicusActiveForBlack = true
            }
            
        case "Extra Turn":
            // Already implemented: next turn, don't switch player
            if player == .playerOne {
                extraTurnActiveForWhite = true
            } else {
                extraTurnActiveForBlack = true
            }
        
        case "Triple Turn":
            // Already implemented: next turn, don't switch player
            if player == .playerOne {
                tripleTurnActiveForWhite = true
                tripleWhiteTurn = 0
            } else {
                tripleTurnActiveForBlack = true
                tripleWhiteTurn = 0
            }
            
        case "Pawndimonium":
            // Already implemented: next capture acts like a pawn capture revert
            if player == .playerOne {
                pawndimoniumActiveForWhite = true
            } else {
                pawndimoniumActiveForBlack = true
            }
            
        case "Pawnzilla":
            // Spawns a second pawn in the same row as an existing pawn.
            // Placeholder: find one of the player's pawns and duplicate it in some free spot in that row.
            spawnExtraPawn(for: player)
            
        case "Backpedal":
            // Move one of your pieces backward by one square if possible.
            // Placeholder: choose a piece of the current player and move it backward if legal.
            backpedalMove(for: player)
            
        case "Pawndemic":
            // A pawn moves backward and captures adjacent enemies.
            // Placeholder: pick one of your pawns, move it one square backward if free,
            // and remove enemy pieces adjacent to it.
            pawndemicEffect(for: player)
            
        case "Swap 'n' Go":
            // Swap places with one of your pieces.
            // Placeholder: choose two of your pieces and swap them.
            swapAndGo(for: player)
            
        case "Port-A-Piece":
            // Teleport one piece anywhere.
            // Placeholder: pick a piece, pick a free square, move it there.
            portAPiece(for: player)
            
        case "Reboot":
            // Bring back a captured pawn of your color in the back row.
            rebootPawn(for: player)
            
        case "Copycat":
            // Move 2 pawns together at once.
            // Placeholder: pick two pawns and move them forward one step if possible.
            copycatMove(for: player)
            
        case "Pawno-Kinetic":
            // Move all your pawns forward two squares if possible.
            pawnoKineticEffect(for: player)
            
        case "Frozen Assets":
            // Freeze 3 enemy pieces for one turn.
            // Placeholder: pick or find 3 enemy pieces and mark them as frozen.
            freezeEnemyPieces(for: player, count: 3)
            
        case "Knightmare Fuel":
            // All your knights move like queens for one turn.
            // Just set a counter that for the next X turn (just 1 turn?), knights move like queens.
            if player == .playerOne {
                knightsMoveLikeQueensForWhite = 1
            } else {
                knightsMoveLikeQueensForBlack = 1
            }
            
        case "Piece Out":
            // Pick an enemy piece; it can’t move/attack for two turns.
            // Placeholder: choose an enemy piece and store it in pieceOutEffects.
            pieceOutEffect(for: player)
            
        case "King's Sacrifice":
            // Deactivate your king for 3 rounds and remove an enemy piece instantly.
            // Remove an enemy piece (random or chosen) and mark your king as "deactivated".
            kingsSacrifice(for: player)
            
        case "Rook 'n' Roll":
            // Two of your pieces move like rooks for one turn.
            // Set a counter to indicate this effect.
            if player == .playerOne {
                rookRollForWhite = 1
            } else {
                rookRollForBlack = 1
            }
            
        case "Puppet Strings":
            // Control one enemy pawn for a turn.
            // Just set a state that next turn you can move one enemy pawn as if it was yours.
            if player == .playerOne {
                puppetStringsActiveForWhite = true
            } else {
                puppetStringsActiveForBlack = true
            }
            
        case "Grand Finale":
            // Sacrifice a piece and cause chain removals over 3 turns.
            // Increment a counter that after each turn removes a random enemy piece.
            grandFinale(for: player)
            
        case "Rookie Mistake":
            // All pawns move like rooks this turn.
            if player == .playerOne {
                allPawnsRookForWhite = 1
            } else {
                allPawnsRookForBlack = 1
            }
            
        case "Check That Out":
            // Delete 1 random piece around enemy's king.
            checkThatOut(for: player)
            
        case "I Ocean You":
            // Ocean wave captures 4 random enemy pawns.
            iOceanYou(for: player)
            
        default:
            break
        }
        
        // After using the power-up, set its cooldown based on rarity.
        powerUp.cooldown = cooldownForRarity(powerUp.rarity)
    }
    
    private func spawnExtraPawn(for player: Player) {
        // Find a pawn belonging to the player.
        // Then find a free square in the same row and place a new pawn there.
        // For simplicity, just pick the first pawn found.
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
        // Find a piece and try to move it one square "back" from its perspective.
        // For white, back means +1 row, for black back means -1 row.
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
        // Just return the first piece found for simplicity.
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
        // Pick a pawn, move it backward one step, capture adjacent enemies.
        if let (r,c) = findPawn(for: player) {
            let direction = (player == .playerOne) ? 1 : -1
            let newRow = r + direction
            if inBounds(newRow, c) && board[newRow][c] == nil {
                // Move pawn
                board[newRow][c] = board[r][c]
                board[r][c] = nil
                // Capture adjacent enemies
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
        // Swap two of your pieces.
        // Just pick first two pieces of the player and swap them if possible.
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
        // Teleport one piece anywhere.
        // Just pick a piece and move it to first free spot found at top-left corner.
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
        // Bring back a captured pawn. We must track captured pieces if we want this to work properly.
        // For simplicity, create a new pawn in the back row if free.
        let backRow = player == .playerOne ? 7 : 0
        if let freeCol = findFreeCol(inRow: backRow) {
            board[backRow][freeCol] = ChessPiece(type: .pawn, color: player.color)
        }
    }
    
    private func copycatMove(for player: Player) {
        // Move 2 pawns forward one step if possible.
        // Just find two pawns and move them forward one step.
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
        // Move all your pawns forward two squares if possible.
        let direction = player == .playerOne ? -1 : 1
        // Move from front to back or back to front depending on direction to avoid overwriting
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
    
    private func freezeEnemyPieces(for player: Player, count: Int) {
        // Freeze 3 enemy pieces for one turn.
        // Just pick first 3 enemy pieces and mark them frozen for 1 turn.
        let enemyColor = player == .playerOne ? PieceColor.black : PieceColor.white
        var frozenCount = 0
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == enemyColor {
                    frozenEnemyPieces.append((Position(row: r, col: c), 1))
                    frozenCount += 1
                    if frozenCount == count { return }
                }
            }
        }
    }
    
    private func pieceOutEffect(for player: Player) {
        // Choose an enemy piece and prevent it from moving for 2 turns.
        // Just pick the first enemy piece found.
        let enemy = player == .playerOne ? PieceColor.black : PieceColor.white
        if let pos = findPieceOfColor(enemy) {
            pieceOutEffects.append((pos, 2, player))
        }
    }
    
    private func findPieceOfColor(_ color: PieceColor) -> Position? {
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c], p.color == color {
                    return Position(row: r, col: c)
                }
            }
        }
        return nil
    }
    
    private func kingsSacrifice(for player: Player) {
        // Deactivate your king for 3 rounds and remove an enemy piece.
        // Deactivate king means the king is off the board or can't be moved?
        // For simplicity, remove king from board and store a counter.
        let kingColor = player.color
        if let kingPos = findKing(for: kingColor) {
            board[kingPos.row][kingPos.col] = nil
        }
        if player == .playerOne {
            kingDeactivatedForWhite = 3
        } else {
            kingDeactivatedForBlack = 3
        }
        
        // Remove an enemy piece (first enemy piece found)
        let enemyColor = player == .playerOne ? PieceColor.black : PieceColor.white
        if let enemyPos = findPieceOfColor(enemyColor) {
            board[enemyPos.row][enemyPos.col] = nil
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
    
    private func grandFinale(for player: Player) {
        // 3 turns of chain removals (remove random enemy piece each turn).
        // Just set a counter, and each turn remove one enemy piece if available.
        if player == .playerOne {
            grandFinaleForWhite = 3
        } else {
            grandFinaleForBlack = 3
        }
    }
    
    private func checkThatOut(for player: Player) {
        // Delete 1 random piece around enemy's king.
        // Find enemy king and remove a random piece around it.
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
            if let target = candidates.randomElement() {
                board[target.row][target.col] = nil
            }
        }
    }
    
    private func iOceanYou(for player: Player) {
        // Ocean wave captures 4 random enemy pawns.
        // Just remove up to 4 random enemy pawns.
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
        case (.pawn, .white): return "♙"
        case (.rook, .white): return "♖"
        case (.knight, .white): return "♘"
        case (.bishop, .white): return "♗"
        case (.queen, .white): return "♕"
        case (.king, .white): return "♔"
            
        case (.pawn, .black): return "♟︎"
        case (.rook, .black): return "♜"
        case (.knight, .black): return "♞"
        case (.bishop, .black): return "♝"
        case (.queen, .black): return "♛"
        case (.king, .black): return "♚"
        }
    }
}
