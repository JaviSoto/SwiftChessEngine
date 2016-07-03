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
    @IBOutlet private var evaluationLabel: UILabel!
    @IBOutlet private var toggleCalculationButton: UIButton!

    private var currentBoard: Board? {
        willSet {
            self.boardViewContainer.subviews.forEach { $0.removeFromSuperview() }
        }
        didSet {
            if let board = currentBoard {
                let view = board.customPlaygroundQuickLook.view!
                let image = view.image

                let imageView = UIImageView(frame: self.boardViewContainer.bounds)
                imageView.contentMode = .scaleAspectFit
                imageView.image = image

                self.boardViewContainer.addSubview(imageView)
            }
        }
    }

    private let engine = ChessEngine()

    private let engineQueue = DispatchQueue(label: "engine")
    private static let maxDepth = 4

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    var calculating: Bool = false {
        didSet {
            self.toggleCalculationButton.setTitle(calculating ? "Stop calculating" : "Start calculating", for: [])

            if calculating != oldValue && calculating {
                self.tick()
            }
        }
    }

    private func tick() {
        guard self.calculating else { return }

        self.engineQueue.async {
            do {
                let analysis = try self.engine.bestMove(maxDepth: EngineViewController.maxDepth)

                DispatchQueue.main.async {
                    if let move = analysis.move {
                        try! self.engine.game.execute(move: move)
                        self.currentBoard = self.engine.game.position.board
                    }

                    self.evaluationLabel.text = "Valuation: \(analysis.valuation) (after \(analysis.movesAnalized) moves analized)"
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


