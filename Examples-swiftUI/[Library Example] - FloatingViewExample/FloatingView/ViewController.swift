//
//  ViewController.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// The RootViewController of the Demo
final class ViewController: UIViewController {

    private lazy var panelController: FloatingViewControler = self.makePanelController()

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Aiolos Demo"
        self.view.backgroundColor = .white

        let safeAreaView = UIView()
        safeAreaView.translatesAutoresizingMaskIntoConstraints = false
        safeAreaView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        self.view.addSubview(safeAreaView)
        NSLayoutConstraint.activate([
            safeAreaView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 0),
            safeAreaView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 0),
            safeAreaView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            safeAreaView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: 0)
        ])

        let textField = UITextField(frame: CGRect(x: 50.0, y: 110.0, width: 150.0, height: 44.0))
        textField.layer.borderWidth = 1.0
        textField.delegate = self
        self.view.addSubview(textField)

        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(handleToggleVisibilityPress)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleToggleModePress))
        ]

        self.panelController.add(to: self)
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            self.panelController.performWithoutAnimation {
                self.panelController.configuration = self.configuration(for: newCollection)
            }
        }, completion: nil)
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.bottom]
    }
}

// MARK: - UITextFieldDelegate

extension ViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - PanelSizeDelegate

extension ViewController: PanelSizeDelegate {

    func panel(_ panel: FloatingViewControler, sizeForMode mode: FloatingMode) -> CGSize {

        switch mode {
        case .compact:
            return CGSize(width: 0.0, height: 100.0)
        case .halfScreen:
            let height: CGFloat = self.view.frame.height / 2
            return CGSize(width: 0.0, height: height)
        case .fullScreen:
            return CGSize(width: 0.0, height: 0.0)
        }
    }
}

// MARK: - PanelResizeDelegate

extension ViewController: PanelResizeDelegate {

    func panelDidStartResizing(_ panel: FloatingViewControler) {
        print("Panel did start resizing")
    }

    func panel(_ panel: FloatingViewControler, willResizeTo size: CGSize) {
        print("Panel will resize to size \(size)")
    }

    func panel(_ panel: FloatingViewControler, willTransitionFrom oldMode: FloatingMode?, to newMode: FloatingMode, with coordinator: PanelTransitionCoordinator) {
        print("Panel will transition from \(String(describing: oldMode)) to \(newMode)")

        // we can animate things along the way
        coordinator.animateAlongsideTransition({
            print("Animating alongside of panel transition")
        }, completion: { _ in
            print("Completed panel transition to \(newMode)")
        })
    }
}

// MARK: - PanelRepositionDelegate

extension ViewController: PanelRepositionDelegate {

    func panelCanStartMoving(_ panel: FloatingViewControler) -> Bool {
        return self.traitCollection.userInterfaceIdiom == .pad
    }

    func panelCanBeDismissed(_ panel: FloatingViewControler) -> Bool {
        return true
    }

    func panel(_ panel: FloatingViewControler, willMoveTo frame: CGRect) -> Bool {
        print("Panel will move to frame \(frame)")

        // we can prevent the panel from begin dragged
        // returning false will result in a rubber-band effect
        return true
    }


    func panel(_ panel: FloatingViewControler, with coordinator: PanelTransitionCoordinator) {
//        print("Panel is transitioning from \(String(describing: oldPosition)) to position \(newPosition)")

        // we can animate things along the way
        coordinator.animateAlongsideTransition({
            print("Animating alongside of panel transition")
        }, completion: { _ in
//            print("Completed panel transition to \(newPosition)")
        })
    }

    func panelWillTransitionToHiddenState(_ panel: FloatingViewControler, with coordinator: PanelTransitionCoordinator) {
        print("Panel is transitioning to hidden state")

        // we can animate things along the way
        coordinator.animateAlongsideTransition({
            print("Animating alongside of panel transition")
        }, completion: { _ in
            print("Completed panel transition to hidden state")
        })
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let contentNavigationController = self.panelController.contentViewController as? UINavigationController else { return false }
        guard let tableViewController = contentNavigationController.topViewController as? UITableViewController else { return false }

        // Prevent swipes on the table view being triggered as the panel is being dragged horizontally
        // More info: https://github.com/IdeasOnCanvas/Aiolos/issues/23
        return otherGestureRecognizer.view === tableViewController.tableView
    }
}

// MARK: - Private

private extension ViewController {

    func makePanelController() -> FloatingViewControler {
        let panelController = FloatingViewControler(configuration: self.configuration(for: self.traitCollection))
        let contentNavigationController = UINavigationController(rootViewController: PanelContentViewController(color: UIColor.red.withAlphaComponent(0.4)))
        contentNavigationController.navigationBar.barTintColor = .white
        contentNavigationController.navigationBar.isTranslucent = false
        contentNavigationController.setToolbarHidden(false, animated: false)
        contentNavigationController.toolbar.barTintColor = .darkGray
        contentNavigationController.view.bringSubviewToFront(contentNavigationController.navigationBar)

        panelController.sizeDelegate = self
        panelController.resizeDelegate = self
        panelController.repositionDelegate = self
        panelController.gestureDelegate = self
        panelController.configuration.mode = .halfScreen
        panelController.contentViewController = contentNavigationController

        return panelController
    }

    func configuration(for traitCollection: UITraitCollection) -> FloatingConfiguration {
        var configuration = FloatingConfiguration.default

        var panelMargins: NSDirectionalEdgeInsets {
            if traitCollection.userInterfaceIdiom == .pad || traitCollection.hasNotch { return NSDirectionalEdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0) }

            let horizontalMargin: CGFloat = traitCollection.verticalSizeClass == .compact ? 20.0 : 0.0
            return NSDirectionalEdgeInsets(top: 20.0, leading: horizontalMargin, bottom: 0.0, trailing: horizontalMargin)
        }

        configuration.supportedModes = [.compact, .halfScreen, .fullScreen]

        return configuration
    }

    @objc
    func handleToggleVisibilityPress() {
        if self.panelController.isVisible {
            self.panelController.removeFromParentView()
        } else {
            self.panelController.add(to: self)
        }
    }

    @objc
    func handleToggleModePress() {
        let nextModeMapping: [FloatingMode: FloatingMode] = [
            .compact: .halfScreen,
            .halfScreen: .fullScreen,
            .fullScreen: .compact
        ]
        guard let nextMode = nextModeMapping[self.panelController.configuration.mode] else { return }

        self.panelController.configuration.mode = nextMode
    }
}

private extension UITraitCollection {

    var hasNotch: Bool {
//        return UIApplication.shared.keyWindow!.safeAreaInsets.bottom > 0.0
        return false
    }
}
