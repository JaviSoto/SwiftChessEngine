//
//  ChessEngine.swift
//  SwiftChessEngine
//
//  Created by Javier Soto on 7/3/16.
//  Copyright © 2016 JaviSoto. All rights reserved.
//

import Foundation
import Sage

extension Piece {
    var value: ChessEngine.Valuation {
        switch self {
            case .pawn: return 1
            case .bishop, .knight: return 3
            case .queen: return 10
            case .rook: return 5
            case .king: return 100
        }
    }
}

extension Collection where Iterator.Element == Piece {
    var valuation: ChessEngine.Valuation {
        return self.map { $0.value }.reduce(0, combine: +)
    }
}

extension Board {
    func evaluation(movingSide: Game.PlayerTurn) -> ChessEngine.Valuation {
        return self.whitePieces.valuation - self.blackPieces.valuation
    }
}

extension Game {
    func deepEvaluation(depth: Int) throws -> ChessEngine.PositionAnalysis {
        return try self.deepEvaluation(depth: depth, alpha: Int.min, beta: Int.max)
    }

    private func deepEvaluation(depth: Int, alpha: Int, beta: Int) throws -> ChessEngine.PositionAnalysis {
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
        var bestValuation = movingSide.isWhite ? Int.min : Int.max
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

                alpha = max(alpha, bestValuation)
                if beta <= alpha {
                    break
                }
            }
            else {
                if analysis.valuation < bestValuation {
                    bestValuation = analysis.valuation
                    bestMove = move
                }

                beta = min(beta, bestValuation)
                if beta <= alpha {
                    break
                }
            }
        }

        return ChessEngine.PositionAnalysis(move: bestMove, valuation: bestValuation, movesAnalized: movesAnalized)
    }
}

final class ChessEngine {
    typealias Valuation = Int

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
