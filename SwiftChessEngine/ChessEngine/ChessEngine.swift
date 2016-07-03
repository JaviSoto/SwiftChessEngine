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
        return self.lazy.filter { !$0.isKing }.map { $0.relativeValue }.reduce(0, combine: +)
    }
}

extension Board {
    static let initialChessBoard = Board()

    func allAttackers(attackingColor: Color) -> Bitboard {
        var bitboard = Bitboard()

        let oppositePiecesSquares = self.squares(for: attackingColor.inverse())

        for oppositePieceSquare in oppositePiecesSquares {
            let attackers = self.attackers(to: oppositePieceSquare, color: attackingColor)

            bitboard &= attackers
        }

        return bitboard
    }
}

extension Board {
    func evaluation(movingSide: Game.PlayerTurn) -> ChessEngine.Valuation {
        var extras: ChessEngine.Valuation = 0

        if self.kingIsChecked(for: movingSide.inverse()) {
            extras += 1
        }
        else if self.kingIsChecked(for: movingSide) {
            extras -= 0.3
        }

        let myPieces = self.pieceCount(for: movingSide)
        let theirPieces = self.pieceCount(for: movingSide.inverse())

        extras += Double(myPieces - theirPieces) * 0.1

        extras += 0.01 * Double(self.allAttackers(attackingColor: movingSide).count)
        extras -= 0.005 * Double(self.allAttackers(attackingColor: movingSide.inverse()).count)

        return (self.whitePieces.valuation - self.blackPieces.valuation) + (extras * (movingSide.isWhite ? 1 : -1))
    }
}

extension Game {
    func deepEvaluation(depth: Int) throws -> ChessEngine.PositionAnalysis {
        return try self.deepEvaluation(depth: depth, alpha: ChessEngine.Valuation.infinity.negated(), beta: ChessEngine.Valuation.infinity)
    }

    private func deepEvaluation(depth: Int, alpha: ChessEngine.Valuation, beta: ChessEngine.Valuation) throws -> ChessEngine.PositionAnalysis {
        let movingSide = self.position.playerTurn

        func staticPositionAnalysis() -> ChessEngine.PositionAnalysis {
            func rawEvaluation() -> ChessEngine.Valuation {
                return self.board.evaluation(movingSide: movingSide)
            }

            return ChessEngine.PositionAnalysis(move: nil, valuation: rawEvaluation(), movesAnalized: 1)
        }

        guard depth > 0 else {
            return staticPositionAnalysis()
        }

        let availableMoves = self.availableMoves()
        guard availableMoves.count > 1 else {
            return staticPositionAnalysis()
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
                if analysis.valuation > bestValuation {
                    bestValuation = analysis.valuation
                    bestMove = move
                }

                alpha = ChessEngine.Valuation.maximum(alpha, bestValuation)
                if beta <= alpha {
                    break
                }
            }
            else {
                if analysis.valuation < bestValuation {
                    bestValuation = analysis.valuation
                    bestMove = move
                }

                beta = ChessEngine.Valuation.minimum(beta, bestValuation)
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
