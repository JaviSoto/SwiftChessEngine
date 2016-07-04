//
//  ChessEngine.swift
//  SwiftChessEngine
//
//  Created by Javier Soto on 7/3/16.
//  Copyright © 2016 JaviSoto. All rights reserved.
//

import Foundation
import Sage

extension Collection where Iterator.Element == Piece {
    var valuation: ChessEngine.Valuation {
        return self.lazy.filter { !$0.kind.isKing }.map { $0.kind.relativeValue }.reduce(0, combine: +)
    }
}

private extension Board {
    private static let initialBoard = Board()

    func pieces(for color: Color) -> [Piece] {
        return color.isWhite ? self.whitePieces : self.blackPieces
    }

    func allAttackers(attackingColor: Color) -> Int {
        let oppositePiecesSquares = self.squares(for: attackingColor.inverse())

        var total = 0

        for oppositePieceSquare in oppositePiecesSquares {
            total += self.attackers(to: oppositePieceSquare, color: attackingColor).count
        }

        return total
    }

    private func piecesOutsideOriginalPosition(for color: Color) -> Int {
        let pieces = self.pieces(for: color)

        var count = 0

        for piece in pieces {
            if self.bitboard(for: piece) != Board.initialBoard.bitboard(for: piece) {
                count += 1
            }
        }

        return count
    }

    func doubledPawns(for color: Color) -> Int {
        let pawnFiles = self.pieces(for: color)
            .filter { $0.kind.isPawn }
            .flatMap { self.locations(for: $0).map { $0.file.rawValue } }

        let uniqueFiles = Set(pawnFiles)

        return pawnFiles.count - uniqueFiles.count
    }
}

private extension CastlingRights {
    private static let whiteCastlingRights: CastlingRights = [.whiteQueenside, .whiteKingside]
    private static let blackCastlingRights: CastlingRights = [.blackQueenside, .blackKingside]

    static func rightsFor(color: Color) -> CastlingRights {
        return color.isWhite ? self.whiteCastlingRights : self.blackCastlingRights
    }

    func canCastle(side: Color) -> Bool {
        return !self.intersection(CastlingRights.rightsFor(color: side)).isEmpty
    }
}

extension Game {
    func currentPositionValuation() -> ChessEngine.Valuation {
        let movingSide = self.position.playerTurn
        let oppositeSide = movingSide.inverse()
        let board = self.position.board

        var extras: ChessEngine.Valuation = 0

        if board.kingIsChecked(for: oppositeSide) {
            extras += 1
        }
        else if board.kingIsChecked(for: movingSide) {
            extras -= 0.3
        }

        let myPieces = board.pieceCount(for: movingSide)
        let theirPieces = board.pieceCount(for: oppositeSide)

        extras += Double(myPieces - theirPieces) * 0.1

        extras += 0.001 * Double(board.allAttackers(attackingColor: movingSide))
        extras -= 0.0005 * Double(board.allAttackers(attackingColor: oppositeSide))
        extras += 0.01 * Double(board.piecesOutsideOriginalPosition(for: movingSide))
        extras -= 0.01 * Double(board.piecesOutsideOriginalPosition(for: oppositeSide))

        extras -= 0.01 * Double(board.doubledPawns(for: movingSide))
        extras += 0.01 * Double(board.doubledPawns(for: oppositeSide))

        let weHaveCastled = self.playedMoves(bySide: movingSide).contains { $0.isCastle }
        let theyHaveCastled = self.playedMoves(bySide: oppositeSide).contains { $0.isCastle }

        let pointsForCastling: ChessEngine.Valuation = 2
        let cantCastlePenalty: ChessEngine.Valuation = -pointsForCastling

        if weHaveCastled {
            extras += pointsForCastling
        }

        if theyHaveCastled {
            extras -= pointsForCastling
        }

        let weCanCastle = self.castlingRights.canCastle(side: movingSide)
        let theyCanCastle = self.castlingRights.canCastle(side: movingSide.inverse())

        if !weCanCastle {
            extras += cantCastlePenalty
        }

        if !theyCanCastle {
            extras -= cantCastlePenalty
        }

        return (board.whitePieces.valuation - board.blackPieces.valuation) + (extras * (movingSide.isWhite ? 1 : -1))
    }
}

private extension Int {
    var isEven: Bool {
        return self % 2 == 0
    }

    var isOdd: Bool {
        return !self.isEven
    }
}

private extension Game {
    func playedMoves(bySide side: Color) -> [Move] {
        return self.playedMoves.enumerated()
            .filter { (side.isWhite && $0.offset.isEven) || (side.isBlack && !$0.offset.isEven) }
            .map { $0.element }
    }
}

private extension Game {
    func deepEvaluation(depth: Int) throws -> ChessEngine.PositionAnalysis {
        return try self.deepEvaluation(depth: depth, alpha: ChessEngine.Valuation.infinity.negated(), beta: ChessEngine.Valuation.infinity)
    }

    private func deepEvaluation(depth: Int, alpha: ChessEngine.Valuation, beta: ChessEngine.Valuation) throws -> ChessEngine.PositionAnalysis {
        let movingSide = self.position.playerTurn

        guard depth > 0 else {
            return ChessEngine.PositionAnalysis(move: nil, valuation: self.currentPositionValuation(), movesAnalized: 1)
        }

        let availableMoves = self.availableMoves()

        guard availableMoves.count > 1 else {
            let valuation: ChessEngine.Valuation

            switch self.outcome {
                case .some(.win(let color)):
                    valuation = color.isWhite ? ChessEngine.Valuation.infinity : ChessEngine.Valuation.infinity.negated()

                default:
                    valuation = self.currentPositionValuation()
            }

            return ChessEngine.PositionAnalysis(move: availableMoves.first, valuation: valuation, movesAnalized: 1)
        }

        var bestMove: Move?
        var bestValuation: ChessEngine.Valuation = movingSide.isWhite ? Double.infinity.negated() : Double.infinity
        var movesAnalized = 0

        var alpha = alpha
        var beta = beta

        for move in availableMoves {
            try self.execute(move: move)

            let analysis = try self.deepEvaluation(depth: depth - 1, alpha: alpha, beta: beta)
            self.undoMove()

            movesAnalized += analysis.movesAnalized

            if movingSide.isWhite {
                if analysis.valuation > alpha {
                    alpha = analysis.valuation
                    bestValuation = analysis.valuation
                    bestMove = move
                }
                if alpha >= beta {
                    break
                }
            }
            else {
                if analysis.valuation < beta {
                    beta = analysis.valuation
                    bestValuation = analysis.valuation
                    bestMove = move
                }

                if beta <= alpha {
                    break
                }
            }
        }

        return ChessEngine.PositionAnalysis(move: bestMove, valuation: bestValuation, movesAnalized: movesAnalized)
    }
}

final class ChessEngine {
    typealias Valuation = Double

    struct PositionAnalysis {
        let move: Move?
        let valuation: Valuation
        let movesAnalized: Int
    }

    let game = Game(mode: .computerVsComputer, variant: .standard)

    init() {

    }

    func bestMove(maxDepth: Int) throws -> PositionAnalysis {
        return try self.game.deepEvaluation(depth: maxDepth)
    }

    func benchmark() -> (Int, TimeInterval) {
        var iterations = 0

        let start = Date()
        while iterations < 10000 {
            iterations += 1

            guard let move = game.availableMoves().random else { break }
            try! game.execute(move: move)
        }

        let end = Date()

        let interval = end.timeIntervalSince(start)

        return (iterations, interval)
    }
}

extension Array {
    var random: Element? {
        guard !self.isEmpty else { return nil }

        let randomIndex = Int(arc4random_uniform(UInt32(self.count)))

        return self[randomIndex]
    }
}
