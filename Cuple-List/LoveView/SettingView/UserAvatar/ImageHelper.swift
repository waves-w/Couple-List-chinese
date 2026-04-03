//
//  ImageHelper.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageHelper {
    class func imageOrientationToTiffOrientation(_ orientation: UIImage.Orientation) -> Int32 {
        switch orientation {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default:
            return 1
        }
    }
    
    class func generateForegroundMask(from image: UIImage) -> CIImage? {
        guard let ciImage = CIImage(image: image)?.oriented(forExifOrientation: imageOrientationToTiffOrientation(image.imageOrientation)) else { return nil }
        
        // iOS 17.0+ 使用 VNGenerateForegroundInstanceMaskRequest
        if #available(iOS 17.0, *) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage)
            
            do {
                try handler.perform([request])
                if let result = request.results?.first {
                    guard let firstInstance = result.allInstances.first else {
                        print("No instances found.")
                        return nil
                    }
                    let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: [firstInstance], from: handler)
                    return CIImage(cvPixelBuffer: maskPixelBuffer)
                }
            } catch {
                print("Error generating mask: \(error)")
            }
        } else if #available(iOS 15.0, *) {
            // iOS 15.0-16.x 使用 VNGeneratePersonSegmentationRequest（人像分割）
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            
            do {
                try handler.perform([request])
                if let segmentationResult = request.results?.first as? VNPixelBufferObservation {
                    let maskCIImage = CIImage(cvPixelBuffer: segmentationResult.pixelBuffer)
                    // 缩放遮罩到图像尺寸
                    let imageExtent = ciImage.extent
                    let maskWidth = CGFloat(CVPixelBufferGetWidth(segmentationResult.pixelBuffer))
                    let maskHeight = CGFloat(CVPixelBufferGetHeight(segmentationResult.pixelBuffer))
                    let scaleX = imageExtent.width / maskWidth
                    let scaleY = imageExtent.height / maskHeight
                    let scale = CGAffineTransform(scaleX: scaleX, y: scaleY)
                    return maskCIImage.transformed(by: scale)
                }
            } catch {
                print("Error generating person segmentation mask: \(error)")
            }
        }
        
        return nil
    }
    
    class func applyMask(_ mask: CIImage, to image: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = image
        filter.maskImage = mask
        filter.backgroundImage = CIImage.empty()
        return filter.outputImage ?? image
    }
    
    class func convertToUIImage(ciImage: CIImage) -> UIImage? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    class func extractContours(from ciImage: CIImage) -> CGPath? {
        guard let filter = CIFilter(name: "CIColorInvert") else {
            print("无法创建 CIColorInvert 滤镜")
            return nil
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let result = filter.outputImage else { return nil }
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = true
        
        let handler = VNImageRequestHandler(ciImage: result, options: [:])
        do {
            try handler.perform([request])
            if let observation = request.results?.first as? VNContoursObservation {
                return observation.normalizedPath
            }
        } catch {
            print("Error detecting contours: \(error)")
        }
        return nil
    }
    
    class func scaleCGPath(_ path: CGPath, toFit rect: CGRect, parentSize: CGSize) -> CGPath? {
        let scaleX = rect.width
        let scaleY = rect.height
        
        var transform = CGAffineTransform(translationX: 0, y: rect.height)
        transform = transform.scaledBy(x: scaleX, y: -scaleY) // 翻转路径
        
        return path.copy(using: &transform)
    }
}

