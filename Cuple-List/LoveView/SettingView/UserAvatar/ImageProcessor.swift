//
//  ImageProcessor.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics

class ImageProcessor {
    static let shared = ImageProcessor()
    
    /// ✅ 最终输出图片的像素尺寸（归一化画布，用于控制上传/缓存分辨率；屏幕显示大小由各页 imageView 约束决定）
    static let avatarOutputSize = CGSize(width: 200, height: 200)
    
    /// ✅ 抠图人物在画布中的放大倍率（越大则人物在最终图里占比越大，白边越窄）
    static let cutoutZoomFactor: CGFloat = 3
    
    // ✅ 串行队列，确保同时只有一个 AI 抠图任务在执行
    private let processingQueue = DispatchQueue(label: "com.cuple.imageProcessor", qos: .userInitiated)
    
    /// AI 抠图结果缓存（key 由 cacheKey + borderWidth + outputSize 组成；内存紧张时系统自动驱逐）
    private let cutoutCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 80
        c.totalCostLimit = 80 * 200 * 200 * 4
        return c
    }()
    
    private init() {}
    
    /// 生成缓存 key：同一头像 + 同一参数 命中同一缓存
    private func cacheKey(for key: String, borderWidth: CGFloat, targetSize: CGSize) -> NSString {
        "\(key)_\(borderWidth)_\(targetSize.width)_\(targetSize.height)" as NSString
    }
    
    // ✅ 新的头像处理流程：使用 ImageHelper 方法（基于 ProfileViewController 的实现）
    /// - Parameters:
    ///   - outputSize: 裁剪后最终图片的尺寸；传 nil 使用默认 avatarOutputSize(400×400)，可传如 CGSize(width: 300, height: 300) 自定义
    ///   - cacheKey: 可选；传入时先查缓存，命中则直接回调，否则抠图完成后写入缓存（如 avatarString）
    func processAvatarWithAICutout(
        image: UIImage,
        borderWidth: CGFloat = 14,
        outputSize: CGSize? = nil,
        cacheKey cacheKeyOrNil: String? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        let targetSize = outputSize ?? Self.avatarOutputSize
        if let key = cacheKeyOrNil, !key.isEmpty {
            let cacheKeyObj = self.cacheKey(for: key, borderWidth: borderWidth, targetSize: targetSize)
            if let cached = cutoutCache.object(forKey: cacheKeyObj) {
                DispatchQueue.main.async { completion(cached) }
                return
            }
        }
        processingQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // 用 autoreleasepool 及时释放 CIImage/UIImage 中间产物，降低内存峰值
            autoreleasepool {
            // ✅ iOS 15+ 才支持前景遮罩生成
            guard #available(iOS 15.0, *) else {
                DispatchQueue.main.async { completion(image) }
                return
            }
            
            // ✅ 步骤1：生成前景遮罩
            guard let mask = ImageHelper.generateForegroundMask(from: image) else {
                DispatchQueue.main.async {
                    completion(image)
                }
                return
            }
            
            // ✅ 步骤2：应用遮罩到原图
            guard let ciImage = CIImage(image: image)?.oriented(forExifOrientation: ImageHelper.imageOrientationToTiffOrientation(image.imageOrientation)) else {
                DispatchQueue.main.async {
                    completion(image)
                }
                return
            }
            
            let maskedImage = ImageHelper.applyMask(mask, to: ciImage)
            
            // ✅ 步骤3：转换为 UIImage
            guard let processedImage = ImageHelper.convertToUIImage(ciImage: maskedImage) else {
                DispatchQueue.main.async {
                    completion(image)
                }
                return
            }
    
            
            // ✅ 步骤5：再次从当前抠图生成遮罩并提取轮廓，用于绘制白边（保证轮廓与当前图一致）
            let imageSize = processedImage.size
            let bounds = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            let zoom = Self.cutoutZoomFactor
            if let newMask = ImageHelper.generateForegroundMask(from: processedImage),
               let newPath = ImageHelper.extractContours(from: newMask),
               let scaledPath = ImageHelper.scaleCGPath(newPath, toFit: bounds, parentSize: imageSize),
               let zoomedImage = self.scaleImage(processedImage, by: zoom) {
                var zoomT = CGAffineTransform(scaleX: zoom, y: zoom)
                if let zoomedPath = scaledPath.copy(using: &zoomT),
                   let result = self.addWhiteBorderWithPath(image: zoomedImage, path: zoomedPath, borderWidth: borderWidth),
                   let cropped = self.cropImageToContent(result.image, contentRectInPoints: result.contentRect),
                   let finalImage = self.normalizeToFixedSize(cropped, targetSize: targetSize) {
                    if let key = cacheKeyOrNil, !key.isEmpty {
                        let keyObj = self.cacheKey(for: key, borderWidth: borderWidth, targetSize: targetSize)
                        self.cutoutCache.setObject(finalImage, forKey: keyObj)
                    }
                    DispatchQueue.main.async {
                        completion(finalImage)
                    }
                    return
                }
            }
            
            // ✅ 若步骤5失败，尝试用首帧 mask 的轮廓绘制白边
            if let path = ImageHelper.extractContours(from: mask),
               let scaledPath = ImageHelper.scaleCGPath(path, toFit: bounds, parentSize: imageSize),
               let zoomedImage = self.scaleImage(processedImage, by: zoom) {
                var zoomT = CGAffineTransform(scaleX: zoom, y: zoom)
                if let zoomedPath = scaledPath.copy(using: &zoomT),
                   let result = self.addWhiteBorderWithPath(image: zoomedImage, path: zoomedPath, borderWidth: borderWidth),
                   let cropped = self.cropImageToContent(result.image, contentRectInPoints: result.contentRect),
                   let finalImage = self.normalizeToFixedSize(cropped, targetSize: targetSize) {
                    if let key = cacheKeyOrNil, !key.isEmpty {
                        let keyObj = self.cacheKey(for: key, borderWidth: borderWidth, targetSize: targetSize)
                        self.cutoutCache.setObject(finalImage, forKey: keyObj)
                    }
                    DispatchQueue.main.async {
                        completion(finalImage)
                    }
                    return
                }
            }
            
            // ✅ 如果添加白边失败，仍归一化到统一尺寸后返回
            if let finalImage = self.normalizeToFixedSize(processedImage, targetSize: targetSize) {
                if let key = cacheKeyOrNil, !key.isEmpty {
                    let keyObj = self.cacheKey(for: key, borderWidth: borderWidth, targetSize: targetSize)
                    self.cutoutCache.setObject(finalImage, forKey: keyObj)
                }
                DispatchQueue.main.async {
                    completion(finalImage)
                }
                return
            }
            if let key = cacheKeyOrNil, !key.isEmpty {
                let keyObj = self.cacheKey(for: key, borderWidth: borderWidth, targetSize: targetSize)
                self.cutoutCache.setObject(processedImage, forKey: keyObj)
            }
            DispatchQueue.main.async {
                completion(processedImage)
            }
            }
        }
    }
    
    // ✅ 裁剪图片到指定区域（rect 为像素坐标）
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let cropRect = CGRect(
            x: max(0, rect.origin.x),
            y: max(0, rect.origin.y),
            width: min(rect.width, CGFloat(cgImage.width) - max(0, rect.origin.x)),
            height: min(rect.height, CGFloat(cgImage.height) - max(0, rect.origin.y))
        )
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// 按「点坐标」内容框裁剪，再用于统一尺寸：不随原图布局变化
    private func cropImageToContent(_ image: UIImage, contentRectInPoints: CGRect) -> UIImage? {
        let scale = image.scale
        let pixelRect = CGRect(
            x: contentRectInPoints.origin.x * scale,
            y: contentRectInPoints.origin.y * scale,
            width: contentRectInPoints.width * scale,
            height: contentRectInPoints.height * scale
        )
        return cropImage(image, to: pixelRect)
    }
    
    /// 白边+两层阴影，并返回「内容框」contentRect（轮廓+白边+阴影的包围框，用于后续裁成统一尺寸）
    private func addWhiteBorderWithPath(image: UIImage, path: CGPath, borderWidth: CGFloat) -> (image: UIImage, contentRect: CGRect)? {
        let imageSize = image.size
        let scale = image.scale
        let borderWidthScaled = borderWidth * scale
        let whiteBorderLineWidth = borderWidthScaled * 6.5
        
        let shadow1Blur: CGFloat = 5.0
        let shadow2Blur: CGFloat = 1.0
        let shadowPadding = (shadow1Blur + shadow2Blur) * 2 + 4
        
        let canvasSize = CGSize(
            width: imageSize.width + (whiteBorderLineWidth + shadowPadding) * 2,
            height: imageSize.height + (whiteBorderLineWidth + shadowPadding) * 2
        )
        
        let offsetX = whiteBorderLineWidth + shadowPadding
        let offsetY = whiteBorderLineWidth + shadowPadding
        var transform = CGAffineTransform(translationX: offsetX, y: offsetY)
        guard let translatedPath = path.copy(using: &transform) else {
            return nil
        }
        
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.clear(CGRect(origin: .zero, size: canvasSize))
        
        let shadow1Offset = CGSize(width: 0, height: 1)
        let shadow1Alpha: CGFloat = 0.1
        let shadow2Offset = CGSize(width: 0, height: 1)
        let shadow2Alpha: CGFloat = 0.05
        
        // ✅ 1）第一层阴影
        context.saveGState()
        context.setShadow(offset: shadow1Offset, blur: shadow1Blur, color: UIColor.black.withAlphaComponent(shadow1Alpha).cgColor)
        context.setFillColor(UIColor.black.cgColor)
        context.addPath(translatedPath)
        context.fillPath()
        context.restoreGState()
        
        // ✅ 2）第二层阴影
        context.saveGState()
        context.setShadow(offset: shadow2Offset, blur: shadow2Blur, color: UIColor.black.withAlphaComponent(shadow2Alpha).cgColor)
        context.setFillColor(UIColor.black.cgColor)
        context.addPath(translatedPath)
        context.fillPath()
        context.restoreGState()
        
        // ✅ 3）按轮廓裁剪并绘制抠图
        context.saveGState()
        context.addPath(translatedPath)
        context.clip()
        let imageRect = CGRect(x: offsetX, y: offsetY, width: imageSize.width, height: imageSize.height)
        image.draw(in: imageRect)
        context.restoreGState()
        
        // ✅ 4）白边
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(whiteBorderLineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.addPath(translatedPath)
        context.strokePath()
        
        guard let resultImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        // ✅ 内容框：轮廓包围盒 + 白边半宽 + 阴影留白，再限制在画布内
        let pathBounds = translatedPath.boundingBox
        let expand = whiteBorderLineWidth / 2 + shadowPadding
        var contentRect = pathBounds.insetBy(dx: -expand, dy: -expand)
        contentRect = contentRect.intersection(CGRect(origin: .zero, size: canvasSize))
        guard contentRect.width >= 1, contentRect.height >= 1 else {
            return (resultImage, CGRect(origin: .zero, size: canvasSize))
        }
        return (resultImage, contentRect)
    }
    
    /// 按比例缩放图片（等比，不拉伸）
    private func scaleImage(_ image: UIImage, by scaleFactor: CGFloat) -> UIImage? {
        guard scaleFactor > 0 else { return nil }
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
        guard newSize.width >= 1, newSize.height >= 1 else { return nil }
        let scale = image.scale
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // ✅ 将图片归一化到固定尺寸：等比缩放并居中绘制，画布统一为 targetSize（透明边留白）
    private func normalizeToFixedSize(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let fitRect = CGRect(
            x: (targetSize.width - drawWidth) / 2,
            y: (targetSize.height - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
        let renderScale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(targetSize, false, renderScale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.clear(CGRect(origin: .zero, size: targetSize))
        image.draw(in: fitRect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // ✅ 图片缩放至指定尺寸
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        guard size.width > 0 && size.height > 0 else { return nil }
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // ✅ 取消所有正在进行的处理任务（保留方法以兼容，但串行队列会自动处理）
    func cancelAllProcessing() {
        // 串行队列会自动处理，不需要手动取消
    }
    
    /// 清空 AI 抠图缓存（如用户切换账号/头像更新时与 UserAvatarDisplayCache.clear() 一并调用）
    func clearCutoutCache() {
        cutoutCache.removeAllObjects()
    }
    
    // ✅ 抠图并添加白边（仅用于显示，不保存）- 使用新的 ImageHelper 方法
    func removeBackgroundAndAddWhiteBorder(
        image: UIImage,
        borderWidth: CGFloat = 14,
        completion: @escaping (UIImage?) -> Void
    ) {
        // ✅ 直接使用新的轮廓裁剪方法
        self.processAvatarWithAICutout(image: image, borderWidth: borderWidth, completion: completion)
    }
}
