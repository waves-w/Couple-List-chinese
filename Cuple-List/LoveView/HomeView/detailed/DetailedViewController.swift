//
//  DetailedViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class DetailedViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    var backButton: UIButton!
    var deteButton: UIButton!
    var reButton: UIButton!
    var textFiledView: BorderGradientView!
    var titleTextFiled: UITextField!
    /// 预期（逾期）图标，与 HomeCell 一致：逾期时显示在标题后，可点击切换完成状态
    private var expectedImageView: UIImageView!
    var stateImage: UIImageView!
    var notesTextView: UITextView!
    var rightTimeLabel: UILabel!
    var rightPointslabel: UILabel!
    var itemTitle: String?
    var itemNotes: String?
    var itemDate: String?
    var itemPoints: String?
    var listModelToDelete: ListModel?
    private var assignStatusImageView: UIImageView!
    //    var itemDocumentID: String?
    //    private var isCompleted: Bool = false
    let editPopup = EditViewPopup()
    
    // ✅ 保持删除弹窗的引用，防止被释放
    private var deletePopup: DeleteConfirmPopup?
    
    private var isCompleted: Bool = false {
        didSet {
            // 状态变化时自动更新图片（可选：用属性观察器简化代码）
            updateStateImage()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = true
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = true
                tabBarController.homeAddButton?.isHidden = true
            }
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = false
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = false
                tabBarController.homeAddButton?.isHidden = false
            }
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        bindDataToUI()
        addTapGestureToStateImage()
    }
    
    func setUI() {
        
        view.backgroundColor = .white
        
        let inView = ViewGradientView()
        view.addSubview(inView)
        
        inView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backButton = UIButton()
        backButton.setImage(UIImage(named: "breakback"), for: .normal)
        backButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.backButtonTapped()
        }
        view.addSubview(backButton)
        
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        deteButton = UIButton()
        deteButton.setImage(UIImage(named: "delete_icon"), for: .normal) // 假设您有一个名为 "delete_icon" 的图片
        deteButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.deleteItemTapped() // 绑定删除操作
        }
        view.addSubview(deteButton)
        
        deteButton.snp.makeConstraints { make in
            make.right.equalTo(-20)
            make.topMargin.equalTo(24)
        }
        
        reButton = UIButton()
        reButton.setImage(UIImage(named: "edit_icon"), for: .normal)
        reButton.addTarget(self, action: #selector(reButtonTapped), for: .touchUpInside)
        view.addSubview(reButton)
        
        reButton.snp.makeConstraints { make in
            make.right.equalTo(deteButton.snp.left).offset(-20)
            make.centerY.equalTo(deteButton)
        }
        
        textFiledView = BorderGradientView()
        textFiledView.layer.cornerRadius = 18
        view.addSubview(textFiledView)
        
        textFiledView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(24)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(104)
        }
        
        titleTextFiled = UITextField()
        titleTextFiled.attributedPlaceholder = NSAttributedString(string: "Title", attributes: [.foregroundColor : UIColor.color(hexString: "#CACACA")])
        titleTextFiled.layer.cornerRadius = 18
        titleTextFiled.backgroundColor = .clear
        titleTextFiled.keyboardType = .default
        titleTextFiled.returnKeyType = .done
        titleTextFiled.isUserInteractionEnabled = false
        titleTextFiled.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleTextFiled.textColor = .color(hexString: "#322D3A")
        titleTextFiled.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        textFiledView.addSubview(titleTextFiled)
        
        titleTextFiled.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(42.0 / 104.0)
        }
        
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
        titleTextFiled.leftView = leftPaddingView
        titleTextFiled.leftViewMode = .always
        
        expectedImageView = UIImageView(image: UIImage(named: "expectedimage"))
        expectedImageView.isUserInteractionEnabled = true
        expectedImageView.contentMode = .scaleAspectFit
        expectedImageView.isHidden = true
        textFiledView.addSubview(expectedImageView)
        expectedImageView.snp.makeConstraints { make in
            make.left.equalTo(titleTextFiled.snp.right).offset(6)
            make.centerY.equalTo(titleTextFiled)
            make.width.height.equalTo(20)
        }
        
        stateImage = UIImageView(image: .middleButton)
        stateImage.isUserInteractionEnabled = true
        textFiledView.addSubview(stateImage)
        stateImage.snp.makeConstraints { make in
            make.centerY.equalTo(titleTextFiled)
            make.right.equalTo(-14)
            make.width.height.equalTo(30)
            make.left.greaterThanOrEqualTo(expectedImageView.snp.right).offset(8)
        }
        
        titleTextFiled.snp.makeConstraints { make in
            make.right.lessThanOrEqualTo(stateImage.snp.left).offset(-34)
        }
        
        let textFiledLine = UIView()
        textFiledLine.backgroundColor = .color(hexString: "#484848").withAlphaComponent(0.05)
        textFiledView.addSubview(textFiledLine)
        
        textFiledLine.snp.makeConstraints { make in
            make.top.equalTo(titleTextFiled.snp.bottom)
            make.height.equalTo(1)
            make.width.equalToSuperview().multipliedBy(307.0 / 335.0)
            make.centerX.equalToSuperview()
        }
        
        notesTextView = UITextView()
        notesTextView.layer.cornerRadius = 18
        notesTextView.backgroundColor = .clear
        notesTextView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        notesTextView.text = "Notes"
        notesTextView.textColor = .color(hexString: "#322D3A")
        notesTextView.font = UIFont(name: "SFCompactRounded-Medium", size: 15)
        notesTextView.isEditable = false
        notesTextView.textContainerInset = .zero
        notesTextView.textContainer.lineFragmentPadding = 0
        textFiledView.addSubview(notesTextView)
        
        notesTextView.snp.makeConstraints { make in
            make.top.equalTo(textFiledLine.snp.bottom).offset(12)
            make.left.equalTo(15)
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        let deadlineView = BorderGradientView()
        deadlineView.layer.cornerRadius = 18
        view.addSubview(deadlineView)
        
        
        deadlineView.snp.makeConstraints { make in
            make.height.equalTo(52)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(textFiledView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        
        let deadImage = UIImageView(image: .dateimage)
        deadlineView.addSubview(deadImage)
        
        deadImage.snp.makeConstraints { make in
            make.left.equalTo(14)
            make.centerY.equalToSuperview()
        }
        
        let deadLabel = UILabel()
        deadLabel.text = "Deadline"
        deadLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        deadLabel.textColor = .color(hexString: "#322D3A")
        deadlineView.addSubview(deadLabel)
        
        deadLabel.snp.makeConstraints { make in
            make.left.equalTo(deadImage.snp.right).offset(8)
            make.centerY.equalTo(deadlineView)
        }
        
        rightTimeLabel = UILabel()
        rightTimeLabel.textColor = .color(hexString: "#999DAB")
        rightTimeLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        deadlineView.addSubview(rightTimeLabel)
        
        rightTimeLabel.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.centerY.equalToSuperview()
        }
        
//        let pointsView = BorderGradientView()
//        pointsView.layer.cornerRadius = 18
//        view.addSubview(pointsView)
//        
//        pointsView.snp.makeConstraints { make in
//            make.height.equalTo(52)
//            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
//            make.top.equalTo(deadlineView.snp.bottom).offset(16)
//            make.centerX.equalToSuperview()
//        }
        
//        rightPointslabel = UILabel()
//        rightPointslabel.textColor = .color(hexString: "#999DAB")
//        rightPointslabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
//        pointsView.addSubview(rightPointslabel)
//        
//        rightPointslabel.snp.makeConstraints { make in
//            make.right.equalTo(-14)
//            make.centerY.equalToSuperview()
//        }
//        
//        let pointsImage = UIImageView(image: .coin)
//        pointsView.addSubview(pointsImage)
//        
//        pointsImage.snp.makeConstraints { make in
//            make.left.equalTo(14)
//            make.centerY.equalToSuperview()
//        }
//        
//        let pointsLabel = UILabel()
//        pointsLabel.text = "Points Reward"
//        pointsLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
//        pointsLabel.textColor = .color(hexString: "#322D3A")
//        pointsView.addSubview(pointsLabel)
//        
//        pointsLabel.snp.makeConstraints { make in
//            make.left.equalTo(pointsImage.snp.right).offset(8)
//            make.centerY.equalTo(pointsView)
//        }
        
        let particView = BorderGradientView()
        particView.layer.cornerRadius = 18
        view.addSubview(particView)
        
        particView.snp.makeConstraints { make in
            make.height.equalTo(52)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(deadlineView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            //            make.height.equalTo(52)
            //            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            //            make.top.equalTo(pointsView.snp.bottom).offset(16)
            //            make.centerX.equalToSuperview()
        }
        
        let particImage = UIImageView(image: .assignimage)
        particView.addSubview(particImage)
        particImage.snp.makeConstraints { make in
            make.left.equalTo(14)
            make.centerY.equalToSuperview()
        }
        
        let particLabel = UILabel()
        particLabel.text = "ParticciPants"
        particLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        particLabel.textColor = .color(hexString: "#322D3A")
        particView.addSubview(particLabel)
        
        particLabel.snp.makeConstraints { make in
            make.left.equalTo(particImage.snp.right).offset(8)
            make.centerY.equalTo(particView)
        }
        
        assignStatusImageView = UIImageView()
        assignStatusImageView.contentMode = .scaleAspectFit
        assignStatusImageView.clipsToBounds = false
        assignStatusImageView.isHidden = true // 初始隐藏
        particView.addSubview(assignStatusImageView)
        assignStatusImageView.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.centerY.equalToSuperview()
            make.size.equalTo(detailSingleAvatarSize)
        }
        
        let createdLabel = UILabel()
        createdLabel.text = "Created by your partner"
        createdLabel.textColor = .color(hexString: "#BFC2CC")
        createdLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 12)
        view.addSubview(createdLabel)
        
        createdLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(particView.snp.bottom).offset(16)
        }
        
    }
    
    private func addTapGestureToStateImage() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(stateImageTapped))
        stateImage.addGestureRecognizer(tapGesture)
        let expectedTap = UITapGestureRecognizer(target: self, action: #selector(expectedImageViewTapped))
        expectedImageView.addGestureRecognizer(expectedTap)
    }
    
    @objc private func stateImageTapped() {
        guard listModelToDelete != nil else { return }
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        isCompleted = !isCompleted
        updateTaskCompletionStatus()
    }
    
    /// 与 HomeCell 一致：预期（逾期）图标也可点击切换完成状态
    @objc private func expectedImageViewTapped() {
        guard listModelToDelete != nil else { return }
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        isCompleted = !isCompleted
        updateTaskCompletionStatus()
    }
    
    private func updateTaskCompletionStatus() {
        guard let model = listModelToDelete else {
            isCompleted = !isCompleted
            return
        }
        model.isCompleted = isCompleted
        DbManager.manager.updateModel(model)
        updateStateImage()
    }
    
    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func reButtonTapped() {
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        guard let modelToEdit = self.listModelToDelete else {
            print("❌ 无法获取要编辑的模型，编辑失败。")
            return
        }
        
        editPopup.onEditAndCloseComplete = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
        }
        
        editPopup.configureUI(with: modelToEdit)
        editPopup.show(width: view.width(), bottomSpacing: view.window?.safeAreaInsets.bottom ?? 34)
    }
    
    func bindDataToUI() {
        self.titleTextFiled.text = itemTitle
        self.notesTextView.text = itemNotes
        self.rightTimeLabel.text = itemDate ?? "No Date" 
//        self.rightPointslabel.text = itemPoints
        
        
        if let notes = itemNotes, !notes.isEmpty {
            self.notesTextView.text = notes
        } else {
            self.notesTextView.text = "No additional notes provided." // 或者设置为 nil / 隐藏
            self.notesTextView.textColor = .lightGray
        }
        
        if let model = listModelToDelete {
            self.isCompleted = model.isCompleted // 从 Core Data 读取状态
            updateStateImage() // 根据数据库状态设置图片
            // ✅ 始终显示创建时选中的头像（assignIndex）
            let assignIndex = Int(model.assignIndex)
            let displayIndex = displayAssignIndexForCurrentViewer(assignIndex: assignIndex, taskId: model.id)
            updateAssignStatusImage(index: displayIndex)
        }
    }
    
    /// 与 HomeCell 一致：将创建者视角的 assignIndex 转为当前查看者视角（对方看时 0↔1，2 不变）
    private func displayAssignIndexForCurrentViewer(assignIndex: Int, taskId: String?) -> Int {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let creatorUUID = (taskId != nil ? DbManager.manager.getTaskCreatorUUID(taskId: taskId!) : nil) ?? currentUUID
        let isCurrentUserCreator = (creatorUUID == currentUUID)
        if isCurrentUserCreator { return assignIndex }
        if assignIndex == TaskAssignIndex.partner.rawValue { return TaskAssignIndex.myself.rawValue }
        if assignIndex == TaskAssignIndex.myself.rawValue { return TaskAssignIndex.partner.rawValue }
        return assignIndex
    }
    
    /// 根据性别返回默认头像图名（与 HomeSwipeTableCell、PointsViewRecordHelper 一致）
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女性" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }
    
    // ✅ 根据「当前查看者视角」的 index 加载头像（与 HomeSwipeTableCell 一致，默认头像按该用户性别）
    private func updateAssignStatusImage(index: Int) {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        
        switch index {
        case TaskAssignIndex.partner.rawValue:
            assignStatusImageView.snp.updateConstraints { make in make.size.equalTo(detailSingleAvatarSize) }
            assignStatusImageView.isHidden = false
            let partnerDefault = defaultImageName(forGender: partnerUser?.gender)
            loadAvatarForUser(uuid: partnerUUID, defaultImage: UIImage(named: partnerDefault), imageView: assignStatusImageView)
        case TaskAssignIndex.myself.rawValue:
            assignStatusImageView.snp.updateConstraints { make in make.size.equalTo(detailSingleAvatarSize) }
            assignStatusImageView.isHidden = false
            let myDefault = defaultImageName(forGender: currentUser?.gender)
            loadAvatarForUser(uuid: currentUUID, defaultImage: UIImage(named: myDefault), imageView: assignStatusImageView)
        case TaskAssignIndex.both.rawValue:
            assignStatusImageView.snp.updateConstraints { make in make.size.equalTo(detailCombinedAvatarSize) }
            assignStatusImageView.isHidden = false
            loadCombinedAvatar(myUUID: currentUUID, partnerUUID: partnerUUID, imageView: assignStatusImageView)
        default:
            assignStatusImageView.isHidden = true
        }
    }
    
    private let detailSingleAvatarSize: CGFloat = 30
    private let detailCombinedAvatarSize: CGFloat = 60
    
    // ✅ 加载单个用户头像；Base64 解码在后台，避免主线程阻塞
    private func loadAvatarForUser(uuid: String, defaultImage: UIImage?, imageView: UIImageView) {
        imageView.image = defaultImage
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        guard let userModel = UserManger.manager.getUserModelByUUID(uuid),
              let avatarString = userModel.avatarImageURL,
              !avatarString.isEmpty else { return }
        let outputSize = CGSize(width: detailSingleAvatarSize, height: detailSingleAvatarSize)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let image = self.imageFromBase64String(avatarString) else { return }
            ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 8, outputSize: outputSize, cacheKey: avatarString) { [weak imageView] processed in
                let final = processed ?? image
                DispatchQueue.main.async {
                    imageView?.image = final
                    imageView?.contentMode = .scaleAspectFit
                    imageView?.clipsToBounds = false
                    imageView?.applyAvatarCutoutShadow()
                }
            }
        }
    }
    
    // ✅ 加载组合头像；Base64 解码在后台
    private func loadCombinedAvatar(myUUID: String, partnerUUID: String, imageView: UIImageView) {
        imageView.image = UIImage()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        let myModel = UserManger.manager.getUserModelByUUID(myUUID)
        let partnerModel = partnerUUID.isEmpty ? nil : UserManger.manager.getUserModelByUUID(partnerUUID)
        let myAvatarStr = myModel?.avatarImageURL ?? ""
        let partnerAvatarStr = partnerModel?.avatarImageURL ?? ""
        let size = detailCombinedAvatarSize
        let cutoutSize = CGSize(width: size, height: size)
        let combineSize = CGSize(width: size, height: size)
        let myDefault = UIImage(named: defaultImageName(forGender: myModel?.gender))
        let partnerDefault = UIImage(named: defaultImageName(forGender: partnerModel?.gender))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var myImage: UIImage? = myAvatarStr.isEmpty ? nil : self.imageFromBase64String(myAvatarStr)
            var partnerImage: UIImage? = partnerAvatarStr.isEmpty ? nil : self.imageFromBase64String(partnerAvatarStr)
            myImage = myImage ?? myDefault
            partnerImage = partnerImage ?? partnerDefault
            guard let myImg = myImage, let partnerImg = partnerImage else { return }
            var myProcessed: UIImage?
            var partnerProcessed: UIImage?
            let group = DispatchGroup()
            group.enter()
            ImageProcessor.shared.processAvatarWithAICutout(image: myImg, borderWidth: 8, outputSize: cutoutSize, cacheKey: myAvatarStr) { myProcessed = $0 ?? myImg; group.leave() }
            group.enter()
            ImageProcessor.shared.processAvatarWithAICutout(image: partnerImg, borderWidth: 8, outputSize: cutoutSize, cacheKey: partnerAvatarStr) { partnerProcessed = $0 ?? partnerImg; group.leave() }
            group.notify(queue: .main) { [weak imageView] in
                let m = myProcessed ?? myImg
                let p = partnerProcessed ?? partnerImg
                guard let imageView = imageView, let combined = FirebaseImageManager.shared.combineAvatars(p, m, size: combineSize) else { return }
                imageView.image = combined
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = false
                imageView.applyAvatarCutoutShadow()
            }
        }
    }
    
    // ✅ 从Base64字符串解码图片
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        var base64 = base64String
        if base64.hasPrefix("data:image/"), let range = base64.range(of: ",") {
            base64 = String(base64[range.upperBound...])
        }
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    // ✅ 调整图片尺寸
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    /// 与 HomeCell 一致：仅完成/未完成两种圆圈状态；预期图标逾期时显示
    private func updateStateImage() {
        guard let model = listModelToDelete else {
            stateImage.image = UIImage(named: "middleButton")
            expectedImageView.isHidden = true
            return
        }
        stateImage.image = isCompleted ? UIImage(named: "middleButtonSelected") : UIImage(named: "middleButton")
        expectedImageView.isHidden = !model.isOverdue
        updateTextStrikethroughStyle()
    }
    
    /// 与 HomeCell 一致：根据完成/逾期更新标题、备注、时间颜色及删除线
    private func updateTextStrikethroughStyle() {
        guard let model = listModelToDelete else { return }
        let (titleColor, notesColor, timeColor, isStrikethrough): (UIColor, UIColor, UIColor, Bool)
        if model.isCompleted {
            titleColor = .color(hexString: "#C0C0C0")
            notesColor = .color(hexString: "#C0C0C0")
            timeColor = .color(hexString: "#C0C0C0")
            isStrikethrough = true
        } else if model.isOverdue {
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
        rightTimeLabel.textColor = timeColor
        titleTextFiled.textColor = titleColor
        if let title = titleTextFiled.text {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: titleColor,
                .strikethroughStyle: isStrikethrough ? NSUnderlineStyle.single.rawValue : 0,
                .strikethroughColor: titleColor,
                .font: UIFont(name: "SFCompactRounded-Bold", size: 15)!
            ]
            titleTextFiled.attributedText = NSAttributedString(string: title, attributes: attrs)
        }
        let notes = notesTextView.text ?? ""
        let notesAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: notesColor,
            .strikethroughStyle: isStrikethrough ? NSUnderlineStyle.single.rawValue : 0,
            .strikethroughColor: notesColor,
            .font: UIFont(name: "SFCompactRounded-Medium", size: 15)!
        ]
        notesTextView.attributedText = NSAttributedString(string: notes, attributes: notesAttrs)
    }
    
    
    func deleteItemTapped() {
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        guard let model = self.listModelToDelete else {
            print("Error: ListModel is missing. Cannot proceed with deletion.")
            return
        }
        
        // ✅ 使用自定义删除确认弹窗
        self.deletePopup = DeleteConfirmPopup(
            title: "Delete task?",
            message: "Are you sure you want to delete this task?",
            imageName: "delete_icon",
            cancelTitle: "Cancel",
            confirmTitle: "Delete",
            confirmBlock: { [weak self] in
                DbManager.manager.deleteModel(model)
                self?.deletePopup = nil // ✅ 删除后释放引用
                // 只有在用户确认删除后，才返回上一页
                DispatchQueue.main.async {
                    self?.navigationController?.popViewController(animated: true)
                }
            },
            cancelBlock: { [weak self] in
                self?.deletePopup = nil // ✅ 取消后释放引用
            }
        )
        self.deletePopup?.show()
    }
}
