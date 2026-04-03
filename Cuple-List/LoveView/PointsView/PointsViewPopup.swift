//
//  PointsViewPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class PointsViewPopup: NSObject {
    weak var homeViewController1: PointsView?
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    // 按钮网格容器 (垂直 StackView)
    var gridStackView: UIStackView!
    var continueButton: UIButton!
    var onWishPointselected: ((String) -> Void)?
    private weak var selectedButton: UIButton?
    private var selectedPoints: String?
    
    let buttonData: [(title: String, image: UIImage?, text: String)] = [
        ("10", UIImage(named: "coin"), "10 points description text."),
        ("20", UIImage(named: "coin"), "20 points description text."),
        ("30", UIImage(named: "coin"), "30 points description text."),
        ("50", UIImage(named: "coin"), "50 points description text."),
        ("70", UIImage(named: "coin"), "70 points description text."),
        ("100", UIImage(named: "coin"), "100 points description text.")
    ]
    
    let startColor = UIColor.color(hexString: "#FFC251")
    let endColor = UIColor.color(hexString: "#FF7738")
    
    override init() {
        super.init()
        setupUI()
    }
    
    private func setupUI() {
        backView = UIView()
        backView.layer.cornerRadius = 24
        backView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backView.clipsToBounds = true
        backView.backgroundColor = .white
        
        hintView = UIView()
        hintView.backgroundColor = .clear
        backView.addSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalTo(20)
            make.width.equalTo(300)
            make.centerX.equalToSuperview()
        }
        
        topLine = UIView()
        topLine.layer.cornerRadius = 2.5
        topLine.backgroundColor = .color(hexString: "#DED9ED")
        backView.addSubview(topLine)
        topLine.snp.makeConstraints { make in
            make.top.equalTo(6)
            make.centerX.equalToSuperview()
            make.width.equalTo(35)
            make.height.equalTo(5)
        }
        
        closeButton = UIButton()
        closeButton.setImage(UIImage(named: "listback"), for: .normal)
        closeButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.popup.dismiss(animated: true)
        }
        backView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(20)
            make.width.height.equalTo(28)
        }
        
        titleLabel = UILabel()
        titleLabel.text = "Points"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        // StackView 约束 (与之前保持一致)
        gridStackView = UIStackView()
        gridStackView.axis = .vertical
        gridStackView.spacing = 13.0
        gridStackView.distribution = .fillEqually
        
        backView.addSubview(gridStackView)
        
        gridStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(25)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        createPointsButtons()
        
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.layer.borderWidth = 1
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            if let selectedPoints = self.selectedPoints {
                self.onWishPointselected?(selectedPoints) // 传递选中的分数
                print("通过 Continue 按钮确认分数：\(selectedPoints)")
                self.popup.dismiss(animated: true) // 确认后关闭弹窗
            } else {
                print("未选择分数")
            }
        }
        backView.addSubview(continueButton)
        
        continueButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottomMargin.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(56)
        }
        
        popup = WavesPopup(contentView: backView,
                           showType: .slideInFromBottom,
                           dismissType: .slideOutToBottom,
                           maskType: .dimmed,
                           dismissOnBackgroundTouch: true,
                           dismissOnContentTouch: false,
                           dismissPanView: hintView)
    }
    
    /// 展示弹窗，可传入当前已选分数使弹窗内默认选中
    func show(width: CGFloat, bottomSpacing: CGFloat, initialPoints: String? = nil) {
        self.layout(width: width, bottomSpacing: bottomSpacing)
        if let points = initialPoints, !points.isEmpty {
            selectButton(byTitle: points)
        }
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    /// 根据分数标题选中对应按钮（用于编辑时回显）
    private func selectButton(byTitle title: String) {
        for view in gridStackView.arrangedSubviews {
            guard let rowStack = view as? UIStackView else { continue }
            for subview in rowStack.arrangedSubviews {
                guard let button = subview as? UIButton else { continue }
                let index = button.tag
                guard index < buttonData.count, buttonData[index].title == title else { continue }
                handleSelection(for: button)
                selectedPoints = title
                return
            }
        }
    }
    
//    private func selectDefaultButton() {
//        // 遍历所有按钮，找到标题为"20"的按钮
//        // ✅ 使用安全的可选绑定，避免强制解包导致崩溃
//        for view in gridStackView.arrangedSubviews {
//            guard let rowStack = view as? UIStackView else { continue }
//            for subview in rowStack.arrangedSubviews {
//                guard let button = subview as? UIButton else { continue }
//                let index = button.tag
//                guard index < buttonData.count else { continue }
//                if buttonData[index].title == "20" {
//                    handleSelection(for: button)
//                    selectedPoints = "20"
//                    return
//                }
//            }
//        }
//        // fallback：如果未找到（异常情况），选中第一个按钮
//        if let firstRow = gridStackView.arrangedSubviews.first as? UIStackView,
//           let firstButton = firstRow.arrangedSubviews.first as? UIButton {
//            handleSelection(for: firstButton)
//            selectedPoints = buttonData[firstButton.tag].title
//        }
//    }
    
    // 保持 layout 方法不变
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: gridStackView.maxY() + 96 + bottomSpacing)
    }
    
    
    private func handlePointButtonTapped(_ tag: Int, button: UIButton) {
        guard tag < buttonData.count else { return }
        
        handleSelection(for: button)
        self.selectedPoints = buttonData[tag].title // 更新选中分数
        let data = buttonData[tag]
        print("选中分数（未确认）：\(data.title)")
    }
    
    // ⭐️ 核心逻辑：处理按钮选中状态的切换
    private func handleSelection(for newButton: UIButton) {
        // 1. 重置旧按钮的样式和图片
        if let oldButton = selectedButton, oldButton != newButton {
            oldButton.layer.borderColor = UIColor.clear.cgColor
            // 找到旧按钮的图片视图并隐藏
            if let imageView = oldButton.viewWithTag(999) as? UIImageView {
                imageView.isHidden = true
            }
        }
        
        newButton.layer.borderColor = UIColor.color(hexString: "#FF7738").cgColor
        // 找到新按钮的图片视图并显示
        if let imageView = newButton.viewWithTag(999) as? UIImageView {
            imageView.isHidden = false
        }
        
        // 3. 更新选中的按钮引用
        selectedButton = newButton
    }
    
    private func createPointsButtons() {
        let columnCount = 3
        let rowCount = 2
        let horizontalSpacing: CGFloat = 17.0
        let buttonHeight: CGFloat = 48.0
        let imageTextSpacing: CGFloat = 0 // 图片与文字的间距
        
        for row in 0..<rowCount {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.spacing = horizontalSpacing
            rowStackView.distribution = .fillEqually
            rowStackView.alignment = .fill
            
            gridStackView.addArrangedSubview(rowStackView)
            
            for col in 0..<columnCount {
                let index = row * columnCount + col
                guard index < buttonData.count else { break }
                let data = buttonData[index]
                
                let button = BorderGradientPointsButton()
                button.tag = index
                button.layer.cornerRadius = 14
                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.clear.cgColor
                button.snp.makeConstraints { make in
                    make.height.equalTo(buttonHeight)
                }
                
                
                // ⭐️ 关键：用水平StackView包裹图片和文字，便于整体居中
                let contentStackView = UIStackView()
                contentStackView.axis = .horizontal
                contentStackView.spacing = imageTextSpacing
                contentStackView.alignment = .center // 垂直居中
                contentStackView.distribution = .fill // 按内容填充
                contentStackView.isBaselineRelativeArrangement = false
                contentStackView.isUserInteractionEnabled = false
                button.addSubview(contentStackView)
                // 让StackView在按钮中完全居中
                contentStackView.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.centerY.equalToSuperview()
                }
                
                let coinImageView = UIImageView(image: data.image)
                //                coinImageView.isUserInteractionEnabled = true
                coinImageView.tag = 999 // 用固定tag便于后续查找
                coinImageView.contentMode = .scaleAspectFit
                coinImageView.tintColor = startColor
                coinImageView.isHidden = true // 默认隐藏
                //                coinImageView.snp.makeConstraints { make in
                //                    make.size.equalTo(imageSize)
                //                }
                contentStackView.addArrangedSubview(coinImageView)
                
                let underpointsShadowLabel = StrokeShadowLabel()
                underpointsShadowLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
                underpointsShadowLabel.shadowOffset = CGSize(width: 0, height: 1)
                underpointsShadowLabel.shadowBlurRadius = 2.0
                underpointsShadowLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
                underpointsShadowLabel.text = data.title
                contentStackView.addArrangedSubview(underpointsShadowLabel)
                
                let pointsShadowLabel = StrokeShadowLabel()
                pointsShadowLabel.shadowColor = UIColor.black.withAlphaComponent(0.03)
                pointsShadowLabel.shadowOffset = CGSize(width: 0, height: 1)
                pointsShadowLabel.shadowBlurRadius = 4.0
                pointsShadowLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
                pointsShadowLabel.text = data.title
                contentStackView.addSubview(pointsShadowLabel)
                
                pointsShadowLabel.snp.makeConstraints { make in
                    make.centerX.equalTo(underpointsShadowLabel)
                    make.centerY.equalToSuperview()
                }
                
                // ⭐️ 2. 添加文字标签（添加到StackView）
                let pointsLabel = GradientMaskLabel()
                //                pointsLabel.isUserInteractionEnabled = true
                pointsLabel.clipsToBounds = true
                pointsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
                pointsLabel.gradientStartColor = .color(hexString: "#FFC251")
                pointsLabel.gradientEndColor = .color(hexString: "#FF7738")
                pointsLabel.gradientDirection = (start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))
                pointsLabel.text = data.title
                pointsLabel.layoutMargins = .zero
                contentStackView.addSubview(pointsLabel)
                
                pointsLabel.snp.makeConstraints { make in
                    make.centerX.equalTo(underpointsShadowLabel)
                    make.centerY.equalToSuperview()
                }
                
                
                
                
                
                // 绑定点击事件
                button.reactive.controlEvents(.touchUpInside).observeValues { [weak self] btn in
                    self?.handlePointButtonTapped(btn.tag, button: btn)
                }
                
                rowStackView.addArrangedSubview(button)
            }
        }
    }
}
