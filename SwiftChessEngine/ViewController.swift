//
//  ViewController.swift
//  SwiftChessEngine
//
//  Created by Javier Soto on 7/3/16.
//  Copyright © 2016 JaviSoto. All rights reserved.
//

import UIKit
import Sage

extension PlaygroundQuickLook {
    var view: UIView? {
        switch self {
            case .view(let view): return view as? UIView
            default: return nil
        }
    }
}

extension UIView {
    var image: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: self.bounds)

        return renderer.image() { context in
            self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        }
    }
}

final class EngineViewController: UIViewController {
    @IBOutlet private var boardViewContainer: UIView!
    @IBOutlet private var boardImageView: UIImageView!
    @IBOutlet private var evaluationLabel: UILabel!
    @IBOutlet private var toggleCalculationButton: UIButton!

    private var currentBoard: Board! {
        didSet {
            let view = currentBoard.customPlaygroundQuickLook.view!
            let image = view.image

            self.boardImageView.image = image
        }
    }

    private let engine = ChessEngine()

    private let engineQueue = DispatchQueue(label: "engine")
    private static let maxDepth = 3

    override func viewDidLoad() {
        super.viewDidLoad()

        self.evaluationLabel.text = nil
        self.currentBoard = self.engine.game.position.board
    }

    private func presentAlertWithGamePGN() {
        let alert = UIAlertController(title: "Moves", message: "\(self.engine.game.playedMoves)", preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "OK", style: .`default`) { _ in
            alert.dismiss(animated: true)
        }
        alert.addAction(dismissAction)

        self.present(alert, animated: true)
    }

    private func presentAlertViewToEnterText(title: String, textEntered: (String) -> ()) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "OK", style: .`default`) { [unowned alert] _ in
            let enteredText = alert.textFields!.first!.text ?? ""

            self.dismiss(animated: true)
            textEntered(enteredText)
        }
        alert.addAction(dismissAction)

        alert.addTextField()
        
        self.present(alert, animated: true)
    }

    private func presentAlertViewsToEnterMove() {
        self.presentAlertViewToEnterText(title: "From square") { text in
            guard text.characters.count == 4 else {
                self.presentAlertViewsToEnterMove()
                return
            }

            let originText = String(Array(text.characters)[0...1])
            let destinationText = String(Array(text.characters)[2...4])

            guard let originSquare = Square(originText),
                let destinationSquare = Square(destinationText) else {
                    self.presentAlertViewsToEnterMove()
                    return
            }

            let move = Move(start: originSquare, end: destinationSquare)
            do {
                try self.apply(move)
                self.tick()
            }
            catch {
                print("Invalid move: \(error)")
                self.presentAlertViewsToEnterMove()
            }
        }
    }

    var calculating: Bool = false {
        didSet {
            self.toggleCalculationButton.setTitle(calculating ? "Stop calculating" : "Start calculating", for: [])

            if calculating != oldValue {
                if calculating {
                    self.tick()
                }
                else {
                    self.presentAlertWithGamePGN()
                }
            }
        }
    }

    func apply(_ move: Move) throws {
        print("Applying move \(move)")

        try self.engine.game.execute(move: move)
        self.currentBoard = self.engine.game.position.board
    }

    var totalMovesAnalized = 0

    let computerSide = Color.black

    private func tick() {
        guard self.calculating else { return }

        guard self.engine.game.playerTurn == self.computerSide else {
            self.presentAlertViewsToEnterMove()
            return
        }

        self.engineQueue.async {
            do {
                print("Calculating from position \(self.engine.game.position.fen())")
                let analysis = try self.engine.bestMove(maxDepth: EngineViewController.maxDepth)

                DispatchQueue.main.async {
                    if let move = analysis.move {
                        try! self.apply(move)
                    }

                    self.totalMovesAnalized += analysis.movesAnalized
                    self.evaluationLabel.text = "Move \(self.engine.game.fullmoves). Valuation: \(analysis.valuation) (after \(self.totalMovesAnalized) moves analized)"
                    self.tick()
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.evaluationLabel.text = "Error: \(error)"
                }
            }
        }
    }

    @IBAction func calculateButtonTapped() {
        self.calculating = !self.calculating
    }
}
