//
//  PointsView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit
import CoreData
import MagicalRecord

struct WishItem {
    let id: String
    let title: String
    let notes: String
    let timestamp: Date
    let isShared: Bool
    let points: Int
    let wishImage: String
}

private class AnimationDelegate: NSObject, CAAnimationDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            completion()
        }
    }
}

private struct AssociatedKeys {
    static var animationDelegate = "animationDelegate"
}

class PointsView: UIViewController {
    var addwishButon: UIButton!
    var userPointsView: UIView!
    /// 从 userPointsView 到 wishlist 底部的整体滚动容器
    private var mainScrollView: UIScrollView!
    private var scrollContentView: UIView!
    /// wishlist 表格高度约束（随 contentSize 更新，实现整体滑动）
    private var wishlistHeightConstraint: Constraint?
    private var wishlistContentSizeObservation: NSKeyValueObservation?
    
    
    var user1heardView: UIImageView!
    var user1underheardView: UIImageView!
    var upblueView: UIImageView!
    
    var user2heardView: UIImageView!
    var user2underheardView: UIImageView!
    var upinkView: UIImageView!
    
    // ✅ 波浪和气泡效果管理器
    private let blueLiquidManager = LiquidAnimationManager()
    private let pinkLiquidManager = LiquidAnimationManager()
    private var hasShownBubbles: Bool = false // ✅ 标记是否已展示过气泡
    
    // ✅ 保存矩形视图的底部约束，用于控制上下移动
    private var upblueViewBottomConstraint: Constraint?
    private var upinkViewBottomConstraint: Constraint?
    
    var user1ImageView: UIImageView!
    var user1PointsLabel: GradientMaskLabel!
    var underuser1PointsLabel: StrokeShadowLabel!
    var underunderuser1PointsLabel: StrokeShadowLabel!
    
    var user2ImageView: UIImageView!
    var user2PointsLabel: GradientMaskLabel!
    var underuser2PointsLabel: StrokeShadowLabel!
    var underunderuser2PointsLabel: StrokeShadowLabel!
    var breakButton: UIButton!
    var wishLabel: UILabel!
    var wishViewPopup = WishViewPopup()
    var pointsViewPopup = PointsViewPopup()
    let wishtableView = PointsTableViewController()
    private var unlinkPopup: UnlinkConfirmPopup?
    
    var record1View: UIView!
    var record2View: UIView!
    /// breakdown 区域两条记录之间的分隔线（仅一条记录时隐藏）
    private var breakdownLineView: UIView!
    /// breakdown 按钮高度约束（一条记录时缩小，两条时恢复）
    private var breakButtonHeightConstraint: Constraint?
    var recordsEmptyImageView: UIImageView!
    var wishListEmptyImageView: UIImageView!
    var allEmptyImageView: UIImageView!
    private var emptyStateManager: PointsViewEmptyStateManager!
    private var isFirstLoad = true
    
    // ✅ 添加操作取消标记，用于在视图消失时取消未完成的操作
    private var isViewActive = false
    private var pendingOperations: [DispatchWorkItem] = []
    
    // ✅ 对方设备上 breakdown 防抖：避免「自己+伴侣」两路分数通知导致 breakdown 区域反复刷新、cell 上下跳动
    private var loadRecentScoreRecordsWorkItem: DispatchWorkItem?
    private let loadRecentScoreRecordsDebounceInterval: TimeInterval = 0.35
    /// 上次 breakdown 展示的条数 + 两条记录的 recordId，用于去重避免无变化时重复 layout
    private var lastBreakdownRecordCount: Int = -1
    private var lastBreakdownRecord1Id: String?
    private var lastBreakdownRecord2Id: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emptyStateManager = PointsViewEmptyStateManager(pointsView: self)
        setUI()
        
        loadAndBindCoupleScore()
        wishViewPopup.pointsView = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshScoreWhenChanged),
            name: ScoreDidUpdateNotification,
            object: nil
        )
        
        // ✅ 仅在用户修改头像时刷新头像，不监听 dataDidUpdate 避免频繁刷新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avatarDidUpdate),
            name: UserManger.avatarDidUpdateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wishDataDidUpdate),
            name: PointsManger.dataDidUpdateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wishListDataDidChange),
            name: NSNotification.Name("WishListDataDidChange"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleDidUnlink),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
        
        // ✅ 不监听 DbManager.dataDidUpdateNotification，避免与本地操作冲突导致用户数据搞反
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadUserAvatars()
        }
        
        // 根据 wishlist 表格 contentSize 更新高度，使整体 scrollView 可正确滚动
        wishlistContentSizeObservation = wishtableView.tableView.observe(\.contentSize, options: [.new, .initial]) { [weak self] _, _ in
            self?.updateWishlistHeightFromContentSize()
        }
    }
    
    /// 上次用于 wishlist 高度约束的值，避免无变化时反复 update 触发多余布局（降低 GPU）
    private var lastWishlistHeight: CGFloat = -1
    
    private func updateWishlistHeightFromContentSize() {
        guard wishtableView.isViewLoaded else { return }
        let contentHeight = wishtableView.tableView.contentSize.height
        let minHeight: CGFloat = 200
        let height = max(minHeight, contentHeight)
        guard height != lastWishlistHeight else { return }
        lastWishlistHeight = height
        wishlistHeightConstraint?.update(offset: height)
    }
    
    /// 仅在收到「修改头像」通知时刷新头像（不监听 dataDidUpdate）；breakdown 区域头像也需刷新
    @objc private func avatarDidUpdate() {
        guard isViewLoaded, view.window != nil, !isBeingDismissed else { return }
        loadUserAvatars()
        loadRecentScoreRecords() // breakdown 区域头像跟随用户设置和修改
    }
    
    @objc private func wishDataDidUpdate() {
        // ✅ 优化：检查视图是否仍然活跃，避免在页面切换时执行耗时操作
        guard isViewActive, isViewLoaded, view.window != nil, !isBeingDismissed else {
            return
        }
        
        // ✅ 使用后台线程执行耗时操作，避免阻塞主线程
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isViewActive else {
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self,
                      self.isViewActive,
                      self.isViewLoaded,
                      self.view.window != nil,
                      !self.isBeingDismissed else {
                    return
                }
                // ✅ 移除手动刷新，NSFetchedResultsController 会自动更新 UI
                // ✅ 不需要调用 performFetch() 和 reloadData()，避免与自动更新机制冲突
                self.emptyStateManager?.updateEmptyStatesWithCurrentData()
                self.loadAndBindCoupleScore()
                self.loadRecentScoreRecords()
            }
        }
        
        pendingOperations.append(workItem)
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    @objc private func wishListDataDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // ✅ 修复：确保视图已加载且活跃时才更新空状态
            guard self.isViewActive, self.isViewLoaded, self.view.window != nil else {
                return
            }
            let hasWishData = (notification.userInfo?["hasData"] as? Bool) ?? false
            let hasRecordData = !self.record1View.isHidden || !self.record2View.isHidden
            self.emptyStateManager?.updateEmptyStates(hasRecordData: hasRecordData, hasWishData: hasWishData)
        }
    }
    
    deinit {
        // ✅ 标记视图为非活跃状态
        isViewActive = false
        
        // ✅ 取消所有待执行的操作
        pendingOperations.forEach { $0.cancel() }
        pendingOperations.removeAll()
        
        wishlistContentSizeObservation?.invalidate()
        wishlistContentSizeObservation = nil
        
        NotificationCenter.default.removeObserver(self)
        ImageProcessor.shared.cancelAllProcessing()
        PointsViewAvatarManager.shared.clearCache()
    }
    
    /// 上次 viewDidLayoutSubviews 内执行“高度/contentSize 同步”的时间，用于节流、降低 GPU
    private static var lastLayoutSyncTime: CFTimeInterval = 0
    private static let layoutSyncThrottle: CFTimeInterval = 0.15
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // ✅ 爱心遮罩只设置一次（mask == nil 时）
        if user1underheardView?.layer.mask == nil {
            setupHeartMaskForContainer(user1underheardView!)
        }
        if user2underheardView?.layer.mask == nil {
            setupHeartMaskForContainer(user2underheardView!)
        }
        // ✅ 节流：避免每次 layout 都改约束/contentSize，减少重复布局与 GPU 占用
        let now = CACurrentMediaTime()
        guard now - Self.lastLayoutSyncTime >= Self.layoutSyncThrottle else { return }
        Self.lastLayoutSyncTime = now
        updateWishlistHeightFromContentSize()
        if mainScrollView != nil, scrollContentView != nil {
            let size = scrollContentView.bounds.size
            if size.height > 0, mainScrollView.contentSize != size {
                mainScrollView.contentSize = size
            }
        }
    }
    
    // ✅ 为容器视图设置固定的爱心遮罩
    private func setupHeartMaskForContainer(_ containerView: UIImageView) {
        guard let maskImage = UIImage(named: "upheard"),
              containerView.bounds.width > 0 && containerView.bounds.height > 0 else {
            return
        }
        
        let maskLayer: CALayer
        if let existingMask = containerView.layer.mask {
            maskLayer = existingMask
        } else {
            maskLayer = CALayer()
            containerView.layer.mask = maskLayer
        }
        
        maskLayer.contents = maskImage.cgImage
        maskLayer.contentsGravity = .resizeAspect
        maskLayer.frame = containerView.bounds
    }
    
    // ✅ 通过移动矩形视图的位置来实现填充效果
    private func applyHeartMask(maskView: UIImageView, targetView: UIImageView, fillRatio: CGFloat, animated: Bool = true) {
        guard targetView.bounds.width > 0 && targetView.bounds.height > 0,
              let containerView = targetView.superview else {
            return
        }
        
        let clampedRatio = max(0, min(1, fillRatio))
        let containerHeight = containerView.bounds.height
        
        // ✅ 计算矩形视图应该移动到的位置
        // fillRatio = 0 时，矩形完全在底部（隐藏）
        // fillRatio = 1 时，矩形完全填充（底部对齐）
        // 矩形需要向上移动的距离 = 容器高度 * (1 - fillRatio)
        let offsetY = containerHeight * (1 - clampedRatio)
        
        // ✅ 获取对应的约束
        let bottomConstraint: Constraint?
        if targetView == upblueView {
            bottomConstraint = upblueViewBottomConstraint
        } else if targetView == upinkView {
            bottomConstraint = upinkViewBottomConstraint
        } else {
            return
        }
        
        guard let constraint = bottomConstraint else { return }
        
        // ✅ 如果不需要动画，直接更新约束
        if !animated {
            constraint.update(offset: offsetY)
            containerView.layoutIfNeeded()
            
            // ✅ 更新波浪和气泡
            if targetView == upblueView {
                blueLiquidManager.updateWaveAndBubbles(for: targetView, fillRatio: clampedRatio, shouldShowBubbles: !hasShownBubbles)
            } else if targetView == upinkView {
                pinkLiquidManager.updateWaveAndBubbles(for: targetView, fillRatio: clampedRatio, shouldShowBubbles: !hasShownBubbles)
            }
            return
        }
        
        // ✅ 动画更新约束（平滑缓动，无回弹效果）
        UIView.animate(withDuration: 1.2, delay: 0, options: .curveEaseOut, animations: {
            constraint.update(offset: offsetY)
            containerView.layoutIfNeeded()
        }) { [weak self] _ in
            guard let self = self else { return }
            
            // ✅ 动画完成后更新波浪和气泡
            if targetView == self.upblueView {
                self.blueLiquidManager.updateWaveAndBubbles(for: targetView, fillRatio: clampedRatio, shouldShowBubbles: !self.hasShownBubbles)
            } else if targetView == self.upinkView {
                self.pinkLiquidManager.updateWaveAndBubbles(for: targetView, fillRatio: clampedRatio, shouldShowBubbles: !self.hasShownBubbles)
            }
            
            // ✅ 标记已展示过气泡
            if !self.hasShownBubbles {
                self.hasShownBubbles = true
            }
        }
        
        // ✅ 同时更新波浪（气泡只在动画完成后创建，避免重复）
        if targetView == upblueView {
            blueLiquidManager.updateWaveAndBubbles(for: targetView, fillRatio: clampedRatio, shouldShowBubbles: !hasShownBubbles)
        } else if targetView == upinkView {
            pinkLiquidManager.updateWaveAndBubbles(for: targetView, fillRatio: clampedRatio, shouldShowBubbles: !hasShownBubbles)
        }
    }
    
    private func applyHeartMaskToBlueView(fillRatio: CGFloat, animated: Bool = true) {
        guard user1underheardView != nil, upblueView != nil else { return }
        applyHeartMask(maskView: user1underheardView, targetView: upblueView, fillRatio: fillRatio, animated: animated)
    }
    
    private func applyHeartMaskToPinkView(fillRatio: CGFloat, animated: Bool = true) {
        guard user2underheardView != nil, upinkView != nil else { return }
        applyHeartMask(maskView: user2underheardView, targetView: upinkView, fillRatio: fillRatio, animated: animated)
    }
    
    // ✅ 辅助方法：设置分数标签（图片永远在文本左边，整体居中于头像）
    private func setupPointsLabels(
        container: UIView,
        coinImage: UIImageView,
        isLeftSide: Bool
    ) -> (underUnderLabel: StrokeShadowLabel, underLabel: StrokeShadowLabel, gradientLabel: GradientMaskLabel) {
        // ✅ 最底层标签
        let underUnderLabel = StrokeShadowLabel()
        underUnderLabel.text = "-000"
        underUnderLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        underUnderLabel.textColor = .white
        underUnderLabel.strokeColor = .white
        underUnderLabel.strokeWidth = -25.0
        underUnderLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underUnderLabel.shadowOffset = CGSize(width: 0, height: 1)
        underUnderLabel.shadowBlurRadius = 1.0
        underUnderLabel.clipsToBounds = false
        container.addSubview(underUnderLabel)
        
        // ✅ 图片永远在文本左边（左右两侧都一样）
        // 文本在coin图片右边，确保容器能包裹所有内容
        underUnderLabel.snp.makeConstraints { make in
            make.left.equalTo(coinImage.snp.right).offset(-8) // ✅ coin图片和分数之间的间距
            make.centerY.equalTo(coinImage)
            make.right.lessThanOrEqualToSuperview() // ✅ 允许容器包裹内容
        }
        
        // ✅ 中间层标签
        let underLabel = StrokeShadowLabel()
        underLabel.text = "-000"
        underLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        underLabel.textColor = .white
        underLabel.strokeColor = .white
        underLabel.strokeWidth = -25.0
        underLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        underLabel.shadowOffset = CGSize(width: 0, height: 1)
        underLabel.shadowBlurRadius = 5.0
        underLabel.clipsToBounds = false
        container.addSubview(underLabel)
        underLabel.snp.makeConstraints { make in
            make.center.equalTo(underUnderLabel)
        }
        
        // ✅ 最上层渐变标签
        let gradientLabel = GradientMaskLabel()
        gradientLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        gradientLabel.gradientStartColor = .color(hexString: "#FFC251")
        gradientLabel.gradientEndColor = .color(hexString: "#FF7738")
        container.addSubview(gradientLabel)
        gradientLabel.snp.makeConstraints { make in
            make.center.equalTo(underUnderLabel)
        }
        
        return (underUnderLabel, underLabel, gradientLabel)
    }
    
    /// 根据双方性别设置爱心颜色：双男都蓝，双女都粉，一男一女则左己右伴（男左蓝右粉，女左粉右蓝）
    private func updateHeartColorsByGender() {
        guard upblueView != nil, upinkView != nil else { return }
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let myGender = currentUser?.gender ?? ""
        let partnerGender = partnerUser?.gender ?? ""
        let isFemale: (String) -> Bool = { g in
            let t = g.lowercased().trimmingCharacters(in: .whitespaces)
            return t == "female" || t == "女性" || t == "女"
        }
        let myFemale = isFemale(myGender)
        let partnerFemale = isFemale(partnerGender)
        
        if !myFemale && !partnerFemale {
            // 双男：都蓝色
            upblueView.image = .blueheard
            upinkView.image = .blueheard
        } else if myFemale && partnerFemale {
            // 双女：都粉色
            upblueView.image = .pinkheard
            upinkView.image = .pinkheard
        } else {
            // 一男一女：左己右伴
            if myFemale {
                upblueView.image = .pinkheard
                upinkView.image = .blueheard
            } else {
                upblueView.image = .blueheard
                upinkView.image = .pinkheard
            }
        }
    }

    private func updateHeartFills(myScore: Int, partnerScore: Int, isEntryAnimation: Bool = false) {
        guard user1underheardView != nil, user2underheardView != nil,
              upblueView != nil, upinkView != nil else {
            return
        }
        
        // ✅ 新的填充逻辑：基于两个分数的总和计算占比
        // 如果单个分数超过1万分，显示满爱心
        // 否则按占总和的比例显示
        // ✅ 如果分数是负数（扣分），不显示填充
        
        let totalScore = myScore + partnerScore
        let leftFillRatio: CGFloat
        let rightFillRatio: CGFloat
        
        if totalScore == 0 {
            // ✅ 两个分数都为0，都不显示
            leftFillRatio = 0.0
            rightFillRatio = 0.0
        } else {
            // ✅ 如果分数是负数（扣分），不显示填充
            if myScore < 0 {
                leftFillRatio = 0.0
            } else if myScore >= 10000 {
                // ✅ 如果单个分数超过1万分，显示满爱心
                leftFillRatio = 1.0
            } else {
                // ✅ 否则按占总和的比例显示
                leftFillRatio = CGFloat(myScore) / CGFloat(totalScore)
            }
            
            // ✅ 如果分数是负数（扣分），不显示填充
            if partnerScore < 0 {
                rightFillRatio = 0.0
            } else if partnerScore >= 10000 {
                // ✅ 如果单个分数超过1万分，显示满爱心
                rightFillRatio = 1.0
            } else {
                // ✅ 否则按占总和的比例显示
                rightFillRatio = CGFloat(partnerScore) / CGFloat(totalScore)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.user1underheardView != nil,
                  self.user2underheardView != nil,
                  self.upblueView != nil,
                  self.upinkView != nil,
                  self.upblueView?.bounds.width ?? 0 > 0,
                  self.upinkView?.bounds.width ?? 0 > 0 else {
                return
            }
            
            // ✅ 检查是否需要更新空状态（两个分数都为0）
            let shouldUpdateEmptyState = (leftFillRatio == 0.0 && rightFillRatio == 0.0)
            
            if isEntryAnimation {
                self.applyHeartMaskToBlueView(fillRatio: 0, animated: false)
                self.applyHeartMaskToPinkView(fillRatio: 0, animated: false)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    self.applyHeartMaskToBlueView(fillRatio: leftFillRatio, animated: true)
                    self.applyHeartMaskToPinkView(fillRatio: rightFillRatio, animated: true)
                    
                    // ✅ 如果分数为0，在动画完成后更新空状态
                    if shouldUpdateEmptyState {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                            guard let self = self else { return }
                            self.emptyStateManager?.updateEmptyStatesWithCurrentData()
                        }
                    }
                }
            } else {
                self.applyHeartMaskToBlueView(fillRatio: leftFillRatio, animated: true)
                self.applyHeartMaskToPinkView(fillRatio: rightFillRatio, animated: true)
                
                // ✅ 如果分数为0，在动画完成后更新空状态
                if shouldUpdateEmptyState {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        guard let self = self else { return }
                        self.emptyStateManager?.updateEmptyStatesWithCurrentData()
                    }
                }
            }
        }
    }
    
    func setUI() {
        view.backgroundColor = .white
        
        let backView = ViewGradientView()
        view.addSubview(backView)
        backView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        
        let pointslabelImage = UIImageView(image: .pointsLabel)
        view.addSubview(pointslabelImage)
        pointslabelImage.snp.makeConstraints { make in
            make.left.equalTo(17)
            make.topMargin.equalTo(21)
        }
        
        let wishBtnShadowContainer = UIView()
        wishBtnShadowContainer.isUserInteractionEnabled = true
        backView.addSubview(wishBtnShadowContainer)
        wishBtnShadowContainer.snp.makeConstraints { make in
            make.right.equalTo(-24)
            make.width.equalToSuperview().multipliedBy(78.0 / 375.0)
            make.height.equalTo(34)
            make.centerY.equalTo(pointslabelImage)
        }
        wishBtnShadowContainer.layer.shadowColor = UIColor.black.withAlphaComponent(0.05).cgColor
        wishBtnShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 1)
        wishBtnShadowContainer.layer.shadowRadius = 2.0
        wishBtnShadowContainer.layer.shadowOpacity = 1.0
        wishBtnShadowContainer.layer.shadowColor = UIColor.black.withAlphaComponent(0.03).cgColor
        wishBtnShadowContainer.layer.shadowRadius = 4.0
        
        addwishButon = UIButton()
        addwishButon.layer.cornerRadius = 17
        addwishButon.layer.borderWidth = 3
        addwishButon.clipsToBounds = true
        addwishButon.layer.borderColor = UIColor.color(hexString: "#FFFFFF").cgColor
        addwishButon.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
            guard let self = self else { return }
            // ✅ 模拟器直接进入，真机才检测链接
            #if targetEnvironment(simulator)
            let skipLinkCheck = true
            #else
            let skipLinkCheck = false
            #endif
            guard skipLinkCheck || CoupleStatusManager.shared.isUserLinked else {
                // ✅ 清除本地状态（如果之前有链接状态残留）
                CoupleStatusManager.shared.resetAllStatus()
                
                // ✅ 显示 unlinkpopimage 弹窗，然后从弹窗跳转到 CheekBootPageView
                // ✅ 保存为实例变量，避免被释放导致按钮失效
                self.unlinkPopup = UnlinkConfirmPopup(
                    title: "No partner added",
                    message: "Connect with a partner to create and assign \ntasks.",
                    imageName: "unlinkpopimage",
                    cancelTitle: "Cancel",
                    confirmTitle: "Link Companion",
                    confirmBlock: { [weak self] in
                        guard let self = self else { return }
                        // ✅ 清除引用，允许弹窗被释放
                        self.unlinkPopup = nil
                        // ✅ 点击 Link Companion 后，直接 present 到 CheekBootPageView
                        let cheekVc = CheekBootPageView()
                        cheekVc.modalPresentationStyle = .fullScreen
                        cheekVc.isPresentedFromUnlink = true
                        let nav = UINavigationController(rootViewController: cheekVc)
                        nav.modalPresentationStyle = .fullScreen
                        nav.setNavigationBarHidden(true, animated: false)
                        self.present(nav, animated: true)
                    },
                    cancelBlock: { [weak self] in
                        // ✅ 点击 Cancel，直接关闭弹窗，不做任何操作
                        print("✅ PointsView: 用户取消链接")
                        // ✅ 清除引用，允许弹窗被释放
                        self?.unlinkPopup = nil
                    }
                )
                self.unlinkPopup?.show()
                return
            }
            // ✅ 已链接，正常显示 wishViewPopup
            wishViewPopup.show(width: view.width(), bottomSpacing: self.bottomSpacing())
        }
        wishBtnShadowContainer.addSubview(addwishButon)
        addwishButon.snp.makeConstraints { make in make.edges.equalToSuperview() }
        
        let addView = AddButtonGradientView()
        addView.layer.cornerRadius = 17
        addView.isUserInteractionEnabled = false
        addwishButon.addSubview(addView)
        addView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        
        let loveLabel = UILabel()
        loveLabel.text = "Add Wish"
        loveLabel.font = UIFont(name: "SFCompactRounded-Heavy", size: 14)
        loveLabel.textColor = .color(hexString: "#FFFFFF")
        addView.addSubview(loveLabel)
        loveLabel.snp.makeConstraints { make in make.center.equalToSuperview() }
        
        // 整体滚动：从 userPointsView 到 wishlist 底部由同一个 scrollView 负责
        mainScrollView = UIScrollView()
        mainScrollView.showsVerticalScrollIndicator = false
        mainScrollView.showsHorizontalScrollIndicator = false
        mainScrollView.bounces = true
        view.addSubview(mainScrollView)
        mainScrollView.snp.makeConstraints { make in
            make.top.equalTo(pointslabelImage.snp.bottom).offset(34)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(-100)
        }
        
        scrollContentView = UIView()
        scrollContentView.backgroundColor = .clear
        mainScrollView.addSubview(scrollContentView)
        if #available(iOS 11.0, *) {
            // 用 contentLayoutGuide 才能让 ScrollView 正确算出 contentSize，否则会划不动
            scrollContentView.snp.makeConstraints { make in
                make.top.leading.trailing.equalTo(mainScrollView.contentLayoutGuide)
                make.bottom.equalTo(mainScrollView.contentLayoutGuide)
                make.width.equalTo(mainScrollView.frameLayoutGuide)
            }
        } else {
            scrollContentView.snp.makeConstraints { make in
                make.top.left.right.equalToSuperview()
                make.width.equalTo(mainScrollView)
            }
        }
        
        userPointsView = UIView()
        userPointsView.isHidden = true
        scrollContentView.addSubview(userPointsView)
        userPointsView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(view).multipliedBy(255.0 / 375.0)
            make.height.equalTo(view).multipliedBy(116.0 / 812.0)
            make.top.equalTo(scrollContentView)
        }
        
        // ✅ 占位用中性图，loadUserAvatars 会按当前用户性别设置默认头像
        user1ImageView = UIImageView(image: UIImage(named: "userText"))
        user1ImageView.contentMode = .scaleAspectFill
        user1ImageView.clipsToBounds = true
        user1ImageView.layer.cornerRadius = 30
        userPointsView.addSubview(user1ImageView)
        
        let  xxx5 = view.height() * 5.0 / 812.0
        user1ImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(xxx5)
            make.height.equalToSuperview().multipliedBy(89.0 / 122.0)
            make.width.equalTo(69)
        }
        
        // ✅ 创建左侧分数容器 view（包含图片和数字）
        let user1PointsContainer = UIView()
        user1PointsContainer.backgroundColor = .clear // ✅ 确保背景透明，不影响白色描边显示
        userPointsView.addSubview(user1PointsContainer)
        user1PointsContainer.snp.makeConstraints { make in
            make.centerX.equalTo(user1ImageView.snp.centerX)
            make.top.equalTo(user1ImageView.snp.bottom).offset(16)
        }
        
        let userImage1Coin = UIImageView(image: .coin)
        user1PointsContainer.addSubview(userImage1Coin)
        userImage1Coin.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        // ✅ 设置 user1 分数标签（图片在左，文本在右，整体居中于头像）
        let user1Labels = setupPointsLabels(
            container: user1PointsContainer,
            coinImage: userImage1Coin,
            isLeftSide: true
        )
        
        underunderuser1PointsLabel = user1Labels.underUnderLabel
        underuser1PointsLabel = user1Labels.underLabel
        user1PointsLabel = user1Labels.gradientLabel
        
        // ✅ 占位用中性图，loadUserAvatars 会按伴侣性别设置默认头像
        user2ImageView = UIImageView(image: UIImage(named: "userText"))
        user2ImageView.contentMode = .scaleAspectFill
        user2ImageView.clipsToBounds = true
        user2ImageView.layer.cornerRadius = 30
        userPointsView.addSubview(user2ImageView)
        
        user2ImageView.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.top.equalTo(xxx5)
            make.height.equalToSuperview().multipliedBy(89.0 / 122.0)
            make.width.equalTo(69)
        }
        
        
        user1heardView = UIImageView(image: .backheard)
        user1heardView.transform = CGAffineTransform(rotationAngle: -6 * .pi / 180)
        userPointsView.addSubview(user1heardView)
        
        user1heardView.snp.makeConstraints { make in
            make.left.equalTo(user1ImageView.snp.right).offset(2)
            make.top.equalToSuperview()
        }
        
        user1underheardView = UIImageView(image: .upheard)
        user1underheardView.clipsToBounds = true
        user1heardView.addSubview(user1underheardView)
        
        user1underheardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            
        }
        
        // ✅ 在父视图上设置固定的爱心遮罩
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupHeartMaskForContainer(self.user1underheardView)
        }
        
        upblueView = UIImageView(image: .blueheard)
        user1underheardView.addSubview(upblueView)
        
        // ✅ 修改约束：让矩形视图可以上下移动，初始位置在底部（完全隐藏）
        upblueView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview()
            upblueViewBottomConstraint = make.bottom.equalToSuperview().offset(0).constraint
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.applyHeartMaskToBlueView(fillRatio: 0)
        }
        
        
        user2heardView = UIImageView(image: .backheard)
        user2heardView.transform = CGAffineTransform(rotationAngle: 6 * .pi / 180)
        userPointsView.addSubview(user2heardView)
        
        user2heardView.snp.makeConstraints { make in
            make.right.equalTo(user2ImageView.snp.left).offset(2)
            make.top.equalToSuperview()
        }
        
        user2underheardView = UIImageView(image: .upheard)
        user2underheardView.clipsToBounds = true
        user2heardView.addSubview(user2underheardView)
        
        user2underheardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
           
        }
        
        // ✅ 在父视图上设置固定的爱心遮罩
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupHeartMaskForContainer(self.user2underheardView)
        }
        
        upinkView = UIImageView(image: .pinkheard)
        user2underheardView.addSubview(upinkView)
        
        // ✅ 修改约束：让矩形视图可以上下移动，初始位置在底部（完全隐藏）
        upinkView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview()
            upinkViewBottomConstraint = make.bottom.equalToSuperview().offset(0).constraint
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.applyHeartMaskToPinkView(fillRatio: 0)
        }
        
        // ✅ 创建右侧分数容器 view（包含图片和数字）
        let user2PointsContainer = UIView()
        user2PointsContainer.backgroundColor = .clear // ✅ 确保背景透明，不影响白色描边显示
        user2PointsContainer.clipsToBounds = false // ✅ 确保不裁剪描边
        userPointsView.addSubview(user2PointsContainer)
        user2PointsContainer.snp.makeConstraints { make in
            make.centerX.equalTo(user2ImageView.snp.centerX) // ✅ 精确对齐头像中心
            make.top.equalTo(user2ImageView.snp.bottom).offset(16)
        }
        
        let userImage2Coin = UIImageView(image: .coin)
        user2PointsContainer.addSubview(userImage2Coin)
        userImage2Coin.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        // ✅ 设置 user2 分数标签（图片在左，文本在右，整体居中于头像）
        let user2Labels = setupPointsLabels(
            container: user2PointsContainer,
            coinImage: userImage2Coin,
            isLeftSide: false
        )
        underunderuser2PointsLabel = user2Labels.underUnderLabel
        underuser2PointsLabel = user2Labels.underLabel
        user2PointsLabel = user2Labels.gradientLabel
        
        breakButton = BorderGradientButton()
        breakButton.addTarget(self, action: #selector(breakButtonTapped), for: .touchUpInside)
        breakButton.layer.cornerRadius = 18
        breakButton.isHidden = true
        scrollContentView.addSubview(breakButton)
        breakButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(view).multipliedBy(335.0 / 375.0)
            breakButtonHeightConstraint = make.height.equalTo(158).constraint
            make.top.equalTo(userPointsView.snp.bottom).offset(16)
        }
        
        let breakdownLabel = UILabel()
        breakdownLabel.text = "Breakdown"
        breakdownLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
        breakdownLabel.textColor = .color(hexString: "#322D3A")
        breakButton.addSubview(breakdownLabel)
        breakdownLabel.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.top.equalTo(12)
        }
        
        let breakButtonDown = UIImageView(image: .settingArrow)
        breakButton.addSubview(breakButtonDown)
        
        breakButtonDown.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.centerY.equalTo(breakdownLabel)
        }
        
        record1View = PointsViewRecordHelper.createScoreRecordView()
        record1View.isHidden = true
        breakButton.addSubview(record1View)
        record1View.snp.makeConstraints { make in
            make.top.equalTo(breakdownLabel.snp.bottom).offset(8)
            make.left.equalTo(12)
            make.right.equalTo(-12)
            make.height.equalTo(44)
        }
        
        breakdownLineView = UIView()
        breakdownLineView.backgroundColor = .color(hexString: "#484848").withAlphaComponent(0.05)
        breakButton.addSubview(breakdownLineView)
        
        breakdownLineView.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(305.0 / 375.0)
            make.top.equalTo(record1View.snp.bottom).offset(8)
        }
        
        record2View = PointsViewRecordHelper.createScoreRecordView()
        record2View.isHidden = true
        breakButton.addSubview(record2View)
        record2View.snp.makeConstraints { make in
            make.top.equalTo(breakdownLineView.snp.bottom).offset(8)
            make.left.equalTo(12)
            make.right.equalTo(-12)
            make.height.equalTo(44)
        }
        
        wishLabel = UILabel()
        wishLabel.isHidden = true
        wishLabel.text = "Wish List"
        wishLabel.textColor = .color(hexString: "#322D3A")
        wishLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
        scrollContentView.addSubview(wishLabel)
        wishLabel.snp.makeConstraints { make in
            make.left.equalTo(32)
            make.top.equalTo(breakButton.snp.bottom).offset(16)
        }
        
        self.addChild(wishtableView)
        scrollContentView.addSubview(wishtableView.view)
        wishtableView.view.snp.makeConstraints { make in
            make.top.equalTo(wishLabel.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
            wishlistHeightConstraint = make.height.equalTo(300).constraint
        }
        // 用 wishlist 底部撑开 contentView，从而撑开 contentLayoutGuide，ScrollView 才有可滚动高度
        scrollContentView.snp.makeConstraints { make in
            make.bottom.equalTo(wishtableView.view.snp.bottom)
        }
        wishtableView.didMove(toParent: self)
        pointsViewPopup.homeViewController1 = self
        
        recordsEmptyImageView = UIImageView(image: .noPoints)
        recordsEmptyImageView.contentMode = .scaleAspectFit
        recordsEmptyImageView.isHidden = true
        recordsEmptyImageView.isUserInteractionEnabled = false
        view.addSubview(recordsEmptyImageView)
        recordsEmptyImageView.snp.makeConstraints { make in
            make.top.equalTo(pointslabelImage.snp.bottom).offset(70)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(173.0 / 375.0)
            make.height.equalToSuperview().multipliedBy(191.0 / 812.0)
        }
        
        wishListEmptyImageView = UIImageView(image: .noWish)
        wishListEmptyImageView.contentMode = .scaleAspectFit
        wishListEmptyImageView.isHidden = true
        wishListEmptyImageView.isUserInteractionEnabled = false
        view.addSubview(wishListEmptyImageView)
        wishListEmptyImageView.snp.makeConstraints { make in
            make.top.equalTo(wishLabel.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(271.0 / 375.0)
            make.height.equalTo(171)
        }
        
        allEmptyImageView = UIImageView(image: .noWish)
        allEmptyImageView.contentMode = .scaleAspectFit
        allEmptyImageView.isHidden = true
        allEmptyImageView.isUserInteractionEnabled = false
        view.addSubview(allEmptyImageView)
        allEmptyImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(271.0 / 375.0)
            make.height.equalTo(171)
        }
    }
    
    private func loadAndBindCoupleScore() {
        // ✅ 优化：检查视图是否仍然活跃
        guard isViewActive, isViewLoaded, user1PointsLabel != nil, user2PointsLabel != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.loadAndBindCoupleScore()
            }
            return
        }
        
        let currentUserId = CoupleStatusManager.getUserUniqueUUID()
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUserId = partnerUser?.id ?? ""
        
        // ✅ 优化：在后台线程执行Firebase查询，避免阻塞主线程
        ScoreManager.shared.getCoupleScores { [weak self] myScore, partnerScore in
            guard let self = self,
                  self.isViewActive,
                  self.isViewLoaded,
                  !self.isBeingDismissed,
                  self.view.window != nil,
                  self.user1PointsLabel != nil,
                  self.user2PointsLabel != nil else {
                return
            }
            
            // ✅ 确保UI更新在主线程执行
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      self.isViewActive,
                      self.isViewLoaded,
                      !self.isBeingDismissed,
                      self.view.window != nil else {
                    return
                }
                
                let leftScore = myScore
                let rightScore = partnerScore
                
                let leftScoreText = String(format: "%03d", leftScore)
                self.user1PointsLabel.text = leftScoreText
                self.underuser1PointsLabel.text = leftScoreText
                self.underunderuser1PointsLabel.text = leftScoreText
                
                let rightScoreText = String(format: "%03d", rightScore)
                self.user2PointsLabel.text = rightScoreText
                self.underuser2PointsLabel.text = rightScoreText
                self.underunderuser2PointsLabel.text = rightScoreText
                
                self.user1PointsLabel.setNeedsDisplay()
                self.user2PointsLabel.setNeedsDisplay()
                
                self.updateHeartColorsByGender()
                self.loadUserAvatars()
                self.updateHeartFills(myScore: leftScore, partnerScore: rightScore, isEntryAnimation: false)
            }
        }
    }
    
    private func loadUserAvatars() {
        guard isViewLoaded, user1ImageView != nil, user2ImageView != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.loadUserAvatars()
            }
            return
        }
        
        PointsViewAvatarManager.shared.loadUserAvatars(
            user1ImageView: user1ImageView,
            user2ImageView: user2ImageView,
            isViewLoaded: isViewLoaded,
            viewWindow: view.window,
            applyAICutout: true
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ✅ 每次进入愿望列表时从服务器拉取一次，补全对方添加的 wish（解决实时监听在后台/网络下未触发导致对方看不到的问题）
        PointsManger.manager.refreshWishListFromServer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // ✅ 进入页面时滚动回顶部
        mainScrollView?.contentOffset = .zero
        
        // ✅ 标记视图为活跃状态
        isViewActive = true
        
        // ✅ 确保 allEmptyImageView 在最顶层，不被其他视图遮挡
        if let allEmptyImageView = allEmptyImageView {
            view.bringSubviewToFront(allEmptyImageView)
        }
        
        if isFirstLoad {
            breakButton?.isHidden = true
            userPointsView?.isHidden = true
            // ✅ 首次加载时，先显示 allEmptyImageView，避免白色闪烁
            // 等数据加载完成后再根据实际情况决定是否隐藏
            allEmptyImageView?.isHidden = false
            recordsEmptyImageView?.isHidden = true
            wishListEmptyImageView?.isHidden = true
            wishLabel?.isHidden = true
            if wishtableView.isViewLoaded {
                wishtableView.view.isHidden = true
            }
        }
        
        // ✅ 优化：立即重置爱心填充（轻量操作）
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isViewActive else { return }
            self.applyHeartMaskToBlueView(fillRatio: 0, animated: false)
            self.applyHeartMaskToPinkView(fillRatio: 0, animated: false)
        }
        
        // ✅ 优化：延迟加载耗时操作，避免阻塞页面切换
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  self.isViewActive,
                  self.isViewLoaded,
                  self.view.window != nil else {
                return
            }
            self.updateHeartColorsByGender()
            self.loadAndBindCoupleScore()
            self.loadUserAvatars()
            // ✅ 修复：确保表格视图刷新，显示最新数据
            if self.wishtableView.isViewLoaded {
                self.wishtableView.tableView.reloadData()
                self.emptyStateManager?.updateEmptyStatesWithCurrentData()
            }
        }
        
        if isFirstLoad {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.isViewActive else { return }
                self.loadRecentScoreRecords()
                self.isFirstLoad = false
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self,
                      self.isViewActive,
                      self.isViewLoaded,
                      self.view.window != nil else {
                    return
                }
                self.loadRecentScoreRecords()
            }
        }
        
        // ✅ 每次进入页面时展示一次气泡动画
        hasShownBubbles = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // ✅ 标记视图为非活跃状态，取消未完成的操作
        isViewActive = false
        
        // ✅ 取消所有待执行的操作
        pendingOperations.forEach { $0.cancel() }
        pendingOperations.removeAll()
        loadRecentScoreRecordsWorkItem?.cancel()
        loadRecentScoreRecordsWorkItem = nil
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // ✅ 清理所有气泡和动画，避免内存泄漏
        cleanupBubblesAndWaves()
    }
    
    // ✅ 清理所有气泡和波浪动画
    private func cleanupBubblesAndWaves() {
        blueLiquidManager.cleanup()
        pinkLiquidManager.cleanup()
        hasShownBubbles = false
    }
    
    @objc func breakButtonTapped() {
        let vc = BreakdownViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func refreshScoreWhenChanged() {
        // ✅ 优化：检查视图是否仍然活跃，避免在页面切换时执行操作
        guard isViewActive, isViewLoaded, view.window != nil, !isBeingDismissed else {
            return
        }
        
        loadAndBindCoupleScore()
        // ✅ 防抖：对方设备上「自己+伴侣」两路分数监听会各发一次通知，短时间多次刷新导致 breakdown cell 上下跳动
        loadRecentScoreRecordsWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.loadRecentScoreRecords()
        }
        loadRecentScoreRecordsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + loadRecentScoreRecordsDebounceInterval, execute: workItem)
    }
    
    @objc private func handleCoupleDidUnlink() {
        guard isViewLoaded else { return }
        
        print("🔔 PointsView: 收到断开链接通知，开始更新UI")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. 隐藏用户信息视图
            self.userPointsView?.isHidden = true
            self.breakButton?.isHidden = true
            self.wishLabel?.isHidden = true
            
            // 2. 清空分数显示
            self.user1PointsLabel?.text = "000"
            self.underuser1PointsLabel?.text = "000"
            self.underunderuser1PointsLabel?.text = "000"
            self.user2PointsLabel?.text = "000"
            self.underuser2PointsLabel?.text = "000"
            self.underunderuser2PointsLabel?.text = "000"
            
            // 3. 重置心形填充
            self.applyHeartMaskToBlueView(fillRatio: 0, animated: false)
            self.applyHeartMaskToPinkView(fillRatio: 0, animated: false)
            
            // 4. 隐藏记录视图
            self.record1View?.isHidden = true
            self.record2View?.isHidden = true
            
            // 5. 刷新愿望列表（清空数据）
            if self.wishtableView.isViewLoaded {
                do {
                    try self.wishtableView.fetchedResultsController.performFetch()
                    self.wishtableView.tableView.reloadData()
                } catch {
                    print("⚠️ PointsView: 刷新表格失败: \(error)")
                }
            }
            
            // 6. 更新空状态
            self.emptyStateManager?.updateEmptyStates(hasRecordData: false, hasWishData: false)
            
            print("✅ PointsView: 断开链接UI更新完成")
        }
    }
    
    private func refreshEntirePage() {
        guard isViewLoaded else { return }
        
        loadAndBindCoupleScore()
        loadUserAvatars()
        loadRecentScoreRecords()
        
        // ✅ 修复：确保在主线程且视图已加载时刷新表格
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.wishtableView.isViewLoaded,
                  self.wishtableView.view.window != nil else {
                return
            }
            
            do {
                // ✅ 检查 fetchedResultsController 是否有效
                guard self.wishtableView.fetchedResultsController != nil else {
                    print("⚠️ PointsView: fetchedResultsController 为 nil，跳过刷新")
                    return
                }
                
                try self.wishtableView.fetchedResultsController.performFetch()
                self.wishtableView.tableView.reloadData()
                self.emptyStateManager?.updateEmptyStatesWithCurrentData()
            } catch {
                print("⚠️ PointsView: 刷新表格失败: \(error.localizedDescription)")
            }
        }
    }
    
    func addPointsItem(
        title: String,
        notes: String,
        imageURLs: [String],
        points: Int,
        isShared: Bool,
        wishImage: String
    ) {
        print("🔍 [PointsView] addPointsItem 开始 - Title: \(title), Points: \(points)")
        
        // ✅ 只保存到 Core Data，Firebase 同步由 PointsManger.handleContextDidSave 自动处理
        guard let localModel = PointsManger.manager.addModel(
            titleLabel: title,
            notesLabel: notes,
            imageURLs: imageURLs,
            points: points,
            isShared: isShared,
            wishImage: wishImage
        ) else {
            print("❌ [PointsView] Failed to save item to Core Data.")
            return
        }
        
        print("✅ [PointsView] Item saved - ID: \(localModel.id ?? "unknown")")
        
        // ✅ 移除手动刷新 UI 的代码，避免重复刷新
        // ✅ PointsManger.handleContextDidSave 会自动监听 CoreData 变化并同步到 Firebase
        // ✅ PointsTableViewController 已经通过 NSFetchedResultsController 自动监听 CoreData 变化，会自动更新 UI
        // ✅ 分数和记录的刷新会通过 NotificationCenter 通知自动处理（wishDataDidUpdate 方法）
    }
    
    private func loadRecentScoreRecords() {
        // ✅ 优化：检查视图是否仍然活跃
        guard isViewActive, isViewLoaded else { return }
        
        PointsViewRecordManager.shared.loadRecentScoreRecords(isViewLoaded: isViewLoaded) { [weak self] recentRecords, filteredRecords, allRecords in
            guard let self = self,
                  self.isViewActive,
                  self.isViewLoaded,
                  !self.isBeingDismissed,
                  self.view.window != nil else {
                return
            }
            // ✅ 传递未过滤的原始记录，用于判断是否是双方任务
            self.updateRecordsDisplay(records: recentRecords, allRecords: allRecords)
        }
    }
    
    /// 仅一条记录时 breakdown 区域高度（label + 单条 record + 内边距）；两条时为 158
    private static let breakdownHeightOneCell: CGFloat = 96
    private static let breakdownHeightTwoCells: CGFloat = 158
    
    private func updateRecordsDisplay(records: [ScoreRecordModel], allRecords: [ScoreRecordModel]) {
        guard isViewLoaded, record1View != nil, record2View != nil else { return }
        
        // ✅ 稳定排序：Firebase/缓存返回顺序可能每次不同，导致两条 cell 上下互换。这里固定按 createTime 倒序 + recordId 倒序，保证展示顺序一致。
        let sortedRecent: [ScoreRecordModel] = {
            let two = Array(records.prefix(2))
            guard two.count > 1 else { return two }
            return two.sorted { r1, r2 in
                if r1.createTime != r2.createTime { return r1.createTime > r2.createTime }
                return r1.recordId > r2.recordId
            }
        }()
        
        let count = sortedRecent.count
        let id1 = count > 0 ? sortedRecent[count > 1 ? 1 : 0].recordId : nil
        let id2 = count > 1 ? sortedRecent[0].recordId : nil
        
        // ✅ 去重：数据未变化时不重复更新
        if count == lastBreakdownRecordCount && id1 == lastBreakdownRecord1Id && id2 == lastBreakdownRecord2Id {
            return
        }
        lastBreakdownRecordCount = count
        lastBreakdownRecord1Id = id1
        lastBreakdownRecord2Id = id2
        
        // ✅ record1(上)=次新，record2(下)=最新
        let hasRecordData = count > 0
        if count > 0 {
            PointsViewRecordHelper.updateRecordView(record1View, with: sortedRecent[count > 1 ? 1 : 0], allRecords: allRecords)
            record1View.isHidden = false
        } else {
            record1View.isHidden = true
        }
        
        if count > 1 {
            PointsViewRecordHelper.updateRecordView(record2View, with: sortedRecent[0], allRecords: allRecords)
            record2View.isHidden = false
            breakdownLineView?.isHidden = false
            breakButtonHeightConstraint?.update(offset: Self.breakdownHeightTwoCells)
        } else {
            record2View.isHidden = true
            breakdownLineView?.isHidden = true
            breakButtonHeightConstraint?.update(offset: Self.breakdownHeightOneCell)
        }
        
        let hasWishData = wishtableView.isViewLoaded &&
        (wishtableView.fetchedResultsController?.fetchedObjects?.count ?? 0) > 0
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isFirstLoad {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.emptyStateManager?.updateEmptyStates(hasRecordData: hasRecordData, hasWishData: hasWishData)
                CATransaction.commit()
            } else {
                self.emptyStateManager?.updateEmptyStates(hasRecordData: hasRecordData, hasWishData: hasWishData)
            }
        }
    }
}


