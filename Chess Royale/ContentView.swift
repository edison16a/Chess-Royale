import SwiftUI

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
    @State private var pawndimoniumActiveForWhite = false
    @State private var pawndimoniumActiveForBlack = false
    
    // A move counter just for cooldown purposes
    @State private var moveCounter: Int = 0
    
    // MARK: - PowerUp Pools
    
    let rarePowers = [
        ("Extra Turn", "Two moves in a row.", "Rare"),
        ("Pawnzilla", "Spawns a second pawn in the same row as an existing pawn.", "Rare"),
        ("Backpedal", "Move one of your pieces backward.", "Rare"),
        ("Pawndemic", "A pawn moves backward and captures adjacent enemies.", "Rare"),
        ("Swap 'n' Go", "Swap places with one of your pieces.", "Rare"),
        ("Port-A-Piece", "Teleport one piece anywhere.", "Rare"),
        ("Reboot", "Bring back a captured pawn.", "Rare"),
        ("Copycat", "Move 2 pawns together at once", "Rare"),
        ("Pawno-Kinetic", "Move all your pawns forward two squares.", "Rare")
    ]
    
    let epicPowers = [
        ("Pawndimonium", "Capture like a pawn once, then revert.", "Epic"),
        ("Frozen Assets", "Freeze 3 enemy pieces for one turn.", "Epic"),
        ("Knightmare Fuel", "All knights move like queens for one turn.", "Epic"),
        ("Piece Out", "Pick an enemy piece; it can’t move/attack for two turns.", "Epic"),
        ("King's Sacrifice", "Deactivate your king for 3 rounds and instantly remove an enemy piece.", "Epic"),
        ("Rook 'n' Roll", "Two of your pieces move like rooks for one turn.", "Epic"),
        ("Puppet Strings", "Control one enemy pawn for a turn.", "Epic"),
        ("Grand Finale", "Sacrifice a piece for chain removals over 3 turns.", "Epic")
    ]
    
    let legendaryPowers = [
        ("Atomicus!", "When captured, explode in a 3x3 area.", "Legendary"),
        ("Rookie Mistake", "All pawns move like rooks this turn.", "Legendary"),
        ("Check That Out", "Delete 1 random piece around enemy's king.", "Legendary"),
        ("I Ocean You", "Ocean wave captures 4 random enemy pawns.", "Legendary")
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
        
        // Computed property to determine background color based on rarity
        private var backgroundColor: Color {
            switch powerUp.rarity.lowercased() {
            case "rare":
                return Color.green
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
        } else if currentPlayer == .playerTwo && extraTurnActiveForBlack {
            extraTurnActiveForBlack = false
            // Don't switch player
        } else {
            currentPlayer = currentPlayer.opposite
        }
        
        // Decrement cooldowns
        decrementCooldowns(for: &playerOnePowerUps)
        decrementCooldowns(for: &playerTwoPowerUps)
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
            if player == .playerOne {
                atomicusActiveForWhite = true
            } else {
                atomicusActiveForBlack = true
            }
        case "Extra Turn":
            if player == .playerOne {
                extraTurnActiveForWhite = true
            } else {
                extraTurnActiveForBlack = true
            }
        case "Pawndimonium":
            if player == .playerOne {
                pawndimoniumActiveForWhite = true
            } else {
                pawndimoniumActiveForBlack = true
            }
        default:
            // Implement other power logic here.
            break
        }
        
        // After using the power-up, set its cooldown based on rarity.
        powerUp.cooldown = cooldownForRarity(powerUp.rarity)
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
