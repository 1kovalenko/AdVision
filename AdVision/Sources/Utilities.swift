//
//  Utilities.swift
//  Getting distance in AR
//
//  Created by Kovalenko Ilia on 12/11/2018.
//  Copyright © 2018 Kovalenko Ilia. All rights reserved.
//

import UIKit

extension CGPoint {
    func remaped(from oldSize: CGSize, to newSize: CGSize) -> CGPoint {
        let newX = (self.x * newSize.width) / oldSize.width
        let newY = (self.y * newSize.height) / oldSize.height
        return CGPoint(x: newX, y: newY)
    }
    
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width, y: self.y * size.height)
    }
}

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}

extension CIImage {
    func convertToCGImage() -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(self, from: self.extent) {
            return cgImage
        }
        return nil
    }
}
