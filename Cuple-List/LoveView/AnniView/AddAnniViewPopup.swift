//
//  AddAnniViewPopup.swift
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

class AddAnniViewPopup: NSObject, UITextFieldDelegate, UITextViewDelegate,PHPickerViewControllerDelegate, UIGestureRecognizerDelegate{
    var anniViewController: AnniViewController!
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
//    var notesTextView: UITextView!
    /// 点击唤起 Title 键盘的遮罩：默认禁用输入框触摸，仅能点此 view 弹出键盘
    private var titleInputTriggerView: UIView!
    var selectImageButton: UIButton!
    var photoScrollView: UIScrollView!
    var photoStackView: UIStackView!
    
    var dateButton: BorderGradientButton!
    var dateDisplayLabel: UILabel!
    var selectedDate: Date? = nil
    
    
    var repeatButton: BorderGradientButton!
    var repeatSelectionText: UILabel!
    var advanceButton: BorderGradientButton!
    var advanceSelectionText: UILabel!
    /// 「与对方同步」：开 = 写入 Firestore；关 = 仅本地 Core Data
    private var shareWithPartnerRow: BorderGradientView!
    private var shareWithPartnerSwitch: UISwitch!
    var iconView: UIView!
    private var selectedEmoji: String?
    private var emojiButtons: [UIButton] = []
    private var emojiButtonImages: [Int: UIImageView] = [:]
    private let buttonBottomImage = UIImage(named: "iconback")
    var continueButton: UIButton!
    
    private var addedImageViews: [UIImageView] = []
    private weak var currentDeleteButton: UIButton?
    
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
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
        titleLabel.text = "New Moment"
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
            make.height.equalTo(148)
        }
        
        titleTextFiled = UITextField()
        titleTextFiled.attributedPlaceholder = NSAttributedString(string: "e.g. First Date, Birthday", attributes: [.foregroundColor : UIColor.color(hexString: "#CACACA")])
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
        
        titleTextFiled.inputAccessoryView = nil
        // 关闭输入框原本点击弹出键盘：只能通过下方 trigger view 点击唤起
        titleTextFiled.isUserInteractionEnabled = false
        
        titleInputTriggerView = UIView()
        titleInputTriggerView.backgroundColor = .clear
        titleInputTriggerView.isUserInteractionEnabled = true
        textFiledView.addSubview(titleInputTriggerView)
        titleInputTriggerView.snp.makeConstraints { make in
            make.edges.equalTo(titleTextFiled)
        }
        let titleTap = UITapGestureRecognizer(target: self, action: #selector(onTitleTriggerTapped))
        titleInputTriggerView.addGestureRecognizer(titleTap)
        
        let textFiledLine = UIView()
        textFiledLine.backgroundColor = .color(hexString: "#484848").withAlphaComponent(0.05)
        textFiledView.addSubview(textFiledLine)
        
        textFiledLine.snp.makeConstraints { make in
            make.top.equalTo(titleTextFiled.snp.bottom)
            make.height.equalTo(1)
            make.width.equalToSuperview().multipliedBy(307.0 / 335.0)
            make.centerX.equalToSuperview()
        }
        
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
        
        dateButton = BorderGradientButton()
        dateButton.layer.cornerRadius = 18
        dateButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            let datePopup = AnniDatePopup()
            self.backView.endEditing(true)
            datePopup.onDateSelected = { [weak self] selectedDate in
                self?.selectedDate = selectedDate
                self?.updateDateButtonTitle()
                datePopup.popup.dismiss(animated: true)
            }
            datePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
        }
        mainContentView.addSubview(dateButton)
        
        dateButton.snp.makeConstraints { make in
            make.top.equalTo(textFiledView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
        }
        
        let dateButtondown = UIImageView(image: .adddown)
        dateButton.addSubview(dateButtondown)
        
        dateButtondown.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
        }
        
        let dateImage = UIImageView(image: .dateimage)
        dateButton.addSubview(dateImage)
        
        dateImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        
        dateDisplayLabel = UILabel()
        dateDisplayLabel.isUserInteractionEnabled = false
        dateDisplayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        dateDisplayLabel.textColor = .color(hexString: "#999DAB")
        dateButton.addSubview(dateDisplayLabel)
        
        dateDisplayLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(dateButtondown.snp.left).offset(-8)
        }
        
        let dateLabel = UILabel()
        dateLabel.text = "Date"
        dateLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        dateLabel.textColor = .color(hexString: "#322D3A")
        dateButton.addSubview(dateLabel)
        
        dateLabel.snp.makeConstraints { make in
            make.left.equalTo(dateImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        repeatButton = BorderGradientButton()
        repeatButton.layer.cornerRadius = 18
        repeatButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.backView.endEditing(true)
            
            let repeatPopup = RepeatPopup()
            repeatPopup.homeViewController1 = self.anniViewController
            
            // 新增：RepeatPopup 选择回调
            repeatPopup.onRepeatSelected = { [weak self] isNever, number, unit in
                guard let self = self else { return }
                if isNever {
                    self.updateRepeatSelection(text: "Never")
                } else {
                    self.updateRepeatSelection(text: "Every \(number) \(unit)")
                }
                repeatPopup.popup.dismiss(animated: true)
            }
            
            repeatPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
        }
        mainContentView.addSubview(repeatButton)
        
        repeatButton.snp.makeConstraints { make in
            make.top.equalTo(dateButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
        }
        
        let repeatImageView = UIImageView(image: UIImage(named: "repeatImage"))
        repeatButton.addSubview(repeatImageView)
        
        repeatImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        
        let repeatLabel = UILabel()
        repeatLabel.text = "Repeat"
        repeatLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        repeatLabel.textColor = .color(hexString: "#322D3A")
        repeatButton.addSubview(repeatLabel)
        
        repeatLabel.snp.makeConstraints { make in
            make.left.equalTo(repeatImageView.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        let repeatButtondown = UIImageView(image: .adddown)
        repeatButton.addSubview(repeatButtondown)
        
        repeatButtondown.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
        }
        
        repeatSelectionText = UILabel()
        repeatSelectionText.textColor = .color(hexString: "#999DAB")
        repeatSelectionText.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        repeatButton.addSubview(repeatSelectionText)
        
        repeatSelectionText.snp.makeConstraints { make in
            make.right.equalTo(repeatButtondown.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        
        advanceButton = BorderGradientButton()
        advanceButton.layer.cornerRadius = 18
        advanceButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.backView.endEditing(true)
            let advancePopup = AdvancePopup()
            
            // 使用新增的 onAdvanceSelected 回调（推荐，已处理好文本）
            advancePopup.onAdvanceSelected = { [weak self] isNever, timePointText, advanceText in
                guard let self = self else { return }
                
                if isNever {
                    // 无提醒
                    self.advanceSelectionText.text = "No reminder"
                } else if let timeText = timePointText {
                    // That day 模式 - 直接使用格式化后的时间文本
                    self.advanceSelectionText.text = timeText // 如 "02:30 PM"
                } else if let advanceText = advanceText {
                    // In advance 模式 - 直接使用构建好的提前时间文本
                    self.advanceSelectionText.text = advanceText // 如 "2 days 3 hr 15 min PM"
                }
                advancePopup.popup.dismiss(animated: true)
            }
            advancePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
        }
        mainContentView.addSubview(advanceButton)
        
        advanceButton.snp.makeConstraints { make in
            make.top.equalTo(repeatButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
        }
        
        let advanceButtondown = UIImageView(image: .adddown)
        advanceButton.addSubview(advanceButtondown)
        
        advanceButtondown.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
        }
        
        let advanceImage = UIImageView(image: .reminderimage)
        advanceButton.addSubview(advanceImage)
        
        advanceImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        
        let advanceLabel = UILabel()
        advanceLabel.text = "Reminder"
        advanceLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        advanceLabel.textColor = .color(hexString: "#322D3A")
        advanceButton.addSubview(advanceLabel)
        
        advanceLabel.snp.makeConstraints { make in
            make.left.equalTo(advanceImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        advanceSelectionText = UILabel()
        advanceSelectionText.textColor = .color(hexString: "#999DAB")
        advanceSelectionText.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        advanceButton.addSubview(advanceSelectionText)
        
        advanceSelectionText.snp.makeConstraints { make in
            make.right.equalTo(advanceButtondown.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        shareWithPartnerRow = BorderGradientView()
        shareWithPartnerRow.layer.cornerRadius = 18
        shareWithPartnerRow.isUserInteractionEnabled = true
        mainContentView.addSubview(shareWithPartnerRow)
        shareWithPartnerRow.snp.makeConstraints { make in
            make.top.equalTo(advanceButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
        }
        
        let shareIcon = UIImageView(image: .assignimage)
        shareWithPartnerRow.addSubview(shareIcon)
        shareIcon.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        let shareLabel = UILabel()
        shareLabel.text = "Shared With"
        shareLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        shareLabel.textColor = .color(hexString: "#322D3A")
        shareWithPartnerRow.addSubview(shareLabel)
        shareLabel.snp.makeConstraints { make in
            make.left.equalTo(shareIcon.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        shareWithPartnerSwitch = UISwitch()
        shareWithPartnerSwitch.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
//        shareWithPartnerSwitch.onTintColor = .color(hexString: "#322D3A")
        shareWithPartnerSwitch.isOn = true
        shareWithPartnerRow.addSubview(shareWithPartnerSwitch)
        shareWithPartnerSwitch.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
        }
        
        iconView = BorderGradientView()
        iconView.layer.cornerRadius = 18
        mainContentView.addSubview(iconView)
        
        iconView.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(shareWithPartnerRow.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.height.equalTo(404.0)
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
            //            horizontalStackView.distribution = .fillEqually
            
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
    
    private func updateDateButtonTitle() {
        if let date = selectedDate {
            dateDisplayLabel.text = "Target Date : \(dateFormatter.string(from: date))"
        } else {
            dateDisplayLabel.text = "Target Date"
        }
        dateDisplayLabel.textColor = .color(hexString: "#999DAB")
    }
    
    
    func updateRepeatSelection(text: String) {
        repeatSelectionText.text = "\(text)"
        //        updateSelectionDisplay()
    }
    
    func updateAdvanceSelection(text: String) {
        advanceSelectionText.text = "\(text)"
        //        updateSelectionDisplay()
    }
    
    private func resetInputFields() {
        titleTextFiled.text = nil
//        titleTextFiled.resignFirstResponder()
        titleInputTriggerView?.isHidden = false
        titleTextFiled.isUserInteractionEnabled = false
        
        selectedDate = nil
        updateDateButtonTitle()
        
        shareWithPartnerSwitch?.isOn = true
        
        // 重置表情选择
        resetAllEmojiButtons()
        selectedEmoji = nil
        
        // ✅ 清空所有选中的图片
        for imageView in addedImageViews {
            photoStackView.removeArrangedSubview(imageView)
            imageView.removeFromSuperview()
        }
        addedImageViews.removeAll()
        
        // 未选择不显示文案，等用户选了再显示；提交时用默认值
        repeatSelectionText.text = ""
        advanceSelectionText.text = ""
        titleTextFiled.resignFirstResponder()
        forceDismissKeyboardForPopup()
    }
    
    private func resetAllEmojiButtons() {
        emojiButtons.forEach { button in
            button.backgroundColor = .color(hexString: "#FBFBFB")
            
            if let imageView = emojiButtonImages[button.tag] {
                imageView.isHidden = true
            }
        }
    }
    
    // ✅ 从Base64字符串解码图片
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
        
        let image: UIImage? = autoreleasepool {
            UIImage(data: imageData)
        }
        
        guard let image = image, image.size.width > 0 && image.size.height > 0 else {
            return nil
        }
        
        let pixelCount = image.size.width * image.size.height
        guard pixelCount < 50_000_000 else {
            return nil
        }
        
        return image
    }
    
    private func forceDismissKeyboardForPopup() {
        titleTextFiled.resignFirstResponder()
        // notesTextView 未在 setupUI 里创建，仅用 ! 会在 show→resetInputFields 时崩；有则收起，无则跳过
//        notesTextView?.resignFirstResponder()
        backView.endEditing(true)
        backView.window?.endEditing(true)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === titleTextFiled {
            titleTextFiled.isUserInteractionEnabled = false
            titleInputTriggerView?.isHidden = false
        }
    }
    
    @objc private func onTitleTriggerTapped() {
        titleInputTriggerView.isHidden = true
        titleTextFiled.isUserInteractionEnabled = true
        titleTextFiled.becomeFirstResponder()
    }
//    
//     MARK: - UITextFieldDelegate（Title 完成键 / 系统键盘对勾）
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Title 上点完成/对勾：直接收起（不再依赖 keyWindow，避免弹窗 window 收不掉）
        forceDismissKeyboardForPopup()
        return true
    }
    
    @objc func handleContinueButton() {
        // 必填：title、assign、icon，缺一弹窗提醒
        guard let title = titleTextFiled.text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AlertManager.showSingleButtonAlert(message: "Please enter a title", target: self)
            return
        }
        
        let isShared = shareWithPartnerSwitch.isOn
        let assignIndex = isShared ? TaskAssignIndex.both.rawValue : TaskAssignIndex.myself.rawValue
        
        guard let selectedEmoji = selectedEmoji else {
            AlertManager.showSingleButtonAlert(message: "Please select an icon", target: self)
            return
        }
        
        // 非必填：date 默认今天，repeat 默认 Never，advance 默认 No reminder
        let taskDate = selectedDate ?? Date()
        let repeatText = (repeatSelectionText.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Never"
        let advanceText = (advanceSelectionText.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "No reminder"
        
        guard let homeVC = self.anniViewController else {
            return
        }
        
        // ✅ 将选中的图片转换为 Base64，并压缩以符合 Firestore 单文档 1MB 限制，保证能同步到另一台设备
        let imageURLs = compressedImageURLsForFirestore(from: addedImageViews)
        
        // ✅ 修复：只要用户选择了提醒时间（不是"No reminder"），就应该创建通知
        let isReminder = advanceText != "No reminder"
        let isNever = repeatText == "Never"
        
        homeVC.addAnniItem(titleLabel: title,
                           targetDate: taskDate,
                           repeatDate: repeatText,
                           isNever: isNever,
                           advanceDate: advanceText,
                           isReminder: isReminder,
                           assignIndex: assignIndex,
                           imageURLs: imageURLs, // ✅ 传递图片 URL 数组
                           wishImage: selectedEmoji,
                           isShared: isShared
        )
        let droppedCount = addedImageViews.count - imageURLs.count
        self.popup.dismiss(animated: true)
        self.resetInputFields()
        if droppedCount > 0 {
            print("Due to sync size limit, only \(imageURLs.count) photo(s) were saved. \(droppedCount) photo(s) were not saved. Suggest adding 1–3 photos per anni for reliable sync.")
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
        self.backView.endEditing(true)
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
    
    // MARK: - PHPickerViewControllerDelegate（顺序加载 + 失败重试一次 + 成功后再进下一张，减少多选遗漏）
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard !results.isEmpty else { return }
        
        let validResults = results.filter { $0.itemProvider.canLoadObject(ofClass: UIImage.self) }
        guard !validResults.isEmpty else { return }
        
        var index = 0
        var retryCount = 0
        let loadInterval: TimeInterval = 0.45
        
        func loadNext() {
            guard index < validResults.count else { return }
            let result = validResults[index]
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self = self else { return }
                guard let image = object as? UIImage else {
                    if retryCount < 1 {
                        retryCount += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { loadNext() }
                    } else {
                        retryCount = 0
                        index += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { loadNext() }
                    }
                    return
                }
                retryCount = 0
                DispatchQueue.main.async {
                    let resized = self.resizeImageForSync(image, maxDimension: 1024)
                    self.addImageToStackView(resized)
                    index += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + loadInterval) { loadNext() }
                }
            }
        }
        loadNext()
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
    
    /// Firestore 单文档限制 1 MiB，图片以 Base64 写入同一文档，过大会导致整次写入失败、另一台设备收不到。此处压缩并限制总大小，保证能同步。
    private func compressedImageURLsForFirestore(from imageViews: [UIImageView]) -> [String] {
        let maxDocBytes = 1_048_576
        let reserveForOtherFields = 150_000
        let maxImagePayloadBytes = maxDocBytes - reserveForOtherFields
        let maxBytesPerImage = 240_000
        var result: [String] = []
        var totalBytes = 0
        
        for imageView in imageViews {
            guard totalBytes < maxImagePayloadBytes, let image = imageView.image else { continue }
            let resized = resizeImageForSync(image, maxDimension: 1024)
            var quality: CGFloat = 0.5
            var best: String?
            var bestBytes = Int.max
            while quality >= 0.2 {
                guard let data = resized.jpegData(compressionQuality: quality) else { quality -= 0.1; continue }
                let str = "data:image/jpeg;base64,\(data.base64EncodedString())"
                let bytes = str.utf8.count
                if bytes <= maxBytesPerImage {
                    best = str
                    bestBytes = bytes
                    break
                }
                if bytes < bestBytes { best = str; bestBytes = bytes }
                quality -= 0.1
            }
            // 单张图时兜底：常规压缩失败（如部分格式）仍用原图低质量保存，避免“上传一张被自动删掉”
            if best == nil, let fallbackData = resized.jpegData(compressionQuality: 0.15) ?? image.jpegData(compressionQuality: 0.15) {
                best = "data:image/jpeg;base64,\(fallbackData.base64EncodedString())"
            }
            guard let str = best, totalBytes + str.utf8.count <= maxImagePayloadBytes else { break }
            result.append(str)
            totalBytes += str.utf8.count
        }
        return result
    }
    
    private func resizeImageForSync(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        guard w > maxDimension || h > maxDimension else { return image }
        let scale = min(maxDimension / w, maxDimension / h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
    
    func show(width: CGFloat, bottomSpacing: CGFloat) {
        resetInputFields()
        mainScrollView.contentOffset = .zero
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        // 弹窗高度按屏幕比例：1027 / 1144
        let screenHeight = UIScreen.main.bounds.height
        let popupHeight = screenHeight * (695.0 / 812.0)
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: popupHeight)
        backView.layoutNow()
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .color(hexString: "#CACACA") {
            textView.text = nil
            textView.textColor = .black // 设置用户输入文本的颜色
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
