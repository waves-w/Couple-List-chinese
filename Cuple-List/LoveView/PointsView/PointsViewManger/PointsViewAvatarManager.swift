//
//  PointsViewAvatarManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import CoreData
import MagicalRecord

class PointsViewAvatarManager {
    
    // MARK: - 单例
    static let shared = PointsViewAvatarManager()
    
    // MARK: - 缓存
    private var cachedAvatars: [String: UIImage] = [:]
    // ✅ 线程安全：使用串行队列保护缓存字典的访问
    private let cacheQueue = DispatchQueue(label: "com.cuplelist.avatarCache", attributes: .concurrent)
    
    private init() {}
    
    // MARK: - 加载用户头像
    /// - Parameter applyAICutout: 是否对头像做抠图+白边效果（与用户页一致）
    func loadUserAvatars(
        user1ImageView: UIImageView,
        user2ImageView: UIImageView,
        isViewLoaded: Bool,
        viewWindow: UIWindow?,
        applyAICutout: Bool = false
    ) {
        guard isViewLoaded, user1ImageView.superview != nil, user2ImageView.superview != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.loadUserAvatars(
                    user1ImageView: user1ImageView,
                    user2ImageView: user2ImageView,
                    isViewLoaded: isViewLoaded,
                    viewWindow: viewWindow,
                    applyAICutout: applyAICutout
                )
            }
            return
        }
        
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let coupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
        
        let needSyncMyInfo = coupleInfo.myAvatar.isEmpty ||
        coupleInfo.myName.isEmpty ||
        coupleInfo.myName == "未知"
        
        if needSyncMyInfo && !currentUUID.isEmpty {
            let db = Firestore.firestore()
            db.collection("users").document(currentUUID).getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.updateAvatarsWithCoupleInfo(
                            coupleInfo: coupleInfo,
                            user1ImageView: user1ImageView,
                            user2ImageView: user2ImageView,
                            isViewLoaded: isViewLoaded,
                            viewWindow: viewWindow,
                            applyAICutout: applyAICutout
                        )
                    }
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    DispatchQueue.main.async {
                        self.updateAvatarsWithCoupleInfo(
                            coupleInfo: coupleInfo,
                            user1ImageView: user1ImageView,
                            user2ImageView: user2ImageView,
                            isViewLoaded: isViewLoaded,
                            viewWindow: viewWindow,
                            applyAICutout: applyAICutout
                        )
                    }
                    return
                }
                
                guard let data = snapshot.data() else {
                    DispatchQueue.main.async {
                        self.updateAvatarsWithCoupleInfo(
                            coupleInfo: coupleInfo,
                            user1ImageView: user1ImageView,
                            user2ImageView: user2ImageView,
                            isViewLoaded: isViewLoaded,
                            viewWindow: viewWindow,
                            applyAICutout: applyAICutout
                        )
                    }
                    return
                }
                
                var needUpdate = false
                if let myModel = UserManger.manager.getUserModelByUUID(currentUUID) {
                    if let firebaseName = data["userName"] as? String,
                       !firebaseName.isEmpty {
                        let shouldUpdateName = (myModel.userName == nil || myModel.userName?.isEmpty == true || myModel.userName == "未知")
                        if shouldUpdateName {
                            myModel.userName = firebaseName
                            needUpdate = true
                        }
                    }
                    
                    if let avatarURL = data["avatarImageURL"] as? String,
                       !avatarURL.isEmpty {
                        let shouldUpdateAvatar = (myModel.avatarImageURL == nil || myModel.avatarImageURL?.isEmpty == true)
                        if shouldUpdateAvatar {
                            myModel.avatarImageURL = avatarURL
                            needUpdate = true
                        }
                    }
                    
                    if needUpdate {
                        DispatchQueue.main.async {
                            do {
                                let context = NSManagedObjectContext.mr_default()
                                guard context.hasChanges else { return }
                                try context.save()
                            } catch {
                                print("❌ [PointsViewAvatarManager] CoreData保存失败: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self = self else { return }
                    let updatedCoupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
                    self.updateAvatarsWithCoupleInfo(
                        coupleInfo: updatedCoupleInfo,
                        user1ImageView: user1ImageView,
                        user2ImageView: user2ImageView,
                        isViewLoaded: isViewLoaded,
                        viewWindow: viewWindow,
                        applyAICutout: applyAICutout
                    )
                }
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateAvatarsWithCoupleInfo(
                coupleInfo: coupleInfo,
                user1ImageView: user1ImageView,
                user2ImageView: user2ImageView,
                isViewLoaded: isViewLoaded,
                viewWindow: viewWindow,
                applyAICutout: applyAICutout
            )
        }
    }
    
    // MARK: - 更新头像信息
    private func updateAvatarsWithCoupleInfo(
        coupleInfo: UserManger.CoupleInfo,
        user1ImageView: UIImageView,
        user2ImageView: UIImageView,
        isViewLoaded: Bool,
        viewWindow: UIWindow?,
        applyAICutout: Bool = false
    ) {
        // ✅ 修复：头像分配应该和分数分配保持一致
        // user1 始终显示当前用户（myAvatar），user2 始终显示伴侣（partnerAvatar）
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        
        let currentGender = currentUser?.gender ?? ""
        let partnerGender = partnerUser?.gender ?? ""
        
        func isFemale(_ gender: String?) -> Bool {
            guard let gender = gender else { return false }
            let lowercased = gender.lowercased().trimmingCharacters(in: .whitespaces)
            return lowercased == "female" || lowercased == "女性" || lowercased == "女"
        }
        
        let currentIsFemale = isFemale(currentGender)
        let partnerIsFemale = isFemale(partnerGender)
        let currentDefault = currentIsFemale ? "femaleImage" : "maleImage"
        let partnerDefault = partnerIsFemale ? "femaleImage" : "maleImage"
        
        loadAvatar(
            imageView: user1ImageView,
            avatarString: coupleInfo.myAvatar,
            defaultImage: currentDefault,
            fallbackImage: currentIsFemale ? "woman" : "man",
            isViewLoaded: isViewLoaded,
            viewWindow: viewWindow,
            applyAICutout: applyAICutout
        )
        
        loadAvatar(
            imageView: user2ImageView,
            avatarString: coupleInfo.partnerAvatar,
            defaultImage: partnerDefault,
            fallbackImage: partnerIsFemale ? "woman" : "man",
            isViewLoaded: isViewLoaded,
            viewWindow: viewWindow,
            applyAICutout: applyAICutout
        )
    }
    
    // MARK: - 加载单个头像（有缓存时直接设缓存，避免「默认图→缓存」导致另一台设备上闪烁）
    func loadAvatar(
        imageView: UIImageView,
        avatarString: String,
        defaultImage: String,
        fallbackImage: String,
        isViewLoaded: Bool,
        viewWindow: UIWindow?,
        applyAICutout: Bool = false
    ) {
        guard imageView.superview != nil else {
            return
        }
        
        let cacheKey = applyAICutout ? "cutout:\(avatarString)" : avatarString
        var cachedImage: UIImage?
        cacheQueue.sync {
            cachedImage = cachedAvatars[cacheKey]
        }
        
        if let cachedImage = cachedImage {
            applyAvatarOnMain(imageView: imageView, image: cachedImage, isViewLoaded: isViewLoaded, viewWindow: viewWindow, applyAICutout: applyAICutout)
            return
        }
        
        let defaultImg = UIImage(named: defaultImage) ?? UIImage(named: fallbackImage)
        applyAvatarOnMain(imageView: imageView, image: defaultImg, isViewLoaded: isViewLoaded, viewWindow: viewWindow, applyAICutout: false)
        
        if !avatarString.isEmpty {
            guard isViewLoaded, viewWindow != nil else {
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                guard let avatarImage = self.imageFromBase64String(avatarString) else {
                    return
                }
                
                if applyAICutout {
                    ImageProcessor.shared.processAvatarWithAICutout(image: avatarImage, borderWidth: 10, cacheKey: avatarString) { [weak self] processedImage in
                        guard let self = self else { return }
                        let finalImage = processedImage ?? avatarImage
                        self.cacheQueue.async(flags: .barrier) {
                            self.cachedAvatars[cacheKey] = finalImage
                        }
                        self.applyAvatarOnMain(imageView: imageView, image: finalImage, isViewLoaded: isViewLoaded, viewWindow: viewWindow, applyAICutout: true)
                    }
                } else {
                    self.cacheQueue.async(flags: .barrier) {
                        self.cachedAvatars[avatarString] = avatarImage
                    }
                    self.applyAvatarOnMain(imageView: imageView, image: avatarImage, isViewLoaded: isViewLoaded, viewWindow: viewWindow, applyAICutout: false)
                }
            }
        }
    }
    
    private func applyAvatarOnMain(imageView: UIImageView, image: UIImage?, isViewLoaded: Bool, viewWindow: UIWindow?, applyAICutout: Bool) {
        let block = {
            guard isViewLoaded, viewWindow != nil else { return }
            guard imageView.superview != nil else { return }
            imageView.image = image
            if applyAICutout {
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = false
                imageView.layer.cornerRadius = 0
                imageView.applyAvatarCutoutShadow()
            } else {
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
            }
        }
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }
    
    // MARK: - Base64 转图片
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        guard !base64String.isEmpty else {
            return nil
        }
        
        guard base64String.count < 2_000_000 else {
            return nil
        }
        
        var base64 = base64String
        if base64.hasPrefix("data:image/"), let range = base64.range(of: ",") {
            base64 = String(base64[range.upperBound...])
        }
        
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        
        guard imageData.count < 1_500_000 else {
            return nil
        }
        
        let imageFormat = detectImageFormat(from: imageData)
        guard imageFormat != .unknown else {
            return nil
        }
        
        let image: UIImage? = autoreleasepool {
            UIImage(data: imageData)
        }
        
        guard let image = image else {
            return nil
        }
        
        guard image.size.width > 0 && image.size.height > 0 else {
            return nil
        }
        
        let pixelCount = image.size.width * image.size.height
        guard pixelCount < 50_000_000 else {
            return nil
        }
        
        return image
    }
    
    // MARK: - 图片格式枚举
    private enum ImageFormat {
        case jpeg
        case png
        case gif
        case unknown
    }
    
    // MARK: - 检测图片格式
    private func detectImageFormat(from data: Data) -> ImageFormat {
        guard data.count >= 4 else { return .unknown }
        
        let bytes = data.prefix(4)
        let hexString = bytes.map { String(format: "%02x", $0) }.joined()
        
        if hexString.hasPrefix("ffd8ff") {
            return .jpeg
        }
        if hexString.hasPrefix("89504e47") {
            return .png
        }
        if hexString.hasPrefix("47494638") {
            return .gif
        }
        
        return .unknown
    }
    
    // MARK: - 清理缓存
    func clearCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.cachedAvatars.removeAll()
        }
    }
}

