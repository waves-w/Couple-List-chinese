//
//  AnniEditViewPopup.swift
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

class AnniEditViewPopup: NSObject, UITextFieldDelegate, UITextViewDelegate,PHPickerViewControllerDelegate, UIGestureRecognizerDelegate{
    /// 用于 Repeat 订阅链、订阅校验；顶部列表编辑时由 `AnniViewController` 赋值
    weak var anniViewController: AnniViewController?
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var deleteButton: UIButton!
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
    
    var dateButton: BorderGradientButton!
    var repeatSelectionText: UILabel!
    var repeatButton: BorderGradientButton!
    var advanceButton: BorderGradientButton!
    var advanceSelectionText: UILabel!
    private var shareWithPartnerRow: BorderGradientView!
    private var shareWithPartnerSwitch: UISwitch!
    var iconView: UIView!
    private var selectedEmoji: String?
    private var emojiButtons: [UIButton] = []
    private var emojiButtonImages: [Int: UIImageView] = [:]
    private let buttonBottomImage = UIImage(named: "iconback")
    var continueButton: UIButton!
    var anniModel: AnniModel!
    
    var onEditComplete: (() -> Void)?
    var onEditAndCloseComplete: (() -> Void)?
    /// 在编辑弹窗内确认删除并成功执行后调用（用于刷新列表或 pop 详情页）
    var onDeleteComplete: (() -> Void)?
    
    private var deleteConfirmPopup: DeleteConfirmPopup?
    
    var dateDisplayLabel: UILabel!
    var selectedDate: Date? = nil
    
    private var addedImageViews: [UIImageView] = []
    private weak var currentDeleteButton: UIButton?
    
    // 定义表情数组（全局可访问）
    private let emojis = [
        "💖", "🏖️", "🌋", "🎡", "💒", "🛩️", "🗿",
        "🏕️", "🧗", "🌴", "🦧", "⛄️", "🪂", "⛷️",
        "🛥️", "🎰", "🎳", "🛶", "🎥", "⛸️", "🚞",
        "🏀", "🏸", "🏑", "🪂", "🎣", "🏓", "🤿",
        "🏇", "🏄", "🎪", "🎫", "🎬", "🎨", "🎹",
        "🎮", "🎺", "🏎️", "🧸", "🎢", "🏯", "🚁",
        "🏟️", "🪃", "⚽️", "🎾", "🏹", "🎱", "🛼",
        "🤹‍♀️", "🎭", "🗺️", "🎆", "🎞️", "💌", "🛍️️"
    ]
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
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
        
        deleteButton = UIButton()
        deleteButton.setImage(UIImage(named: "delete_icon"), for: .normal)
        deleteButton.addTarget(self, action: #selector(editDeleteButtonTapped), for: .touchUpInside)
        backView.addSubview(deleteButton)
        deleteButton.snp.makeConstraints { make in
            make.right.equalTo(-20)
            make.centerY.equalTo(closeButton)
            make.width.height.equalTo(32)
        }
        
        titleLabel = UILabel()
        titleLabel.text = "Edit Moment" // 修改标题为编辑
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
            let datePopup = DatePopup()
            self.backView.endEditing(true)
            datePopup.onDateSelected = { [weak self] selectedDate in
                self?.selectedDate = selectedDate
                self?.updateDateButtonTitle()
                datePopup.popup.dismiss(animated: true)
            }
            datePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing, initialDate: self.selectedDate)
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
        
        dateDisplayLabel = UILabel()
        dateDisplayLabel.isUserInteractionEnabled = false
        dateDisplayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        dateDisplayLabel.textColor = .color(hexString: "#999DAB")
        dateButton.addSubview(dateDisplayLabel)
        
        dateDisplayLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(dateButtondown.snp.left).offset(-8)
        }
        
        let dateImage = UIImageView(image: .dateimage)
        dateButton.addSubview(dateImage)
        
        dateImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
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
            let (repNever, repNum, repUnit) = parseRepeatText(repeatSelectionText.text)
            repeatPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing,
                            initialIsNever: repNever, initialNumber: repNum, initialUnit: repUnit)
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
            advancePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing, initialAdvanceText: self.advanceSelectionText.text)
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
        continueButton.setTitle("Save", for: .normal) // 修改按钮文字为Save
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
    
    private func selectEmojiByText(_ emojiText: String) {
        // 1. 找到表情在数组中的索引
        guard let emojiIndex = emojis.firstIndex(of: emojiText) else {
            print("表情 \(emojiText) 不存在于表情列表中")
            return
        }
        
        // 2. 重置所有表情按钮状态
        resetAllEmojiButtons()
        
        // 3. 找到对应的表情按钮并选中
        guard let targetButton = emojiButtons.first(where: { $0.tag == emojiIndex }),
              let imageView = emojiButtonImages[emojiIndex] else {
            return
        }
        
        // 4. 设置选中状态
        imageView.isHidden = false
        imageView.alpha = 1
        self.selectedEmoji = emojiText
    }
    
    private func resetAllEmojiButtons() {
        emojiButtons.forEach { button in
            button.backgroundColor = .color(hexString: "#FBFBFB")
            
            if let imageView = emojiButtonImages[button.tag] {
                imageView.isHidden = true
                imageView.alpha = 0
            }
        }
    }
    
    func updateRepeatSelection(text: String) {
        repeatSelectionText.text = "Repeat: \(text)"
    }
    
    func updateAdvanceSelection(text: String) {
        advanceSelectionText.text = "Advance: \(text)"
    }
    
    /// 解析重复文案为 (isNever, number, unit)，用于 Repeat 弹窗回显
    private func parseRepeatText(_ text: String?) -> (isNever: Bool?, number: Int?, unit: String?) {
        let s = (text ?? "").trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "Repeat:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        if s.isEmpty || s == "Never" { return (true, nil, nil) }
        guard s.hasPrefix("Every "), s.count > 6 else { return (nil, nil, nil) }
        let rest = String(s.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map { String($0) }
        guard parts.count >= 2, let num = Int(parts[0]) else { return (nil, nil, nil) }
        let unitRaw = parts[1]
        let unit: String
        if unitRaw.hasPrefix("Day") { unit = "Day" }
        else if unitRaw.hasPrefix("Week") { unit = "Week" }
        else if unitRaw.hasPrefix("Month") { unit = "Month" }
        else if unitRaw.hasPrefix("Year") { unit = "Year" }
        else { return (false, num, nil) }
        return (false, num, unit)
    }
    
    private func updateDateButtonTitle() {
        let dateText: String
        
        if let date = selectedDate {
            dateText = dateFormatter.string(from: date)
        } else {
            dateText = "Today"
            selectedDate = Date() // 如果未选择，默认今天
        }
        dateDisplayLabel.text = dateText
        dateDisplayLabel.textColor = .color(hexString: "#322D3A")
    }
    
    @objc private func dismissKeyboardFromToolbar() {
        backView.endEditing(true)
    }
    
    @objc func handleContinueButton() {
        // 1. 收集数据
        guard let title = titleTextFiled.text, !title.isEmpty else {
            print("❌ 标题不能为空")
            AlertManager.showSingleButtonAlert(message: "Please enter a title", target: self)
            return
        }
        
        guard let taskDate = selectedDate ?? Date() as? Date else {
            print("❌ 日期获取失败，阻断提交")
            AlertManager.showSingleButtonAlert(message: "Please select task date", target: self)
            return
        }
        
        let repeatText = repeatSelectionText.text ?? "Never"
        guard !repeatText.isEmpty else {
            AlertManager.showSingleButtonAlert(message: "Please select a recurrence", target: self)
            return
        }
        
        let advanceText = advanceSelectionText.text ?? "No reminder"
        guard !advanceText.isEmpty else {
            AlertManager.showSingleButtonAlert(message: "Please select reminder time", target: self)
            return
        }
        
        let isShared = shareWithPartnerSwitch.isOn
        let assignIndex = isShared ? TaskAssignIndex.both.rawValue : TaskAssignIndex.myself.rawValue
        
        guard let selectedEmoji = selectedEmoji else {
            AlertManager.showSingleButtonAlert(message: "Please select an emoticon", target: self)
            return
        }
        
        let isReminder = advanceText != "No reminder" && repeatText != "Never"
        let isNever = repeatText == "Never"
        
        // ✅ 将选中的图片压缩以符合 Firestore 单文档 1MB 限制，保证能同步到另一台设备
        let imageURLs = compressedImageURLsForFirestore(from: addedImageViews)
        let droppedCount = addedImageViews.count - imageURLs.count
        if droppedCount > 0 {
            print("Due to sync size limit, only \(imageURLs.count) photo(s) were saved. \(droppedCount) photo(s) were not saved. Suggest adding 1–3 photos per anni for reliable sync.")
        }
        
        var updatedData: [String: Any?] = [
            "titleLabel": title,
            "targetDate": taskDate,
            "repeatDate": repeatText,
            "isNever": isNever,
            "advanceDate": advanceText,
            "isReminder": isReminder,
            "assignIndex": assignIndex,
            "wishImage": selectedEmoji,
            "isShared": isShared
        ]
        
        // ✅ 添加图片 URL 数组到更新数据
        updatedData["imageURLs"] = imageURLs
        
        if let modelToEdit = anniModel {
            // 编辑模式：调用更新方法
            guard let itemId = modelToEdit.id else { return }
            AnniManger.manager.AnniupdateItem(withId: itemId, updatedData: updatedData)
            onEditComplete?()
        } else {
            // 注意：这里的 senderUID 应该从你的用户管理器中获取
            print("⚠️ 编辑弹窗中没有找到 modelToEdit，可能是逻辑错误。")
        }
        
        // 5. 关闭弹窗（编辑模式下不重置输入项）
        self.popup.dismiss(animated: true)
        onEditAndCloseComplete?()
    }
    
    @objc private func editDeleteButtonTapped() {
        let presenter = anniViewController ?? UIViewController.getCurrentViewController(base: nil)
        guard SubscriptionPaywallGate.requireSubscription(from: presenter) else { return }
        guard let model = anniModel else { return }
        forceDismissKeyboardForPopup()
        
        deleteConfirmPopup = DeleteConfirmPopup(
            title: "Delete this moment?",
            message: "Are you sure you want to delete \(model.titleLabel ?? "this record")?",
            imageName: "delete_icon",
            cancelTitle: "Cancel",
            confirmTitle: "Delete",
            confirmBlock: { [weak self] in
                guard let self = self else { return }
                AnniManger.manager.deleteModel(model)
                self.deleteConfirmPopup = nil
                self.popup.dismiss(animated: true)
                self.onDeleteComplete?()
            },
            cancelBlock: { [weak self] in
                self?.deleteConfirmPopup = nil
            }
        )
        deleteConfirmPopup?.show()
    }
    
    func configureUI(with model: AnniModel) {
        self.anniModel = model
        
        // 1. 设置标题
        titleTextFiled.text = model.titleLabel ?? ""
        
        // 2. 设置日期
        selectedDate = model.targetDate ?? Date()
        updateDateButtonTitle()
        
        // 3. 设置重复和提醒文本
        repeatSelectionText.text = model.repeatDate ?? ""
        advanceSelectionText.text = model.advanceDate ?? ""
        
        // 4. 是否与对方同步（Core Data `isShared`）
        shareWithPartnerSwitch.isOn = model.isShared
        
        // 5. 关键：根据wishImage选中对应的表情按钮
        if let wishImageText = model.wishImage, !wishImageText.isEmpty {
            selectEmojiByText(wishImageText)
        }
        
        // ✅ 加载已有图片（从 Base64 字符串数组解码并显示）
        loadExistingImages(from: model)
    }
    
    // ✅ 从模型加载已有图片
    private func loadExistingImages(from model: AnniModel) {
        // 先清空现有图片
        for imageView in addedImageViews {
            photoStackView.removeArrangedSubview(imageView)
            imageView.removeFromSuperview()
        }
        addedImageViews.removeAll()
        
        // 从模型获取图片 URL 数组
        let imageURLs = AnniManger.manager.getImageURLs(from: model)
        
        // 将 Base64 字符串解码为图片并显示
        for imageURLString in imageURLs {
            if let image = imageFromBase64String(imageURLString) {
                addImageToStackView(image)
            }
        }
    }
    
    // ✅ 从Base64字符串解码图片（添加异常处理，避免崩溃）
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        let startTime = Date()
        print("🔍 [AnniEditViewPopup] imageFromBase64String 开始 - 输入长度: \(base64String.count)")
        
        // ✅ 安全检查：空字符串
        guard !base64String.isEmpty else {
            print("❌ [AnniEditViewPopup] Base64字符串为空")
            return nil
        }
        
        // ✅ 安全检查：字符串长度限制（避免内存溢出）
        guard base64String.count < 10_000_000 else { // 约10MB
            print("❌ [AnniEditViewPopup] Base64字符串过长，可能损坏: \(base64String.count) 字符")
            return nil
        }
        
        var base64 = base64String
        let originalLength = base64.count
        if base64.hasPrefix("data:image/"), let range = base64.range(of: ",") {
            base64 = String(base64[range.upperBound...])
            print("🔍 [AnniEditViewPopup] 移除data:image前缀 - 原始长度: \(originalLength), 处理后长度: \(base64.count)")
        }
        
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            print("❌ [AnniEditViewPopup] Base64解码失败 - 字符串长度: \(base64.count), 前100字符: \(String(base64.prefix(100)))")
            return nil
        }
        
        let decodeTime = Date().timeIntervalSince(startTime)
        print("✅ [AnniEditViewPopup] Base64解码成功 - 耗时: \(String(format: "%.3f", decodeTime))秒, 数据大小: \(imageData.count) 字节")
        
        // ✅ 安全检查：数据大小限制
        guard imageData.count < 5_000_000 else { // 约5MB
            print("❌ [AnniEditViewPopup] 图片数据过大: \(imageData.count) 字节")
            return nil
        }
        
        guard let image = UIImage(data: imageData) else {
            print("❌ [AnniEditViewPopup] 无法从数据创建UIImage - 数据大小: \(imageData.count) 字节, 前16字节: \(imageData.prefix(16).map { String(format: "%02x", $0) }.joined())")
            return nil
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // ✅ 验证图片是否有效
        guard image.size.width > 0 && image.size.height > 0 else {
            print("❌ [AnniEditViewPopup] 图片尺寸无效: \(image.size)")
            return nil
        }
        
        print("✅ [AnniEditViewPopup] 图片创建成功 - 总耗时: \(String(format: "%.3f", totalTime))秒, 尺寸: \(image.size), scale: \(image.scale)")
        return image
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
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: iconView.maxY() - bottomSpacing - 50)
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

    /// 弹窗在 FFPopup 的 window 里时，优先用 window.endEditing 收起键盘（与 AddViewPopup 一致）
    private func forceDismissKeyboardForPopup() {
        if let w = backView.window {
            w.endEditing(true)
            return
        }
        backView.endEditing(true)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - UITextFieldDelegate（Title 完成键收起键盘，与 AddViewPopup 一致）
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        forceDismissKeyboardForPopup()
        return true
    }
}
