//
//  ViewController.swift
//  Getting distance in AR
//
//  Created by Kovalenko Ilia on 12/11/2018.
//  Copyright © 2018 Kovalenko Ilia. All rights reserved.
//

import UIKit
import ARKit
import Vision
import CoreML

class ViewController: UIViewController {
    
    // MARK: - Outlet
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var vertView: UIView!
    @IBOutlet weak var horizView: UIView!
    @IBOutlet weak var squareView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var labelView: UILabel!
    
    // MARK: - Property
    var isDebuging: Bool = true {
        didSet {
            showAim(isDebuging)
            sceneView.debugOptions = isDebuging ? [.showWorldOrigin, .showFeaturePoints] : []
            squareView.isHidden = !isDebuging
        }
    }
    
    lazy var rectanglesRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest(completionHandler: handleRectangles)
        request.regionOfInterest = CGRect(x: 0.075, y: 0.075, width: 0.85, height: 0.85)
        
        return request
    }()
    
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: BannerClassifier().model)
            return VNCoreMLRequest(model: model, completionHandler: handleClassification)
        } catch {
            fatalError("can't load Vision ML model: \(error)")
        }
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLabenAndImageView()
        setupSquareView()
        setupSceneView()
        
        isDebuging = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        resetTrackingConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    // MARK: - Action
    // MARK: Vision Handler
    func handleRectangles(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation] else {
            fatalError("unexpected result type from VNDetectRectanglesRequest")
        }
        
        guard !observations.isEmpty else {
            print("Doesn't see any rectangles")
            return
        }
        
        guard let currentFrame = sceneView.session.currentFrame else { return }
        let inputImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
        
        for detectedRectangle in observations {
            let imageSize = inputImage.extent.size
            
            // Verify detected rectangle is valid.
            let boundingBox = detectedRectangle.boundingBox.scaled(to: imageSize)
            
            guard inputImage.extent.contains(boundingBox) else {
                print("invalid detected rectangle");
                return
            }
            
            // Rectify the detected image and reduce it to inverted grayscale for applying model.
            let topLeft = detectedRectangle.topLeft.scaled(to: imageSize)
            let topRight = detectedRectangle.topRight.scaled(to: imageSize)
            let bottomLeft = detectedRectangle.bottomLeft.scaled(to: imageSize)
            let bottomRight = detectedRectangle.bottomRight.scaled(to: imageSize)
            let correctedImage = inputImage
                .cropped(to: boundingBox)
                .applyingFilter("CIPerspectiveCorrection", parameters: [
                    "inputTopLeft": CIVector(cgPoint: topLeft),
                    "inputTopRight": CIVector(cgPoint: topRight),
                    "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                    "inputBottomRight": CIVector(cgPoint: bottomRight)
                    ])

            DispatchQueue.main.async { [unowned self] in
                self.imageView.image = UIImage(ciImage: correctedImage)
                self.labelView.text = "Analyzing..."
                
                self.imageView.isHidden = false
                self.labelView.isHidden = false
            }
            
            let handler = VNImageRequestHandler(ciImage: correctedImage)
            do {
                try handler.perform([classificationRequest])
            } catch {
                print(error)
            }
            
        }
    }
    
    func handleClassification(request: VNRequest, error: Error?) {
        
        guard let observations = request.results as? [VNClassificationObservation] else {
            fatalError("unexpected result type from VNCoreMLRequest")
        }
        
        guard let best = observations.first else {
            fatalError("can't get best result")
        }
        
        if isDebuging {
            print("Classification: \"\(best.identifier)\" Confidence: \(best.confidence)")
        }
        
        DispatchQueue.main.async { [unowned self] in
            self.labelView.text = "Classification: \"\(best.identifier)\" Confidence: \(best.confidence)"
        }
    }
    
    // MARK: Gesture Recognizer Handler
    @objc func imageViewTapHandler(sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        
        imageView.isHidden = true
        labelView.isHidden = true
    }
    
    @objc func sceneTapHandler(sender: UITapGestureRecognizer) {
        
        guard sender.state == .ended else { return }
        
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        addSphereToScene()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([self.rectanglesRequest])
            } catch {
                print(error)
            }
        }
    }
    
    @objc func changeDebuggingStatus(sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        
        isDebuging.toggle()
    }
    
    // MARK: - Method
    fileprivate func setupLabenAndImageView() {
        let tapRecongizer = UITapGestureRecognizer(target: self, action: #selector(imageViewTapHandler))
        
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(white: 0.3, alpha: 0.8)
        imageView.addGestureRecognizer(tapRecongizer)
        imageView.isHidden = true
        
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = labelView.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        labelView.addSubview(blurEffectView)
        labelView.layer.cornerRadius = 8
        labelView.clipsToBounds = true
        labelView.isHidden = true
    }
    
    fileprivate func setupSquareView() {
        squareView.layer.borderWidth  = 2
        squareView.layer.borderColor  = UIColor.gray.cgColor
        squareView.layer.cornerRadius = 16
        squareView.alpha = 0.4
    }
    
    fileprivate func setupSceneView() {
        let tapRecongizer = UITapGestureRecognizer(target: self, action: #selector(sceneTapHandler(sender:)))
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(changeDebuggingStatus(sender:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        
        sceneView.addGestureRecognizer(tapRecongizer)
        sceneView.addGestureRecognizer(doubleTapRecognizer)
        sceneView.delegate = self
    }
    
    func resetTrackingConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        
        sceneView.session.run(configuration, options: options)
    }
    
    func showAim(_ showNeeded: Bool) {
        vertView.isHidden = !showNeeded
        horizView.isHidden = !showNeeded
    }
    
    func addSphereToScene() {
        guard let currentFrame = sceneView.session.currentFrame else { return }
    
        guard let result = sceneView.hitTest(CGPoint(x: 0.5, y: 0.5), types: [.existingPlaneUsingGeometry, .featurePoint]).first else { return }
        
        if isDebuging {
            print("Distance to target: \(result.distance)")
        }
        
        let sphere = SCNSphere(radius: 0.0025)
        let sphereNode = SCNNode(geometry: sphere)
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -Float(result.distance)
        translation = matrix_multiply(currentFrame.camera.transform, translation)
        
        sphereNode.simdTransform = translation
        
        sceneView.scene.rootNode.addChildNode(sphereNode)
    }
}

extension ViewController: ARSCNViewDelegate {
    
}
