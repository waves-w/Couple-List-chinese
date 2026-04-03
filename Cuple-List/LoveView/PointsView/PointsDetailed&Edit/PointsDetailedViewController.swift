//
//  PointsDetailedViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class PointsDetailedViewController: UIViewController {
    
    var backButton: UIButton!
    var deteButton: UIButton!
    var reButton: UIButton!
    var middleView: PointsBorderGradientView!
    var imageLabel: UILabel!
    var titleLabel: UILabel!
    var notesLabel: UILabel!
    var middleLoveView: UIView!
    var pointsModel: PointsModel?
    let editPopup = PointsEditViewPopup()
    
    // ✅ 保持删除弹窗的引用，防止被释放
    private var deletePopup: DeleteConfirmPopup?
    
    var assignImageView: UIImageView! // 单个头像时使用
    var assignContainerView: UIView! // 两个头像的容器
    var assignLeftImageView: UIImageView! // 左侧头像（双方时使用）
    var assignRightImageView: UIImageView! // 右侧头像（双方时使用）
    
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
        deteButton.setImage(UIImage(named: "delete_icon"), for: .normal)
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
        
        middleView = PointsBorderGradientView()
        middleView.layer.cornerRadius = 22
        view.addSubview(middleView)
        
        middleView.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(272.0 / 375.0)
            make.height.equalToSuperview().multipliedBy(343.0 / 812.0)
            make.centerX.equalToSuperview()
            let xxx107 = view.height() * 107.0 / 812.0
            make.top.equalTo(reButton.snp.bottom).offset(xxx107)
        }
        
        imageLabel = UILabel()
        imageLabel.font = UIFont.systemFont(ofSize: 36)
        middleView.addSubview(imageLabel)
        
        imageLabel.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.left.equalTo(20)
        }
        
        titleLabel = UILabel()
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)
        titleLabel.textColor = .color(hexString: "#322D3A")
        titleLabel.numberOfLines = 2
        middleView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageLabel.snp.bottom).offset(12)
            make.left.equalTo(20)
            make.height.equalTo(48)
            make.width.equalToSuperview().multipliedBy(212.0 / 272.0)
        }
        
        notesLabel = UILabel()
        notesLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        notesLabel.textColor = .color(hexString: "#999DAB")
        notesLabel.numberOfLines = 0
        notesLabel.textAlignment = .center
        middleView.addSubview(notesLabel)
        
        notesLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.width.equalTo(titleLabel)
        }

        // ✅ middle 图片（Shared Aspiration）区块
        middleLoveView = UIView()
        middleView.addSubview(middleLoveView)
        
        middleLoveView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(notesLabel.snp.bottom).offset(20)
            make.width.equalToSuperview().multipliedBy(108.0 / 272.0)
            make.height.equalTo(50)
        }
        
        let loveImage = UIImageView(image: .pinklove)
        middleLoveView.addSubview(loveImage)
        
        loveImage.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalTo(32)
            make.height.equalTo(32)
        }
        
        let loveLabel = GradientMaskLabel()
        loveLabel.text = "Shared Aspiration"
        loveLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 13)!
        loveLabel.gradientStartColor = .color(hexString: "#FF8AD6")
        loveLabel.gradientEndColor = .color(hexString: "#FF6DA5")
        middleLoveView.addSubview(loveLabel)
        
        loveLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        
        // ✅ 添加单个头像视图（单个用户时使用，居中显示）
        assignImageView = UIImageView()
        assignImageView.contentMode = .scaleAspectFill
        assignImageView.clipsToBounds = true
        assignImageView.layer.cornerRadius = 0 // 不使用圆角
        assignImageView.isHidden = true // 默认隐藏，根据 isShared 显示
        middleView.addSubview(assignImageView)
        
        assignImageView.snp.makeConstraints { make in
            make.top.equalTo(middleLoveView.snp.bottom).offset(10) // ✅ 放到 middle 图片下面，间距 10
            make.centerX.equalToSuperview() // ✅ 居中显示
            make.width.equalTo(69)
            make.height.equalTo(89)
        }
        
        // ✅ 添加两个头像的容器视图（双方时使用）
        assignContainerView = UIView()
        assignContainerView.isHidden = true // 默认隐藏
        middleView.addSubview(assignContainerView)
        
        assignContainerView.snp.makeConstraints { make in
            make.top.equalTo(middleLoveView.snp.bottom).offset(10) // ✅ 放到 middle 图片下面，间距 10
            make.centerX.equalToSuperview() // ✅ 容器居中
            make.width.equalTo(138) // 两个头像宽度：69 * 2
            make.height.equalTo(89)
        }
        
        // ✅ 左侧头像
        assignLeftImageView = UIImageView()
        assignLeftImageView.contentMode = .scaleAspectFill
        assignLeftImageView.clipsToBounds = true
        assignLeftImageView.layer.cornerRadius = 0
        assignContainerView.addSubview(assignLeftImageView)
        
        assignLeftImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(69)
            make.height.equalTo(89)
        }
        
        // ✅ 右侧头像
        assignRightImageView = UIImageView()
        assignRightImageView.contentMode = .scaleAspectFill
        assignRightImageView.clipsToBounds = true
        assignRightImageView.layer.cornerRadius = 0
        assignContainerView.addSubview(assignRightImageView)
        
        assignRightImageView.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(69)
            make.height.equalTo(89)
        }
        
        let createdLabel = UILabel()
        createdLabel.text = "Created by your partner"
        createdLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 12)
        createdLabel.textColor = .color(hexString: "#BFC2CC")
        view.addSubview(createdLabel)
        
        createdLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(middleView.snp.bottom).offset(20)
        }
    }
    
    private func bindDataToUI() {
        guard let model = pointsModel else { return }
        // 安全赋值：加 nil 容错
        imageLabel.text = model.wishImage ?? ""
        titleLabel.text = model.titleLabel ?? "无标题"
        notesLabel.text = model.notesLabel ?? "无备注"
        
        // ✅ 根据 isShared 设置头像显示
        updateAssignImage(isShared: model.isShared)
    }
    
    /// 根据性别返回默认头像图名（与 HomeCell/Assign 一致）
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }
    
    // ✅ 更新 assign 头像显示（根据 isShared 显示对应的头像；默认图按性别）
    private func updateAssignImage(isShared: Bool) {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        
        if isShared {
            // ✅ 双方：抠图+双圆组合显示在一个 imageView
            assignImageView.isHidden = false
            assignContainerView.isHidden = true
            loadCombinedAvatar(myUUID: currentUUID, partnerUUID: partnerUUID, imageView: assignImageView)
        } else {
            assignImageView.isHidden = false
            assignContainerView.isHidden = true
            let defaultName = defaultImageName(forGender: currentUser?.gender)
            loadAvatarForUser(uuid: currentUUID, defaultImage: UIImage(named: defaultName), imageView: assignImageView)
        }
    }
    
    // ✅ 进一次不刷新：先读缓存，无则抠图并写入缓存
    private func loadAvatarForUser(uuid: String, defaultImage: UIImage?, imageView: UIImageView) {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.layer.cornerRadius = 0
        imageView.image = defaultImage
        guard let userModel = UserManger.manager.getUserModelByUUID(uuid),
              let avatarString = userModel.avatarImageURL,
              !avatarString.isEmpty else { return }
        if let cached = UserAvatarDisplayCache.shared.imageForSingle(avatarString: avatarString) {
            imageView.image = cached
            imageView.applyAvatarCutoutShadow()
            return
        }
        let outputSize = CGSize(width: 138, height: 178)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let image = self.imageFromBase64String(avatarString) else { return }
            ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 14, outputSize: outputSize, cacheKey: avatarString) { [weak imageView] processed in
                let final = processed ?? image
                UserAvatarDisplayCache.shared.setSingle(final, for: avatarString)
                DispatchQueue.main.async {
                    imageView?.image = final
                    imageView?.contentMode = .scaleAspectFit
                    imageView?.applyAvatarCutoutShadow()
                }
            }
        }
    }
    
    // ✅ 进一次不刷新：先读缓存，无则抠图+组合并写入缓存；Base64 解码在后台
    private func loadCombinedAvatar(myUUID: String, partnerUUID: String, imageView: UIImageView) {
        imageView.image = UIImage(named: "wwwww")
        imageView.contentMode = .scaleAspectFit
        var myAvatarStr = ""; var partnerAvatarStr = ""
        if let s = UserManger.manager.getUserModelByUUID(myUUID)?.avatarImageURL { myAvatarStr = s }
        if let s = UserManger.manager.getUserModelByUUID(partnerUUID)?.avatarImageURL { partnerAvatarStr = s }
        if let cached = UserAvatarDisplayCache.shared.imageForCombined(partnerAvatar: partnerAvatarStr, myAvatar: myAvatarStr) {
            imageView.image = cached
            imageView.applyAvatarCutoutShadow()
            return
        }
        let cutoutSize = CGSize(width: 100, height: 100)
        let combineSize = CGSize(width: 130, height: 90)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var myImage: UIImage? = myAvatarStr.isEmpty ? nil : self.imageFromBase64String(myAvatarStr)
            var partnerImage: UIImage? = partnerAvatarStr.isEmpty ? nil : self.imageFromBase64String(partnerAvatarStr)
            if myImage == nil { myImage = UIImage(named: "wwwww") }
            if partnerImage == nil { partnerImage = UIImage(named: "wwwww") }
            guard let myImg = myImage, let partnerImg = partnerImage else { return }
            var myProcessed: UIImage?
            var partnerProcessed: UIImage?
            let group = DispatchGroup()
            group.enter()
            ImageProcessor.shared.processAvatarWithAICutout(image: myImg, borderWidth: 8, outputSize: cutoutSize, cacheKey: myAvatarStr) { myProcessed = $0 ?? myImg; group.leave() }
            group.enter()
            ImageProcessor.shared.processAvatarWithAICutout(image: partnerImg, borderWidth: 8, outputSize: cutoutSize, cacheKey: partnerAvatarStr) { partnerProcessed = $0 ?? partnerImg; group.leave() }
            group.notify(queue: .main) { [weak imageView] in
                let p = partnerProcessed ?? partnerImg
                let m = myProcessed ?? myImg
                guard let imageView = imageView, let combined = FirebaseImageManager.shared.combineAvatars(p, m, size: combineSize) else { return }
                UserAvatarDisplayCache.shared.setCombined(combined, partnerAvatar: partnerAvatarStr, myAvatar: myAvatarStr)
                imageView.image = combined
                imageView.contentMode = .scaleAspectFit
                imageView.applyAvatarCutoutShadow()
            }
        }
    }
    
    // ✅ 从Base64字符串解码图片
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        // ✅ 检查是否是Base64格式（可能包含前缀 "data:image/jpeg;base64,"）
        var base64 = base64String
        
        // 移除前缀（如果存在）
        if base64.hasPrefix("data:image/") {
            if let range = base64.range(of: ",") {
                base64 = String(base64[range.upperBound...])
            }
        }
        
        // ✅ 解码Base64字符串
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        
        return UIImage(data: imageData)
    }
    
    // ✅ 调整图片尺寸到指定大小
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func reButtonTapped() {
        guard let modelToEdit = self.pointsModel else {
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
    
    func deleteItemTapped() {
        guard let model = self.pointsModel else {
            print("Error: PointsModel is missing. Cannot proceed with deletion.")
            return
        }
        
        // ✅ 使用自定义删除确认弹窗"#"
        self.deletePopup = DeleteConfirmPopup(
            title: "Confirm Deletion",
            message: "Are you sure you want to delete \(model.titleLabel ?? "this record")?",
            imageName: "delete_icon",
            cancelTitle: "Cancel",
            confirmTitle: "Delete",
            confirmBlock: { [weak self] in
                PointsManger.manager.deleteModel(model)
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
