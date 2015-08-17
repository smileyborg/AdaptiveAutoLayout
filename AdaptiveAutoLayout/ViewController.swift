//
//  ViewController.swift
//  AdaptiveAutoLayout
//
//  Copyright (c) 2015 Tyler Fox
//

import UIKit
import PureLayout

/** A simple function that interpolates between two CGFloat values. */
func interpolateCGFloat(start start: CGFloat, end: CGFloat, progress: CGFloat) -> CGFloat {
    return start * (1.0 - progress) + end * progress
}

/** A simple function that interpolates between two CGRect values. */
func interpolateCGRect(start start: CGRect, end: CGRect, progress: CGFloat) -> CGRect {
    let x = interpolateCGFloat(start: start.origin.x, end: end.origin.x, progress: progress)
    let y = interpolateCGFloat(start: start.origin.y, end: end.origin.y, progress: progress)
    let width = interpolateCGFloat(start: start.size.width, end: end.size.width, progress: progress)
    let height = interpolateCGFloat(start: start.size.height, end: end.size.height, progress: progress)
    return CGRect(x: x, y: y, width: width, height: height)
}


class ViewController: UIViewController {
    
    let redView = UIView.newAutoLayoutView()
    let blueView = UIView.newAutoLayoutView()
    let greenView = UIView()
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(red: 30/255.0, green: 29/255.0, blue: 31/255.0, alpha: 1.0)
        redView.backgroundColor = UIColor(red: 255/255.0, green: 84/255.0, blue: 62/255.0, alpha: 1.0)
        blueView.backgroundColor = UIColor(red: 0/255.0, green: 145/255.0, blue: 255/255.0, alpha: 1.0)
        greenView.backgroundColor = UIColor(red: 87/255.0, green: 220/255.0, blue: 119/255.0, alpha: 1.0)
        greenView.layer.cornerRadius = 10
        view.addSubview(redView)
        view.addSubview(blueView)
        view.addSubview(greenView)
        view.setNeedsUpdateConstraints() // bootstrap the auto layout engine
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: "viewPanned:")
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    var didSetupConstraints = false
    
    override func updateViewConstraints() {
        if (!didSetupConstraints) {
            // Setup the "real" constraints for the views
            setupConstraintsForRedView(redView, blueView: blueView)
            didSetupConstraints = true
        }
        
        super.updateViewConstraints()
    }
    
    /** Creates and activates constraints for the red and blue views passed in. Note: both views must share a common superview. */
    func setupConstraintsForRedView(redView: UIView, blueView: UIView) {
        let margin: CGFloat = 30.0
        
        redView.autoMatchDimension(.Width, toDimension: .Width, ofView: redView.superview!, withMultiplier: 0.5)
        redView.autoSetDimension(.Height, toSize: 60.0)
        redView.autoPinEdgeToSuperviewEdge(.Top, withInset: margin)
        redView.autoPinEdgeToSuperviewEdge(.Left, withInset: margin)
        
        blueView.autoSetDimensionsToSize(CGSize(width: 40.0, height: 120.0))
        blueView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: margin)
        blueView.autoPinEdgeToSuperviewEdge(.Right, withInset: margin)
    }
    
    /** A tuple that stores the start & end frames for the green view. */
    var greenViewFrames: (start: CGRect, end: CGRect)!
    /** Flag used to do one initial calculation of the green view's frame after the first load, as viewWillTransitionToSize... is not called at this time. */
    var didInitialCalculation = false
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if (!didInitialCalculation) {
            greenViewFrames = calculateGreenViewFramesWithViewBounds(view.bounds)
            updateGreenView()
            didInitialCalculation = true
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        coordinator.animateAlongsideTransition(
            { [unowned self] (context) -> Void in
                self.greenViewFrames = self.calculateGreenViewFramesWithViewBounds(self.view.bounds)
                self.updateGreenView()
            },
            completion: nil)
    }
    
    /** Calculates the start & end frames of the green view based on the given bounds for the view controller's view. Returns a tuple containing the start and end frames.
        Utilizes transient offscreen views for layout calculation purposes. */
    func calculateGreenViewFramesWithViewBounds(bounds: CGRect) -> (start: CGRect, end: CGRect) {
        let offscreenContainer = UIView() // need a root-level view in the offscreen hierarchy to contain the views we are interested in
        let oVCView = UIView() // this is an offscreen view that represents this view controller's (onscreen) view
        // Create the offscreen versions of the other onscreen views (the `o` prefix is for offscreen)
        let oRedView = UIView.newAutoLayoutView()
        let oBlueView = UIView.newAutoLayoutView()
        let oGreenView = UIView.newAutoLayoutView()
        
        offscreenContainer.addSubview(oVCView)
        oVCView.frame = bounds
        
        oVCView.addSubview(oRedView)
        oVCView.addSubview(oBlueView)
        setupConstraintsForRedView(oRedView, blueView: oBlueView)
        
        oRedView.addSubview(oGreenView)
        oGreenView.autoPinEdgesToSuperviewMargins()
        oVCView.setNeedsLayout()
        oVCView.layoutIfNeeded()
        let greenViewFrameStart = oVCView.convertRect(oGreenView.bounds, fromView: oGreenView)
        
        oBlueView.addSubview(oGreenView) // implictly removes oGreenView from its superview, as well as its constraints
        oGreenView.autoPinEdgesToSuperviewMargins()
        oVCView.setNeedsLayout()
        oVCView.layoutIfNeeded()
        let greenViewFrameEnd = oVCView.convertRect(oGreenView.bounds, fromView: oGreenView)
        
        return (start: greenViewFrameStart, end: greenViewFrameEnd)
    }
    
    /** Indicates the interpolation progress of the greenView, from the red view (0.0) to the blue view (1.0). */
    var currentProgress: CGFloat = 0.0
    
    /** Sets the frame of the onscreen green view by interpolating between the start and end frames based on the current progress. */
    func updateGreenView() {
        greenView.frame = interpolateCGRect(start: greenViewFrames.start, end: greenViewFrames.end, progress: currentProgress)
    }
    
    func viewPanned(panGestureRecognizer: UIPanGestureRecognizer) {
        let xTranslation = panGestureRecognizer.translationInView(view).x
        let xRange = 0.7 * CGRectGetWidth(view.bounds)
        let newProgress = max(0.0, min(1.0, currentProgress + xTranslation / xRange))
        greenView.frame = interpolateCGRect(start: greenViewFrames.start, end: greenViewFrames.end, progress: newProgress)
        if (panGestureRecognizer.state == .Ended) {
            currentProgress = newProgress
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}
