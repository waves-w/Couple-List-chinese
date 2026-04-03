//
//  FirebaseImageManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

class FirebaseImageManager {
    static let shared = FirebaseImageManager()
    
    private init() {}
    
    // ✅ 组合两个头像：两个圆形并排「叠在一起但不重叠」（相切或留小间隙，不左右对半裁切）
    func combineAvatars(_ image1: UIImage, _ image2: UIImage, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        let startTime = Date()
        print("🔍 [FirebaseImageManager] combineAvatars 开始 - image1尺寸: \(image1.size), image2尺寸: \(image2.size), 目标size: \(size)")
        
        guard image1.size.width > 0 && image1.size.height > 0 else {
            print("❌ [FirebaseImageManager] image1 尺寸无效: \(image1.size)")
            return nil
        }
        guard image2.size.width > 0 && image2.size.height > 0 else {
            print("❌ [FirebaseImageManager] image2 尺寸无效: \(image2.size)")
            return nil
        }
        guard size.width > 0 && size.height > 0 && size.width < 10000 && size.height < 10000 else {
            print("❌ [FirebaseImageManager] 无效的size: \(size)")
            return nil
        }
        
        let scale = UIScreen.main.scale
        let combinedSize = CGSize(width: size.width * scale, height: size.height * scale)
        guard combinedSize.width > 0 && combinedSize.height > 0 && combinedSize.width < 100000 && combinedSize.height < 100000 else {
            print("❌ [FirebaseImageManager] 无效的combinedSize: \(combinedSize)")
            return nil
        }
        
        // 两个圆并排、不重叠：半径 = min(半宽, 半高)，保证能放下两个圆且不超出高度
        let radiusPt = min(size.width / 4, size.height / 2)
        let radius = max(1, radiusPt * scale)
        let leftCenter = CGPoint(x: radius, y: combinedSize.height / 2)
        let rightCenter = CGPoint(x: combinedSize.width - radius, y: combinedSize.height / 2)
        
        return autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(combinedSize, false, scale)
            defer { UIGraphicsEndImageContext() }
            
            guard let context = UIGraphicsGetCurrentContext() else {
                print("⚠️ FirebaseImageManager: 无法获取图形上下文")
                return nil
            }
            
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: .zero, size: combinedSize))
            
            // 左侧圆形头像（image1）
            let leftRect = CGRect(x: leftCenter.x - radius, y: leftCenter.y - radius, width: radius * 2, height: radius * 2)
            context.saveGState()
            context.addEllipse(in: leftRect)
            context.clip()
            _drawImageAspectFill(image: image1, in: leftRect)
            context.restoreGState()
            
            // 右侧圆形头像（image2）
            let rightRect = CGRect(x: rightCenter.x - radius, y: rightCenter.y - radius, width: radius * 2, height: radius * 2)
            context.saveGState()
            context.addEllipse(in: rightRect)
            context.clip()
            _drawImageAspectFill(image: image2, in: rightRect)
            context.restoreGState()
            
            guard let combinedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                print("❌ [FirebaseImageManager] 无法创建组合图片")
                return nil
            }
            guard combinedImage.size.width > 0 && combinedImage.size.height > 0 else {
                print("❌ [FirebaseImageManager] 生成的组合图片尺寸无效: \(combinedImage.size)")
                return nil
            }
            let totalTime = Date().timeIntervalSince(startTime)
            print("✅ [FirebaseImageManager] 组合头像成功（双圆并排不重叠） - 总耗时: \(String(format: "%.3f", totalTime))秒, 最终尺寸: \(combinedImage.size)")
            return combinedImage
        }
    }
    
    /// 在矩形内按 scaleAspectFill 绘制图片（居中裁剪，填满圆）
    private func _drawImageAspectFill(image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0 && imageSize.height > 0, rect.width > 0 && rect.height > 0 else { return }
        let imageAspect = imageSize.width / imageSize.height
        let rectAspect = rect.width / rect.height
        var drawRect: CGRect
        if imageAspect > rectAspect {
            let drawHeight = rect.height
            let drawWidth = rect.height * imageAspect
            drawRect = CGRect(x: rect.midX - drawWidth / 2, y: rect.minY, width: drawWidth, height: drawHeight)
        } else {
            let drawWidth = rect.width
            let drawHeight = rect.width / imageAspect
            drawRect = CGRect(x: rect.minX, y: rect.midY - drawHeight / 2, width: drawWidth, height: drawHeight)
        }
        image.draw(in: drawRect)
    }
}

