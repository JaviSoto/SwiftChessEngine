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
        let movingSide = self.position.playerTurn

        func staticPositionAnalysis() -> ChessEngine.PositionAnalysis {
            func rawEvaluation() -> ChessEngine.Valuation {
                return self.board.evaluation(movingSide: movingSide)
            }

            return ChessEngine.PositionAnalysis(move: nil, valuation: rawEvaluation(), movesAnalized: 0)
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

        for move in availableMoves {
            movesAnalized += 1

            try self.execute(move: move)
            let analysis = try self.deepEvaluation(depth: depth - 1)
            let valuation = analysis.valuation
            movesAnalized += analysis.movesAnalized

            self.undoMove()

            if movingSide.isWhite && valuation > bestValuation || movingSide.isBlack && valuation < bestValuation {
                bestMove = move
                bestValuation = valuation
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
