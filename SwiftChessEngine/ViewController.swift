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

class ViewController: UIViewController {
    @IBOutlet var boardViewContainer: UIView!
    @IBOutlet var evaluationLabel: UILabel!

    var currentBoard: Board? {
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

    let engine = ChessEngine()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func calculateButtonTapped() {
        self.evaluationLabel.text = "Calculating..."

        DispatchQueue(label: "engine").async {
            do {
                let analysis = try self.engine.bestMove(maxDepth: 2)

                DispatchQueue.main.async {
                    if let move = analysis.move {
                        try! self.engine.game.execute(move: move)
                        self.currentBoard = self.engine.game.position.board
                    }

                    self.evaluationLabel.text = "Valuation: \(analysis.valuation) (after \(analysis.movesAnalized) moves analized)"
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.evaluationLabel.text = "Error: \(error)"
                }
            }
        }
    }
}


