//
//  WishViewPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup
import PhotosUI
import AudioToolbox

class WishViewPopup: NSObject, UITextFieldDelegate, UITextViewDelegate,PHPickerViewControllerDelegate, UIGestureRecognizerDelegate{
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    var mainScrollView: UIScrollView!
    var mainContentView: UIView!
    var textFiledView: UIView!
    var titleTextFiled: UITextField!
    var notesTextView: UITextView!
    var selectImageButton: UIButton!
    var photoScrollView: UIScrollView!
    var photoStackView: UIStackView!
    
    var pointsButton: BorderGradientButton!
    var underunderpointsDisplayLabel: StrokeShadowLabel!
    var underpointsDisplayLabel: StrokeShadowLabel!
    var pointsDisplayLabel: GradientMaskLabel!
    var sharedButton: UIButton!
    var checkImageView: UIImageView!
    private var isSharedChecked = false
    var iconView: UIView!
    var continueButton: UIButton!
    
    let selectedImage = UIImage(named: "assignSelect")
    let unselectedImage = UIImage(named: "assignUnselect")
    var pointsView: PointsView!
    
    private var addedImageViews: [UIImageView] = []
    private weak var currentDeleteButton: UIButton?
    
    private var selectedPointValue: Int?
    private var selectedEmoji: String?
    private var emojiButtons: [UIButton] = []
    private var emojiButtonImages: [Int: UIImageView] = [:]
    private let buttonBottomImage = UIImage(named: "iconback")
    
    override init() {
        super.init()
        setupUI()
        setupGlobalTapGesture()
    }
    
    private func setupUI() {
        backView = UIView()
        backView.layer.cornerRadius = 24
        backView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backView.clipsToBounds = true
        backView.backgroundColor = .white
        
        let gradientView = ViewGradientView()
        backView.addSubview(gradientView)
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
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
        titleLabel.text = "Add wish"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        mainScrollView = UIScrollView()
        mainScrollView.isScrollEnabled = true
        mainScrollView.showsHorizontalScrollIndicator = false
        mainScrollView.showsVerticalScrollIndicator = false
        mainScrollView.backgroundColor = .clear
        backView.addSubview(mainScrollView)
        
        mainScrollView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(20)
            make.left.right.equalToSuperview()
        }
        
        mainContentView = UIView()
        mainContentView.backgroundColor = .clear
        mainScrollView.addSubview(mainContentView)
        
        mainContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        textFiledView = BorderGradientView()
        textFiledView.layer.cornerRadius = 18
        mainContentView.addSubview(textFiledView)
        
        textFiledView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(337.0 / 375.0)
            make.height.equalTo(176)
        }
        
        titleTextFiled = UITextField()
        titleTextFiled.attributedPlaceholder = NSAttributedString(string: "Title", attributes: [.foregroundColor : UIColor.color(hexString: "#CACACA")])
        titleTextFiled.layer.cornerRadius = 18
        titleTextFiled.backgroundColor = .clear
        titleTextFiled.keyboardType = .default
        titleTextFiled.returnKeyType = .done
        titleTextFiled.delegate = self
        titleTextFiled.enablesReturnKeyAutomatically = false
        titleTextFiled.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleTextFiled.textColor = .color(hexString: "#322D3A")
        titleTextFiled.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        textFiledView.addSubview(titleTextFiled)
        
        titleTextFiled.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(42)
        }
        
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 15))
        titleTextFiled.leftView = leftPaddingView
        titleTextFiled.leftViewMode = .always
        
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
        notesTextView.backgroundColor = .clear
        notesTextView.text = "Notes"
        notesTextView.textColor = .color(hexString: "#999DAB")
        notesTextView.font =  UIFont(name: "SFCompactRounded-Medium", size: 13)
        notesTextView.returnKeyType = .done
        notesTextView.delegate = self
        notesTextView.isEditable = true
        notesTextView.isUserInteractionEnabled = true
        notesTextView.textContainerInset = .zero
        notesTextView.textContainer.lineFragmentPadding = 0
        textFiledView.addSubview(notesTextView)
        
        notesTextView.snp.makeConstraints { make in
            make.top.equalTo(textFiledLine.snp.bottom).offset(12)
            make.left.equalTo(15)
            make.right.equalToSuperview()
            make.height.equalTo(52)
        }
        
        titleTextFiled.inputAccessoryView = nil
        notesTextView.inputAccessoryView = nil
        
        selectImageButton = UIButton()
        selectImageButton.setImage(UIImage(named: "pica"), for: .normal)
        selectImageButton.backgroundColor = .color(hexString: "#FBFBFB")
        selectImageButton.layer.cornerRadius = 10
        selectImageButton.layer.borderWidth = 0.6
        selectImageButton.layer.borderColor = UIColor.color(hexString: "#E4E4E4").cgColor
        selectImageButton.addTarget(self, action: #selector(selectImageTapped), for: .touchUpInside)
        textFiledView.addSubview(selectImageButton)
        
        selectImageButton.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.width.equalTo(66)
            make.height.equalTo(selectImageButton.snp.width)
            make.bottom.equalTo(-15)
        }
        
        photoScrollView = UIScrollView()
        photoScrollView.showsHorizontalScrollIndicator = false
        textFiledView.addSubview(photoScrollView)
        
        photoScrollView.snp.makeConstraints { make in
            make.left.equalTo(selectImageButton.snp.right).offset(15)
            make.right.equalTo(-15)
            make.centerY.equalTo(selectImageButton)
            make.height.equalTo(selectImageButton.snp.width)
        }
        
        photoStackView = UIStackView()
        photoStackView.axis = .horizontal
        photoStackView.spacing = 15
        photoScrollView.addSubview(photoStackView)
        
        photoStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        
        pointsButton = BorderGradientButton()
        pointsButton.layer.cornerRadius = 18
        pointsButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.backView.endEditing(true)
            let pointsPopup = PointsViewPopup()
            pointsPopup.onWishPointselected = { [weak self] selectedPoints in
                guard let self = self else { return }
                self.selectedPointValue = Int(selectedPoints)
                self.underunderpointsDisplayLabel.text = "\(selectedPoints)"
                self.underpointsDisplayLabel.text = "\(selectedPoints)"
                self.pointsDisplayLabel.text = "\(selectedPoints)"
                self.pointsDisplayLabel.text = "\(selectedPoints)"
                self.pointsDisplayLabel.isHidden = false
                self.underunderpointsDisplayLabel.isHidden = false
                self.underpointsDisplayLabel.isHidden = false
                pointsPopup.popup.dismiss(animated: true)
            }
            pointsPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
        }
        mainContentView.addSubview(pointsButton)
        
        pointsButton.snp.makeConstraints { make in
            make.top.equalTo(textFiledView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
        }
        
        let pointsButtondown = UIImageView(image: .adddown)
        pointsButton.addSubview(pointsButtondown)
        
        pointsButtondown.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
        }
        
        let pointsImage = UIImageView(image: .coin)
        pointsButton.addSubview(pointsImage)
        
        pointsImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        
        underunderpointsDisplayLabel = StrokeShadowLabel()
        underunderpointsDisplayLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderpointsDisplayLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderpointsDisplayLabel.shadowBlurRadius = 2.0
        underunderpointsDisplayLabel.text = "100"
        underunderpointsDisplayLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)!
        pointsButton.addSubview(underunderpointsDisplayLabel)
        
        underunderpointsDisplayLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(pointsButtondown.snp.left).offset(-8)
        }
        
        underpointsDisplayLabel = StrokeShadowLabel()
        underpointsDisplayLabel.shadowColor = UIColor.black.withAlphaComponent(0.03)
        underunderpointsDisplayLabel.text = "100"
        underpointsDisplayLabel.shadowOffset = CGSize(width: 0, height: 1)
        underpointsDisplayLabel.shadowBlurRadius = 4.0
        underpointsDisplayLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)!
        pointsButton.addSubview(underpointsDisplayLabel)
        
        underpointsDisplayLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderpointsDisplayLabel)
        }
        
        
        pointsDisplayLabel = GradientMaskLabel()
        pointsDisplayLabel.isUserInteractionEnabled = false
        pointsDisplayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)!
        pointsDisplayLabel.gradientStartColor = .color(hexString: "#FFC251")
        pointsDisplayLabel.gradientEndColor = .color(hexString: "#FF7738")
        pointsDisplayLabel.gradientDirection = (start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))
        pointsButton.addSubview(pointsDisplayLabel)
        pointsDisplayLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderpointsDisplayLabel)
        }
        
        let pointsLabel = UILabel()
        pointsLabel.text = "Points"
        pointsLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        pointsLabel.textColor = .color(hexString: "#322D3A")
        pointsButton.addSubview(pointsLabel)
        
        pointsLabel.snp.makeConstraints { make in
            make.left.equalTo(pointsImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        
        sharedButton = BorderGradientButton()
        sharedButton.layer.cornerRadius = 18
        sharedButton.addTarget(self, action: #selector(sharedButtonTapped), for: .touchUpInside)
        mainContentView.addSubview(sharedButton)
        
        sharedButton.snp.makeConstraints { make in
            make.top.equalTo(pointsButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
        }
        
        let sharedImage = UIImageView(image: .pinklove)
        sharedButton.addSubview(sharedImage)
        
        sharedImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        
        let sharedLabel = UILabel()
        sharedLabel.text = "Shared Aspiration"
        sharedLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        sharedLabel.textColor = .color(hexString: "#322D3A")
        sharedButton.addSubview(sharedLabel)
        
        sharedLabel.snp.makeConstraints { make in
            make.left.equalTo(sharedImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        checkImageView = UIImageView(image: .assignUnselect)
        sharedButton.addSubview(checkImageView)
        
        checkImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
            //            make.width.height.equalTo(24)
        }
        
        iconView = BorderGradientView()
        iconView.layer.cornerRadius = 18
        mainContentView.addSubview(iconView)
        
        iconView.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(403.0)
            make.top.equalTo(sharedButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        
        let iconLabel = UILabel()
        iconLabel.text = "Icon"
        iconLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        iconLabel.textColor = .color(hexString: "#322D3A")
        iconView.addSubview(iconLabel)
        
        iconLabel.snp.makeConstraints { make in
            make.left.equalTo(14)
            make.top.equalTo(14)
        }
        
        
        let verticalStackView = UIStackView()
        verticalStackView.axis = .vertical
        verticalStackView.spacing = 9
        verticalStackView.alignment = .center
        iconView.addSubview(verticalStackView)
        
        verticalStackView.snp.makeConstraints { make in
            make.top.equalTo(iconLabel.snp.bottom).offset(12)
            make.width.equalToSuperview()
            make.bottom.equalTo(-14)
        }
        
        // 3. 定义系统表情数组（这里提供了 56 个常用表情，你可以根据需要修改）
        let emojis = [
            "💖", "🏖️", "🌋", "🎡", "💒", "🛩️", "🗿",
            "🏕️", "🧗", "🌴", "🦧", "⛄️", "🪂", "⛷️",
            "🛥️", "🎰", "🎳", "🛶", "🎥", "⛸️", "🚞",
            "🏀", "🏸", "🏑", "🪁", "🎣", "🏓", "🤿",
            "🏇", "🏄", "🎪", "🎫", "🎬", "🎨", "🎹",
            "🎮", "🎺", "🏎️", "🧸", "🎢", "🏯", "🚁",
            "🏟️", "🪃", "⚽️", "🎾", "🏹", "🎱", "🛼",
            "🤹‍♀️", "🎭", "🗺️", "🎆", "🎞️", "💌", "🛍️️"
        ]
        
        emojiButtons.removeAll()
        emojiButtonImages.removeAll()
        
        // 4. 创建 8 行按钮
        for row in 0..<8 {
            // 创建水平方向的 stackView（包含 7 个按钮）
            let horizontalStackView = UIStackView()
            horizontalStackView.axis = .horizontal
            horizontalStackView.spacing = 15
            
            // 为当前行添加 7 个按钮
            for column in 0..<7 {
                // 计算当前表情在数组中的索引
                let index = row * 7 + column
                guard index < emojis.count else { break }
                
                let buttonContainer = UIView()
                horizontalStackView.addArrangedSubview(buttonContainer)
                buttonContainer.snp.makeConstraints { make in
                    make.width.height.equalTo(36)
                }
                
                
                // 创建表情按钮
                let emojiButton = UIButton()
                emojiButton.tag = index
                emojiButton.layer.cornerRadius = 8
                emojiButton.backgroundColor = .color(hexString: "#FBFBFB")
                
                // 添加按钮点击事件
                emojiButton.addTarget(self, action: #selector(emojiButtonTapped(_:)), for: .touchUpInside)
                buttonContainer.addSubview(emojiButton)
                // 设置按钮大小
                emojiButton.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                let bottomImageView = UIImageView(image: buttonBottomImage)
                bottomImageView.isUserInteractionEnabled = false
                bottomImageView.contentMode = .scaleAspectFit
                bottomImageView.clipsToBounds = true
                bottomImageView.isHidden = true
                emojiButton.addSubview(bottomImageView)
                bottomImageView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
                let buttonLabel = UILabel()
                buttonLabel.isUserInteractionEnabled = false
                buttonLabel.text = emojis[index] // 设置表情文本
                buttonLabel.font = UIFont.systemFont(ofSize: 24) // 表情字号
                buttonLabel.textAlignment = .center // 居中显示
                buttonLabel.isUserInteractionEnabled = false // 禁止交互，不影响按钮点击
                emojiButton.addSubview(buttonLabel)
                buttonLabel.snp.makeConstraints { make in
                    make.edges.equalToSuperview() // Label 铺满按钮，保证表情居中
                }
                
                emojiButtons.append(emojiButton)
                emojiButtonImages[index] = bottomImageView
            }
            
            verticalStackView.addArrangedSubview(horizontalStackView)
        }
        
        
        
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.layer.borderWidth = 1
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.addTarget(self, action: #selector(handleContinueButton), for: .touchUpInside)
        backView.addSubview(continueButton)
        
        continueButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottomMargin.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(56)
        }
        
        mainScrollView.snp.makeConstraints { make in
            make.bottom.equalTo(continueButton.snp.top).offset(-10)
        }
        
        mainContentView.snp.makeConstraints { make in
            make.bottom.equalTo(iconView.snp.bottom)
        }
        
        
        popup = WavesPopup(contentView: backView,
                           showType: .slideInFromBottom,
                           dismissType: .slideOutToBottom,
                           maskType: .dimmed,
                           dismissOnBackgroundTouch: true,
                           dismissOnContentTouch: false,
                           dismissPanView: hintView)
    }
    
    @objc private func emojiButtonTapped(_ sender: UIButton) {
        resetAllEmojiButtons()
        
        if let imageView = emojiButtonImages[sender.tag] {
            imageView.isHidden = false
            // 可选：添加图片显示动画
            UIView.animate(withDuration: 0.2) {
                imageView.alpha = 1
            }
        }
        
        if let buttonLabel = sender.subviews.compactMap({ $0 as? UILabel }).first {
            self.selectedEmoji = buttonLabel.text
            
        }
    }
    
    private func resetAllEmojiButtons() {
        emojiButtons.forEach { button in
            button.backgroundColor = .color(hexString: "#FBFBFB")
            
            if let imageView = emojiButtonImages[button.tag] {
                imageView.isHidden = true
            }
        }
    }
    
    @objc func handleContinueButton() {
        print("🔍 [WishViewPopup] handleContinueButton 开始")
        
        guard let title = titleTextFiled.text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AlertManager.showSingleButtonAlert(message: "Please enter a title", target: self)
            return
        }
        
        let notes = (notesTextView.text == "Notes" && notesTextView.textColor == .color(hexString: "#CACACA")) ? "" : notesTextView.text ?? ""
        
        guard let points = selectedPointValue, points > 0 else {
            AlertManager.showSingleButtonAlert(message: "Please select a score", target: self)
            return
        }
        
        guard let selectedEmoji = selectedEmoji else {
            AlertManager.showSingleButtonAlert(message: "Please select an emoticon", target: self)
            return
        }
        
        let isShared = self.isSharedChecked
        
        guard let homeVC = self.pointsView else {
            print("❌ [WishViewPopup] pointsView 为 nil")
            return
        }
        
        // ✅ 先关闭弹窗，避免卡顿
        self.popup.dismiss(animated: true)
        self.resetInputFields()
        
        // ✅ 将图片编码移到后台线程，避免主线程卡顿
        if addedImageViews.isEmpty {
            // 没有图片，直接添加
            print("✅ [WishViewPopup] 无图片，直接添加")
            homeVC.addPointsItem(
                title: title,
                notes: notes,
                imageURLs: [],
                points: points,
                isShared: isShared,
                wishImage: selectedEmoji
            )
        } else {
            // 有图片，在后台线程编码
            print("✅ [WishViewPopup] 有图片，开始后台编码 (\(addedImageViews.count) 张)")
            DispatchQueue.global(qos: .userInitiated).async { [weak self, weak homeVC] in
                guard let self = self, let homeVC = homeVC else { return }
                
                var imageURLs: [String] = []
                
                for imageView in self.addedImageViews {
                    guard let image = imageView.image else { continue }
                    
                    // ✅ 直接使用原始图片，不压缩
                    if let imageData = image.jpegData(compressionQuality: 1.0) {
                        let base64String = imageData.base64EncodedString()
                        let base64WithPrefix = "data:image/jpeg;base64,\(base64String)"
                        imageURLs.append(base64WithPrefix)
                    }
                }
                
                print("✅ [WishViewPopup] 图片编码完成，共 \(imageURLs.count) 张")
                
                // ✅ 回到主线程添加数据
                DispatchQueue.main.async { [weak homeVC] in
                    guard let homeVC = homeVC else { return }
                    homeVC.addPointsItem(
                        title: title,
                        notes: notes,
                        imageURLs: imageURLs,
                        points: points,
                        isShared: isShared,
                        wishImage: selectedEmoji
                    )
                }
            }
        }
    }
    
    private func topMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topVC = keyWindow.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
    
    @objc private func selectImageTapped() {
        guard let topController = topMostViewController() else { return }
        
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        
        DispatchQueue.main.async {  // 确保界面已经在 window 上
            topController.present(picker, animated: true, completion: nil)
        }
    }
    
    // MARK: - PHPickerViewControllerDelegate
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    guard let self = self, let image = object as? UIImage else { return }
                    DispatchQueue.main.async {
                        self.addImageToStackView(image)
                    }
                }
            }
        }
    }
    
    // 长按图片显示删除按钮的处理方法
    @objc private func handleImageLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        
        switch gesture.state {
        case .began:
            // 长按震动反馈
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            // 1. 先隐藏之前显示的删除按钮
            currentDeleteButton?.removeFromSuperview()
            // 2. 显示当前图片的删除按钮
            showDeleteButton(on: imageView)
        default:
            break
        }
    }
    
    // 在图片上显示删除按钮（右上角叉叉）
    private func showDeleteButton(on imageView: UIImageView) {
        // 移除已存在的删除按钮
        imageView.subviews.filter { $0.tag == 100 }.forEach { $0.removeFromSuperview() }
        
        // 创建删除按钮（增强显示效果）
        let deleteButton = UIButton()
        deleteButton.tag = 100
        deleteButton.setImage(UIImage(named: "pointsClose"), for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped(_:)), for: .touchUpInside)
        deleteButton.isUserInteractionEnabled = true
        
        // 添加到图片上（调整位置，避免超出图片）
        imageView.addSubview(deleteButton)
        deleteButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        // 优化动画，避免闪烁
        deleteButton.alpha = 0
        deleteButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.25) {
            deleteButton.alpha = 1
            deleteButton.transform = .identity
        }
        
        // 记录当前显示的删除按钮
        currentDeleteButton = deleteButton
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc private func hideCurrentDeleteButton() {
        guard let deleteButton = currentDeleteButton else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            deleteButton.alpha = 0
            deleteButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            deleteButton.removeFromSuperview()
            self.currentDeleteButton = nil
        }
    }
    
    // 点击删除按钮移除图片
    @objc private func deleteButtonTapped(_ sender: UIButton) {
        guard let imageView = sender.superview as? UIImageView else { return }
        
        // 1. 隐藏删除按钮
        sender.removeFromSuperview()
        currentDeleteButton = nil
        
        // 2. 添加删除动画
        UIView.animate(withDuration: 0.2, animations: {
            imageView.alpha = 0
            imageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { [weak self] _ in
            // 3. 从视图中移除
            self?.photoStackView.removeArrangedSubview(imageView)
            imageView.removeFromSuperview()
            
            // 4. 从存储数组中删除
            if let self = self, let index = self.addedImageViews.firstIndex(where: { $0 === imageView }) {
                self.addedImageViews.remove(at: index)
            }
        }
    }
    
    private func setupGlobalTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGlobalTap(_:)))
        tapGesture.cancelsTouchesInView = false // 不影响其他控件的点击事件
        tapGesture.delegate = self
        backView.addGestureRecognizer(tapGesture)
    }
    
    // 新增：处理全局点击，判断是否点击外部区域
    @objc private func handleGlobalTap(_ gesture: UITapGestureRecognizer) {
        guard let currentDeleteButton = currentDeleteButton else { return }
        
        // 1. 获取点击位置（转换为backView坐标系）
        let tapLocation = gesture.location(in: backView)
        
        // 2. 检查点击位置是否在删除按钮上
        let deleteButtonFrame = currentDeleteButton.convert(currentDeleteButton.bounds, to: backView)
        if deleteButtonFrame.contains(tapLocation) {
            return // 点击了删除按钮，不隐藏
        }
        
        // 3. 检查点击位置是否在任何图片上
        for imageView in addedImageViews {
            let imageFrame = imageView.convert(imageView.bounds, to: backView)
            if imageFrame.contains(tapLocation) {
                return // 点击了图片，不隐藏
            }
        }
        hideCurrentDeleteButton()
    }
    
    private func addImageToStackView(_ image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.layer.borderWidth = 0.6
        imageView.layer.borderColor = UIColor.color(hexString: "#E4E4E4").cgColor
        imageView.snp.makeConstraints { make in
            make.width.height.equalTo(66)
        }
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleImageLongPress(_:)))
        longPress.minimumPressDuration = 0.5 // 长按0.5秒触发
        imageView.addGestureRecognizer(longPress)
        imageView.isUserInteractionEnabled = true // 启用交互
        
        // 添加到栈视图和存储数组
        photoStackView.addArrangedSubview(imageView)
        addedImageViews.append(imageView)
    }
    
    @objc func sharedButtonTapped() {
        // 切换勾选状态
        self.backView.endEditing(true)
        isSharedChecked.toggle()
        
        let image = isSharedChecked ? selectedImage : unselectedImage
        checkImageView.image = image
    }
    
    private func resetInputFields() {
        titleTextFiled.text = nil
        notesTextView.text = "Notes"
        notesTextView.textColor = .color(hexString: "#CACACA") // 占位符颜色
        
        selectedPointValue = nil
        underunderpointsDisplayLabel.isHidden = true
        underpointsDisplayLabel.isHidden = true
        pointsDisplayLabel.isHidden = true // 隐藏分数显示
        isSharedChecked = false
        // ✅ 同步更新 checkImageView 的图片状态
        checkImageView.image = unselectedImage
        
        resetAllEmojiButtons()
        selectedEmoji = nil
        
        // ✅ 清空所有选中的图片
        for imageView in addedImageViews {
            photoStackView.removeArrangedSubview(imageView)
            imageView.removeFromSuperview()
        }
        addedImageViews.removeAll()
        
        forceDismissKeyboardForPopup()
    }
    
    func show(width: CGFloat, bottomSpacing: CGFloat) {
        resetInputFields()
        mainScrollView.contentOffset = .zero
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        // 弹窗高度按屏幕比例：1027 / 1144（与 Add Anni 一致）
        let screenHeight = UIScreen.main.bounds.height
        let popupHeight = screenHeight * (695.0 / 812.0)
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: popupHeight)
        backView.layoutNow()
    }
    
    private func forceDismissKeyboardForPopup() {
        titleTextFiled.resignFirstResponder()
        notesTextView.resignFirstResponder()
        backView.endEditing(true)
        backView.window?.endEditing(true)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
         if textView === notesTextView, text == "\n" {
             forceDismissKeyboardForPopup()
             return false
         }
         return true
     }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
         // Title 上点完成/对勾：直接收起（不再依赖 keyWindow，避免弹窗 window 收不掉）
         forceDismissKeyboardForPopup()
         return true
     }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .color(hexString: "#CACACA") {
            textView.text = nil
            textView.textColor = .color(hexString: "#999DAB")
        }
    }
    
    // 当停止编辑时
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Notes" // 恢复占位符
            textView.textColor = .color(hexString: "#CACACA")
        }
    }
}
