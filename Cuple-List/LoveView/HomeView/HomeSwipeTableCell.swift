//
//  HomeSwipeTableCell.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import MGSwipeTableCell
import CoreData
import MagicalRecord
import ReactiveSwift


class HomeSwipeTableCell: MGSwipeTableCell {
    
    var stateImageView: UIImageView!
    var titleLabel: UILabel!
    /// 逾期（预期）时在 titleLabel 后显示的图标，可点击切换完成状态
    var expectedImageView: UIImageView!
    var notesLabel: UILabel!
    var timeLabel: UILabel!
    var userImage: UIImageView!
    /// 双方任务时左侧头像（伴侣），与 userImage 肩并肩、左压右
    var partnerAvatarImageView: UIImageView!
    var pointsLabel: GradientMaskLabel!
    var underpointsLabel: StrokeShadowLabel!
    var underunderpointsLabel: StrokeShadowLabel!
    /// 分数区域（数字 + 硬币图标），设为 hidden 可隐藏整块分数
    var pointsContainerView: UIView!
    var listModel: ListModel?
    
    // ✅ 用于标识当前 cell 的 UUID，防止异步加载时显示到错误的 cell
    private var currentCellIdentifier: String?
    
    // ✅ 新增：定义单个头像和组合头像的尺寸
    private let singleAvatarSize: CGFloat = 36 // 单个头像更小
    private let combinedAvatarSize: CGFloat = 50 // 组合头像保持原尺寸
    /// 双头像时左头像压右头像的重叠量（肩并肩）
    private let twoAvatarOverlap: CGFloat = 18
    
    var isCompleted: Bool = false {
        didSet {
            updateStateImage()
            updateTextStrikethroughStyle()
        }
    }
    
    var onCompletionStateChanged: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUI()
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setUI() {
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        let viewcontentView = BorderGradientView()
        viewcontentView.layer.cornerRadius = 18
        contentView.addSubview(viewcontentView)
        
        let verticalSpacing: CGFloat = 16.0
        let horizontalPadding: CGFloat = 20.0
        
        viewcontentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(verticalSpacing / 2)
            make.bottom.equalToSuperview().offset(-verticalSpacing / 2)
            make.left.equalToSuperview().offset(horizontalPadding)
            make.right.equalToSuperview().offset(-horizontalPadding)
        }
        
        stateImageView = UIImageView(image: .middleButton)
        stateImageView.isUserInteractionEnabled = true
        viewcontentView.addSubview(stateImageView)
        
        stateImageView.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.top.equalTo(9)
            make.width.height.equalTo(30)
        }
        
        titleLabel = UILabel()
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#322D3A")
        viewcontentView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(stateImageView.snp.right).offset(10)
            make.top.equalTo(12)
        }
        
        expectedImageView = UIImageView(image: UIImage(named: "expectedimage"))
        expectedImageView.isUserInteractionEnabled = true
        expectedImageView.contentMode = .scaleAspectFit
        expectedImageView.isHidden = true
        viewcontentView.addSubview(expectedImageView)
        expectedImageView.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.right).offset(6)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(20)
        }
        
        notesLabel = UILabel()
        notesLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        notesLabel.textColor = .color(hexString: "#999DAB")
        viewcontentView.addSubview(notesLabel)
        
        notesLabel.snp.makeConstraints { make in
            make.left.equalTo(stateImageView.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }
        
        timeLabel = UILabel()
        timeLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        timeLabel.textColor = .color(hexString: "#C0C0C0")
        viewcontentView.addSubview(timeLabel)
        
        timeLabel.snp.makeConstraints { make in
            make.left.equalTo(stateImageView.snp.right).offset(10)
            make.bottom.equalTo(-12)
        }
        
        userImage = UIImageView()
        userImage.backgroundColor = .clear
        userImage.contentMode = .scaleAspectFill
        userImage.layer.backgroundColor = UIColor.clear.cgColor
        viewcontentView.addSubview(userImage)
        userImage.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.top.equalTo(9)
            make.width.height.equalTo(singleAvatarSize)
        }
        
        partnerAvatarImageView = UIImageView()
        partnerAvatarImageView.backgroundColor = .clear
        partnerAvatarImageView.contentMode = .scaleAspectFill
        partnerAvatarImageView.layer.backgroundColor = UIColor.clear.cgColor
        partnerAvatarImageView.isHidden = true
        viewcontentView.addSubview(partnerAvatarImageView)
        partnerAvatarImageView.snp.makeConstraints { make in
            make.right.equalTo(userImage.snp.right).offset(-twoAvatarOverlap)
            make.centerY.equalTo(userImage)
            make.width.height.equalTo(singleAvatarSize)
        }
        
        // 分数容器：便于整体隐藏分数
        pointsContainerView = UIView()
        pointsContainerView.backgroundColor = .clear
        viewcontentView.addSubview(pointsContainerView)
        pointsContainerView.snp.makeConstraints { make in
            make.right.equalTo(-9)
            make.bottom.equalTo(-9)
        }

        underunderpointsLabel = StrokeShadowLabel()
        underunderpointsLabel.text = "-000"
        underunderpointsLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderpointsLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderpointsLabel.shadowBlurRadius = 1.0
        underunderpointsLabel.strokeWidth = -25.0
        underunderpointsLabel.clipsToBounds = false
        underunderpointsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!

        pointsContainerView.addSubview(underunderpointsLabel)
        underunderpointsLabel.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        underpointsLabel = StrokeShadowLabel()
        underpointsLabel.text = "-000"
        underpointsLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        underpointsLabel.shadowOffset = CGSize(width: 0, height: 1)
        underpointsLabel.shadowBlurRadius = 5.0
        underpointsLabel.strokeWidth = -25.0
        underpointsLabel.clipsToBounds = false
        underpointsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!

        pointsContainerView.addSubview(underpointsLabel)
        underpointsLabel.snp.makeConstraints { make in
            make.centerX.equalTo(underunderpointsLabel)
            make.bottom.equalToSuperview()
        }

        pointsLabel = GradientMaskLabel()
        pointsLabel.text = "-000"
        pointsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!
        pointsLabel.gradientStartColor = .color(hexString: "#FFC251")
        pointsLabel.gradientEndColor = .color(hexString: "#FF7738")

        pointsContainerView.addSubview(pointsLabel)
        pointsLabel.snp.makeConstraints { make in
            make.centerX.equalTo(underunderpointsLabel)
            make.bottom.equalToSuperview()
        }

        let pointsImage = UIImageView(image: .coin)
        pointsContainerView.addSubview(pointsImage)
        pointsImage.snp.makeConstraints { make in
            make.right.equalTo(pointsLabel.snp.left)
            make.centerY.equalTo(pointsLabel)
        }

        // 隐藏 HomeCell 上的分数（数字 + 硬币）
        pointsContainerView.isHidden = true
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(stateImageViewTapped))
        stateImageView.addGestureRecognizer(tapGesture)
        let expectedTap = UITapGestureRecognizer(target: self, action: #selector(expectedImageViewTapped))
        expectedImageView.addGestureRecognizer(expectedTap)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        timeLabel.text = nil
        self.backgroundColor = .clear
        expectedImageView.isHidden = true
        userImage.image = nil
        userImage.contentMode = .scaleAspectFill
        userImage.snp.updateConstraints { make in
            make.width.height.equalTo(singleAvatarSize)
        }
        partnerAvatarImageView.image = nil
        partnerAvatarImageView.isHidden = true
        currentCellIdentifier = nil
        listModel = nil
    }
    
    
    @objc private func stateImageViewTapped() {
        guard listModel != nil else { return }
        isCompleted = !isCompleted
        onCompletionStateChanged?(isCompleted)
    }
    
    /// 预期（逾期）图标点击：允许逾期任务在此处点击切换完成状态
    @objc private func expectedImageViewTapped() {
        guard listModel != nil else { return }
        isCompleted = !isCompleted
        onCompletionStateChanged?(isCompleted)
    }
    
    
    private func updateStateImage() {
        stateImageView.image = isCompleted ? UIImage(named: "middleButtonSelected") : UIImage(named: "middleButton")
    }
    
    private func updateTextStrikethroughStyle() {
        guard let listModel = self.listModel else { return }
        
        expectedImageView.isHidden = !listModel.isOverdue
        
        let (titleColor, notesColor, timeColor, isStrikethrough): (UIColor, UIColor, UIColor, Bool)
        if listModel.isCompleted {
            titleColor = .color(hexString: "#C0C0C0")
            notesColor = .color(hexString: "#C0C0C0")
            timeColor = .color(hexString: "#C0C0C0")
            isStrikethrough = true
        } else if listModel.isOverdue {
            titleColor = .color(hexString: "#FA8B76")
            notesColor = .color(hexString: "#999DAB")
            timeColor = .color(hexString: "#C0C0C0")
            isStrikethrough = false
        } else {
            titleColor = .color(hexString: "#322D3A")
            notesColor = .color(hexString: "#999DAB")
            timeColor = .color(hexString: "#C0C0C0")
            isStrikethrough = false
        }
        
        // 更新timeLabel颜色（单独处理）
        timeLabel.textColor = timeColor
        
        // 更新titleLabel
        if let title = titleLabel.text {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: titleColor,
                .strikethroughStyle: isStrikethrough ? NSUnderlineStyle.single.rawValue : 0,
                .strikethroughColor: titleColor,
                .font: UIFont(name: "SFCompactRounded-Bold", size: 15)!
            ]
            titleLabel.attributedText = NSAttributedString(string: title, attributes: attributes)
        }
        
        // 更新notesLabel
        if let notes = notesLabel.text {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: notesColor,
                .strikethroughStyle: isStrikethrough ? NSUnderlineStyle.single.rawValue : 0,
                .strikethroughColor: notesColor,
                .font: UIFont(name: "SFCompactRounded-Medium", size: 13)!
            ]
            notesLabel.attributedText = NSAttributedString(string: notes, attributes: attributes)
        }
    }
    
    // 🌟 工具方法：生成带删除线的富文本
    private func attributedText(with text: String, isCompleted: Bool, isNotes: Bool = false) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            // 文本颜色：已完成时变浅
            .foregroundColor: isCompleted ?
            UIColor.color(hexString: "#999999") : // 已完成文本颜色（浅灰）
            UIColor.color(hexString: "#322D3A"),  // 未完成文本颜色（深灰）
            // 删除线：已完成时显示，颜色与文本一致
                .strikethroughStyle: isCompleted ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: isCompleted ? UIColor.color(hexString: "#999999") : UIColor.clear,
            // 字体：保持原有字体（根据实际字体调整）
            .font: isNotes ?
            UIFont(name: "SFCompactRounded-Medium", size: 15)! :
                UIFont(name: "SFCompactRounded-Bold", size: 15)!
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    /// 根据用户性别返回默认头像图名（HomeCell 默认头像与 Assign 一致按性别显示）
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }
    
    // ✅ 根据 assignIndex 加载用户头像（assignIndex相对于创建者，显示时转换为相对于当前查看者）
    // ✅ 核心逻辑：
    //    - assignIndex 是相对于创建者的：0=创建者给对方的任务，1=创建者给自己的任务，2=双方任务
    //    - 显示时需要转换为相对于当前查看者：
    //      * 如果当前查看者是创建者：assignIndex 不变
    //      * 如果当前查看者是对方：assignIndex 需要转换（0→1, 1→0, 2→2）
    //    - 转换后的显示逻辑：
    //      * 0（给对方的任务）→ 显示伴侣的头像
    //      * 1（给自己的任务）→ 显示自己的头像
    //      * 2（双方任务）→ 显示组合头像，自己永远在右边
    private func loadUserAvatarForAssignIndex(_ assignIndex: Int, cellId: String) {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        let myDefaultName = defaultImageName(forGender: currentUser?.gender)
        let partnerDefaultName = defaultImageName(forGender: partnerUser?.gender)
        
        // ✅ 获取任务的创建者UUID
        guard let listModel = self.listModel, let taskId = listModel.id else {
            return
        }
        let creatorUUID = DbManager.manager.getTaskCreatorUUID(taskId: taskId) ?? currentUUID
        
        // ✅ 判断当前查看者是否是创建者
        let isCurrentUserCreator = (creatorUUID == currentUUID)
        
        // ✅ 将 assignIndex 转换为相对于当前查看者
        // 如果当前查看者是对方，需要转换：0→1, 1→0, 2→2
        let displayAssignIndex: Int
        if isCurrentUserCreator {
            // 当前查看者是创建者，assignIndex 不变
            displayAssignIndex = assignIndex
        } else {
            // 当前查看者是对方，需要转换
            if assignIndex == TaskAssignIndex.partner.rawValue {
                // 创建者给对方的任务 → 在对方看来是给自己的任务
                displayAssignIndex = TaskAssignIndex.myself.rawValue
            } else if assignIndex == TaskAssignIndex.myself.rawValue {
                // 创建者给自己的任务 → 在对方看来是给对方的任务
                displayAssignIndex = TaskAssignIndex.partner.rawValue
            } else {
                // 双方任务，不变
                displayAssignIndex = assignIndex
            }
        }
        
        // ✅ 判断是否是双方任务
        let isBothTask = (displayAssignIndex == TaskAssignIndex.both.rawValue)
        
        if isBothTask {
            // ✅ 双方任务：两个头像肩并肩，左边（伴侣）压着右边（自己）
            partnerAvatarImageView.isHidden = false
            userImage.contentMode = .scaleAspectFill
            userImage.snp.updateConstraints { make in
                make.width.height.equalTo(singleAvatarSize)
            }
            loadAvatarForUser(uuid: partnerUUID, defaultImage: UIImage(named: partnerDefaultName), userImage: partnerAvatarImageView, recordId: cellId)
            loadAvatarForUser(uuid: currentUUID, defaultImage: UIImage(named: myDefaultName), userImage: userImage, recordId: cellId)
        } else {
            partnerAvatarImageView.isHidden = true
            // ✅ 单人任务：根据转换后的 assignIndex 显示对应的头像（相对于当前查看者）
//            userImage.layer.cornerRadius = singleAvatarSize / 2
            userImage.contentMode = .scaleAspectFill
            userImage.snp.updateConstraints { make in
                make.width.height.equalTo(singleAvatarSize) // 单个头像尺寸
            }
            
            switch displayAssignIndex {
            case TaskAssignIndex.partner.rawValue: // 0 = 给对方的任务
                if !partnerUUID.isEmpty {
                    loadAvatarForUser(uuid: partnerUUID, defaultImage: UIImage(named: partnerDefaultName), userImage: userImage, recordId: cellId)
                } else {
                    userImage.image = UIImage(named: partnerDefaultName)
                }
            case TaskAssignIndex.myself.rawValue: // 1 = 给自己的任务
                loadAvatarForUser(uuid: currentUUID, defaultImage: UIImage(named: myDefaultName), userImage: userImage, recordId: cellId)
            default:
                userImage.image = UIImage(named: "assignimage")
            }
        }
        // 立即刷新约束
        self.layoutIfNeeded()
    }
    
    // ✅ 加载单个用户头像：有缓存时直接设缓存，无缓存才设默认再异步加载，避免主页头像一直闪烁（与 Breakdown/PointsView 一致）
    private func loadAvatarForUser(uuid: String, defaultImage: UIImage?, userImage: UIImageView, recordId: String) {
        userImage.accessibilityIdentifier = recordId
        
        let userModel = UserManger.manager.getUserModelByUUID(uuid)
        let avatarString = userModel?.avatarImageURL ?? ""
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        
        if avatarString.isEmpty && uuid == currentUUID && !uuid.isEmpty {
            applyAvatarOnMain(userImage: userImage, recordId: recordId, image: defaultImage, isProcessed: false)
            let db = Firestore.firestore()
            db.collection("users").document(uuid).getDocument { [weak self] snapshot, error in
                guard self != nil else { return }
                guard error == nil, let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else { return }
                
                if let avatarURL = data["avatarImageURL"] as? String, !avatarURL.isEmpty,
                   let myModel = UserManger.manager.getUserModelByUUID(uuid) {
                    myModel.avatarImageURL = avatarURL
                    DispatchQueue.main.async {
                        do {
                            let context = NSManagedObjectContext.mr_default()
                            guard context.hasChanges else { return }
                            try context.save()
                            NotificationCenter.default.post(name: UserManger.dataDidUpdateNotification, object: nil)
                        } catch { }
                    }
                }
            }
            return
        }
        
        guard !avatarString.isEmpty else {
            applyAvatarOnMain(userImage: userImage, recordId: recordId, image: defaultImage, isProcessed: false)
            return
        }
        
        if let cached = UserAvatarDisplayCache.shared.imageForSingle(avatarString: avatarString) {
            applyAvatarOnMain(userImage: userImage, recordId: recordId, image: cached, isProcessed: true)
            return
        }
        
        applyAvatarOnMain(userImage: userImage, recordId: recordId, image: defaultImage, isProcessed: false)
        let avatarSize = singleAvatarSize
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let image = self.imageFromBase64String(avatarString) else { return }
            let cellOutputSize = CGSize(width: avatarSize * 2, height: avatarSize * 2)
            // ✅ 键盘可见时跳过 AI 抠图，只显示原图+圆角，减轻发热
            if KeyboardVisibleFlag.isVisible {
                DispatchQueue.main.async { [weak userImage] in
                    guard let userImage = userImage, userImage.accessibilityIdentifier == recordId, userImage.superview != nil else { return }
                    userImage.image = image
                    userImage.contentMode = .scaleAspectFill
                    userImage.layer.cornerRadius = avatarSize / 2
                    userImage.clipsToBounds = true
                    self.clearAvatarShadow(on: userImage)
                }
                return
            }
            ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 6, outputSize: cellOutputSize, cacheKey: avatarString) { [weak self] processedImage in
                guard let self = self else { return }
                let finalImage = processedImage ?? image
                UserAvatarDisplayCache.shared.setSingle(finalImage, for: avatarString)
                DispatchQueue.main.async { [weak userImage] in
                    guard let userImage = userImage, userImage.accessibilityIdentifier == recordId, userImage.superview != nil else { return }
                    guard image.size.width > 0 && image.size.height > 0 else {
                        userImage.image = defaultImage
                        return
                    }
                    userImage.image = finalImage
                    userImage.contentMode = .scaleAspectFit
                    userImage.clipsToBounds = false
                    userImage.applyAvatarCutoutShadow()
                }
            }
        }
    }
    
    /// 默认头像不显示阴影：与 AddPopup 的 clearAssignStatusAvatarShadow 一致
    private func clearAvatarShadow(on imageView: UIImageView) {
        imageView.layer.shadowOpacity = 0
        if let sub = imageView.layer.sublayers?.first(where: { $0.name == "avatarShadowSecondLayer" }) {
            sub.removeFromSuperlayer()
        } else if let first = imageView.layer.sublayers?.first {
            first.removeFromSuperlayer()
        }
    }

    private func applyAvatarOnMain(userImage: UIImageView, recordId: String, image: UIImage?, isProcessed: Bool) {
        if Thread.isMainThread {
            guard userImage.accessibilityIdentifier == recordId else { return }
            userImage.image = image
            if isProcessed {
                userImage.contentMode = .scaleAspectFit
                userImage.clipsToBounds = false
                userImage.applyAvatarCutoutShadow()
            } else {
                clearAvatarShadow(on: userImage)
            }
        } else {
            DispatchQueue.main.async { [weak self, weak userImage] in
                guard let self = self, let userImage = userImage, userImage.accessibilityIdentifier == recordId else { return }
                userImage.image = image
                if isProcessed {
                    userImage.contentMode = .scaleAspectFit
                    userImage.clipsToBounds = false
                    userImage.applyAvatarCutoutShadow()
                } else {
                    self.clearAvatarShadow(on: userImage)
                }
            }
        }
    }
    
    // ✅ 加载组合头像：有缓存时直接设缓存，无缓存才设占位再异步合成，避免主页头像闪烁
    private func loadCombinedAvatar(myUUID: String, partnerUUID: String, userImage: UIImageView, recordId: String) {
        userImage.accessibilityIdentifier = recordId
        let combinedSize = combinedAvatarSize
        let combineTargetSize = CGSize(width: combinedSize - 8, height: combinedSize - 18)
        let cutoutOutputSize = CGSize(width: 100, height: 100)
        
        var myAvatarStr = ""
        var partnerAvatarStr = ""
        if let m = UserManger.manager.getUserModelByUUID(myUUID)?.avatarImageURL { myAvatarStr = m }
        if let p = UserManger.manager.getUserModelByUUID(partnerUUID)?.avatarImageURL { partnerAvatarStr = p }
        if let cached = UserAvatarDisplayCache.shared.imageForCombined(partnerAvatar: partnerAvatarStr, myAvatar: myAvatarStr) {
            applyAvatarOnMain(userImage: userImage, recordId: recordId, image: cached, isProcessed: true)
            return
        }
        applyAvatarOnMain(userImage: userImage, recordId: recordId, image: UIImage(named: "wwwww"), isProcessed: false)
        // ✅ 键盘可见时跳过双人头像的 AI 抠图+合成，保留占位图，减轻发热
        if KeyboardVisibleFlag.isVisible { return }
        
        let myModel = UserManger.manager.getUserModelByUUID(myUUID)
        let partnerModel = UserManger.manager.getUserModelByUUID(partnerUUID)
        let myDefaultName = defaultImageName(forGender: myModel?.gender)
        let partnerDefaultName = defaultImageName(forGender: partnerModel?.gender)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var myImage: UIImage?
            var partnerImage: UIImage?
            if let myModel = UserManger.manager.getUserModelByUUID(myUUID),
               let s = myModel.avatarImageURL, !s.isEmpty {
                myImage = self.imageFromBase64String(s)
            }
            if myImage == nil { myImage = UIImage(named: myDefaultName) }
            
            if !partnerUUID.isEmpty,
               let partnerModel = UserManger.manager.getUserModelByUUID(partnerUUID),
               let s = partnerModel.avatarImageURL, !s.isEmpty {
                partnerImage = self.imageFromBase64String(s)
            }
            if partnerImage == nil { partnerImage = UIImage(named: partnerDefaultName) }
            
            guard let myImg = myImage ?? UIImage(named: myDefaultName),
                  let partnerImg = partnerImage ?? UIImage(named: partnerDefaultName) else {
                return
            }
            
            // ✅ 两个头像分别抠图，再用 group 等两路都完成再组合
            var myProcessed: UIImage?
            var partnerProcessed: UIImage?
            let group = DispatchGroup()
            
            group.enter()
            ImageProcessor.shared.processAvatarWithAICutout(image: myImg, borderWidth: 8, outputSize: cutoutOutputSize, cacheKey: myAvatarStr) { img in
                myProcessed = img ?? myImg
                group.leave()
            }
            group.enter()
            ImageProcessor.shared.processAvatarWithAICutout(image: partnerImg, borderWidth: 8, outputSize: cutoutOutputSize, cacheKey: partnerAvatarStr) { img in
                partnerProcessed = img ?? partnerImg
                group.leave()
            }
            
            group.notify(queue: .main) { [weak userImage] in
                guard let userImage = userImage, userImage.accessibilityIdentifier == recordId else { return }
                let m = myProcessed ?? myImg
                let p = partnerProcessed ?? partnerImg
                guard let combinedImage = FirebaseImageManager.shared.combineAvatars(p, m, size: combineTargetSize) else { return }
                userImage.image = combinedImage
                userImage.contentMode = .scaleAspectFit
                userImage.clipsToBounds = false
                userImage.applyAvatarCutoutShadow()
                UserAvatarDisplayCache.shared.setCombined(combinedImage, partnerAvatar: partnerAvatarStr, myAvatar: myAvatarStr)
            }
        }
    }
    
    // ✅ 从Base64字符串解码图片（添加异常处理，避免崩溃）
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        guard !base64String.isEmpty else { return nil }
        guard base64String.count < 2_000_000 else { return nil }
        
        var base64 = base64String
        if base64.hasPrefix("data:image/"), let range = base64.range(of: ",") {
            base64 = String(base64[range.upperBound...])
        }
        
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        guard imageData.count < 1_500_000 else { return nil }
        
        let image: UIImage? = autoreleasepool { UIImage(data: imageData) }
        guard let image = image else { return nil }
        guard image.size.width > 0 && image.size.height > 0 else { return nil }
        
        let pixelCount = image.size.width * image.size.height
        guard pixelCount < 50_000_000 else { return nil }
        
        return image
    }
    
    // ✅ 调整图片尺寸到指定大小
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    
    // 配置方法用于将数据模型绑定到 Cell 的 UI 上
    func configure(with listModel: ListModel) {
        self.listModel = listModel
        
        let cellId = listModel.id ?? UUID().uuidString
        currentCellIdentifier = cellId
        
        self.titleLabel.text = listModel.titleLabel
        self.notesLabel.text = listModel.notesLabel ?? "NO Notes"
        self.timeLabel.text = listModel.timeString ?? "NO Time"
        
        let pts = Int(listModel.points)
        if listModel.isOverdue && !listModel.isCompleted {
            self.pointsLabel.text = "-\(pts)"
            self.underpointsLabel.text = "-\(pts)"
            self.underunderpointsLabel.text = "-\(pts)"
        } else {
            self.pointsLabel.text = String(pts)
            self.underpointsLabel.text = String(pts)
            self.underunderpointsLabel.text = String(pts)
        }
        self.isCompleted = listModel.isCompleted
        
        updateTextStrikethroughStyle()
        updateStateImage()
        
        // ✅ 始终显示创建时选中的头像（assignIndex）
        let assignIndex = Int(listModel.assignIndex)
        loadUserAvatarForAssignIndex(assignIndex, cellId: cellId)
    }
}
