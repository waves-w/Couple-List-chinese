//
//  PointsViewRecordHelper.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import CoreData
import MagicalRecord

class PointsViewRecordHelper {
    
    // MARK: - 创建记录视图
    static func createScoreRecordView() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // ✅ 仅单人头像（与 AddViewPopup/Breakdown 一致，不再使用组合/双方肩并肩）
        let partnerAvatarImageView = UIImageView()
        partnerAvatarImageView.contentMode = .scaleAspectFill
        partnerAvatarImageView.clipsToBounds = true
        partnerAvatarImageView.layer.cornerRadius = 12
        partnerAvatarImageView.backgroundColor = .clear
        partnerAvatarImageView.tag = 199
        partnerAvatarImageView.isHidden = true // 始终隐藏
        containerView.addSubview(partnerAvatarImageView)
        partnerAvatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        // ✅ 单人头像：根据 record.targetUserId 显示得分者
        let avatarImageView = UIImageView()
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 12
        avatarImageView.backgroundColor = .clear
        avatarImageView.tag = 200
        containerView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        // Title Label
        let titleLabel = UILabel()
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 14)
        titleLabel.textColor = .color(hexString: "#322D3A")
        titleLabel.tag = 100
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(8)
            make.top.equalToSuperview()
            make.right.lessThanOrEqualToSuperview().offset(-80)
        }
        
        // Notes Label
        let notesLabel = UILabel()
        notesLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        notesLabel.textColor = .color(hexString: "#999DAB")
        notesLabel.tag = 101
        containerView.addSubview(notesLabel)
        notesLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(8)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.right.lessThanOrEqualToSuperview().offset(-80)
        }
        
        // 分数显示（右侧）
        let scoreContainer = UIView()
        containerView.addSubview(scoreContainer)
        scoreContainer.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        // 分数三层Label
        let underunderScoreLabel = StrokeShadowLabel()
        underunderScoreLabel.text = "+000"
        underunderScoreLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderScoreLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderScoreLabel.shadowBlurRadius = 1.0
        underunderScoreLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!
        underunderScoreLabel.tag = 102
        scoreContainer.addSubview(underunderScoreLabel)
        underunderScoreLabel.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        let underScoreLabel = StrokeShadowLabel()
        underScoreLabel.text = "+000"
        underScoreLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        underScoreLabel.shadowOffset = CGSize(width: 0, height: 1)
        underScoreLabel.shadowBlurRadius = 5.0
        underScoreLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!
        underScoreLabel.tag = 103
        scoreContainer.addSubview(underScoreLabel)
        underScoreLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderScoreLabel)
        }
        
        let scoreLabel = GradientMaskLabel()
        scoreLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!
        scoreLabel.gradientStartColor = .color(hexString: "#FFC251")
        scoreLabel.gradientEndColor = .color(hexString: "#FF7738")
        scoreLabel.tag = 104
        scoreContainer.addSubview(scoreLabel)
        scoreLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderScoreLabel)
        }
        
        return containerView
    }
    
    // MARK: - 更新记录视图
    static func updateRecordView(_ recordView: UIView, with record: ScoreRecordModel, allRecords: [ScoreRecordModel] = []) {
        guard let titleLabel = recordView.viewWithTag(100) as? UILabel,
              let notesLabel = recordView.viewWithTag(101) as? UILabel,
              let partnerAvatarImageView = recordView.viewWithTag(199) as? UIImageView,
              let avatarImageView = recordView.viewWithTag(200) as? UIImageView,
              let underunderScoreLabel = recordView.viewWithTag(102) as? StrokeShadowLabel,
              let underScoreLabel = recordView.viewWithTag(103) as? StrokeShadowLabel,
              let scoreLabel = recordView.viewWithTag(104) as? GradientMaskLabel else {
            return
        }
        
        // 更新标题和备注
        titleLabel.text = record.taskTitle
        notesLabel.text = record.taskNotes.isEmpty ? "No Notes" : record.taskNotes
        
        // ✅ 加载头像：仅单人头像（与 AddViewPopup/Breakdown 一致）
        loadAvatarForRecord(recordView: recordView, partnerImageView: partnerAvatarImageView, avatarImageView: avatarImageView, record: record, allRecords: allRecords)
        
        // 根据加减分状态显示：加分 +N、减分 -N、加0分 显示为 0（不是减0）
        let scoreValue = abs(record.score)
        let scoreText: String
        if record.score > 0 {
            scoreText = "+\(scoreValue)"
            scoreLabel.gradientStartColor = .color(hexString: "#FFC251")
            scoreLabel.gradientEndColor = .color(hexString: "#FF7738")
        } else if record.score < 0 {
            scoreText = "-\(scoreValue)"
            scoreLabel.gradientStartColor = .color(hexString: "#FF8251")
            scoreLabel.gradientEndColor = .color(hexString: "#FF3838")
        } else {
            scoreText = "0"
            scoreLabel.gradientStartColor = .color(hexString: "#FFC251")
            scoreLabel.gradientEndColor = .color(hexString: "#FF7738")
        }
        scoreLabel.text = scoreText
        underScoreLabel.text = scoreText
        underunderScoreLabel.text = scoreText
    }
    
    /// 根据性别返回默认头像图名（与 HomeCell/Assign 一致）
    private static func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }
    
    // MARK: - 加载头像：与 HomeCell 一致，用 current/partner 区分「当前设备上的我/对方」，避免另一台设备头像反了
    private static func loadAvatarForRecord(recordView: UIView, partnerImageView: UIImageView, avatarImageView: UIImageView, record: ScoreRecordModel, allRecords: [ScoreRecordModel]) {
        let targetUUID = record.targetUserId
        let singleAvatarSize: CGFloat = 24
        let recordId = record.recordId
        avatarImageView.accessibilityIdentifier = recordId
        partnerImageView.accessibilityIdentifier = recordId
        
        partnerImageView.isHidden = true
        partnerImageView.image = nil
        avatarImageView.layer.cornerRadius = singleAvatarSize / 2
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.snp.remakeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(singleAvatarSize)
        }
        guard !targetUUID.isEmpty else {
            avatarImageView.image = UIImage(named: "assignimage")
            clearAvatarShadow(on: avatarImageView)
            return
        }
        // ✅ 与 HomeCell 一致：用 getCoupleUsers() 的 current/partner 判断「得分者是我还是对方」，用对应 model 的头像与默认图（不单靠 UUID 查，避免另一台设备查错人）
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        let uuidToShow: String
        let defaultName: String
        let avatarURLToUse: String?
        if targetUUID == currentUUID {
            uuidToShow = currentUUID
            defaultName = defaultImageName(forGender: currentUser?.gender)
            avatarURLToUse = currentUser?.avatarImageURL
        } else if targetUUID == partnerUUID {
            uuidToShow = partnerUUID
            defaultName = defaultImageName(forGender: partnerUser?.gender)
            avatarURLToUse = partnerUser?.avatarImageURL
        } else {
            let targetUser = UserManger.manager.getUserModelByUUID(targetUUID)
            defaultName = defaultImageName(forGender: targetUser?.gender)
            avatarURLToUse = targetUser?.avatarImageURL
            uuidToShow = targetUUID
        }
        loadAvatarForUser(imageView: avatarImageView, uuid: uuidToShow, avatarURL: avatarURLToUse, defaultImage: UIImage(named: defaultName), singleSize: singleAvatarSize)
    }
    
    // MARK: - 加载单个用户头像（有缓存时直接设缓存；avatarURL 可选，传入时用传入值，与 HomeCell 一致避免另一台设备查错人）
    private static func loadAvatarForUser(imageView: UIImageView, uuid: String, avatarURL: String? = nil, defaultImage: UIImage?, singleSize: CGFloat) {
        let recordId = imageView.accessibilityIdentifier ?? ""
        imageView.layer.cornerRadius = singleSize / 2
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.snp.updateConstraints { make in make.width.height.equalTo(singleSize) }
        let avatarString: String? = avatarURL.flatMap { $0.isEmpty ? nil : $0 }
            ?? UserManger.manager.getUserModelByUUID(uuid)?.avatarImageURL
        guard let avatarString = avatarString, !avatarString.isEmpty else {
            applyAvatarOnMain(imageView: imageView, recordId: recordId, image: defaultImage, isProcessed: false)
            return
        }
        if let cached = UserAvatarDisplayCache.shared.imageForSingle(avatarString: avatarString) {
            applyAvatarOnMain(imageView: imageView, recordId: recordId, image: cached, isProcessed: true)
            return
        }
        applyAvatarOnMain(imageView: imageView, recordId: recordId, image: defaultImage, isProcessed: false)
        let outputSize = CGSize(width: singleSize * 2, height: singleSize * 2)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = imageFromBase64String(avatarString) else { return }
            ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 6, outputSize: outputSize, cacheKey: avatarString) { processed in
                let final = processed ?? image
                UserAvatarDisplayCache.shared.setSingle(final, for: avatarString)
                DispatchQueue.main.async {
                    guard imageView.accessibilityIdentifier == recordId else { return }
                    imageView.image = final
                    imageView.contentMode = .scaleAspectFit
                    imageView.clipsToBounds = false
                    imageView.applyAvatarCutoutShadow()
                }
            }
        }
    }
    
    /// 默认头像不显示阴影：与 AddPopup 的 clearAssignStatusAvatarShadow 一致
    private static func clearAvatarShadow(on imageView: UIImageView) {
        imageView.layer.shadowOpacity = 0
        if let sub = imageView.layer.sublayers?.first(where: { $0.name == "avatarShadowSecondLayer" }) {
            sub.removeFromSuperlayer()
        } else if let first = imageView.layer.sublayers?.first {
            first.removeFromSuperlayer()
        }
    }

    private static func applyAvatarOnMain(imageView: UIImageView, recordId: String, image: UIImage?, isProcessed: Bool) {
        if Thread.isMainThread {
            guard imageView.accessibilityIdentifier == recordId else { return }
            imageView.image = image
            if isProcessed {
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = false
                imageView.applyAvatarCutoutShadow()
            } else {
                clearAvatarShadow(on: imageView)
            }
        } else {
            DispatchQueue.main.async {
                guard imageView.accessibilityIdentifier == recordId else { return }
                imageView.image = image
                if isProcessed {
                    imageView.contentMode = .scaleAspectFit
                    imageView.clipsToBounds = false
                    imageView.applyAvatarCutoutShadow()
                } else {
                    clearAvatarShadow(on: imageView)
                }
            }
        }
    }
    
    // MARK: - Base64 图片解码
    private static func imageFromBase64String(_ base64String: String) -> UIImage? {
        var base64 = base64String
        if base64.hasPrefix("data:image/"), let range = base64.range(of: ",") {
            base64 = String(base64[range.upperBound...])
        }
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: imageData)
    }
}


