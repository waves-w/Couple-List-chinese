//
//  AddViewPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup
import UserNotifications



class AddViewPopup: NSObject, UITextFieldDelegate, UITextViewDelegate{
    var homeViewController: HomeViewController!
    var backView: ViewGradientView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    var textFiledView: BorderGradientView!
    var titleTextFiled: UITextField!
    var notesTextView: UITextView!
    /// Notes 占位符（独立 Label），避免通过修改 TextView 的 text 触发布局与重绘，减轻第三方键盘卡顿
    private var notesPlaceholderLabel: UILabel!
    /// 点击唤起 Title 键盘，盖在 titleTextFiled 上；键盘弹出后隐藏，收起后再显示
    private var titleInputTriggerView: UIView!
    /// 点击唤起 Notes 键盘，盖在 notesTextView 上；键盘弹出后隐藏，收起后再显示
    private var notesInputTriggerView: UIView!
    
    var dataView: BorderGradientView!
    var dateButton: UIButton!
    var timeButton: UIButton!
    
    var reminderView: BorderGradientView!
    var switchView: UISwitch!
    
    var pointsButton: UIButton!
    var assignButton: BorderGradientButton!
    var continueButton: UIButton!
    
    var dateDisplayLabel: UILabel!
    var timeDisplayLabel: UILabel!
    var underunderpointsDisplayLabel: StrokeShadowLabel!
    var underpointsDisplayLabel: StrokeShadowLabel!
    var pointsDisplayLabel: GradientMaskLabel!
    
    // 时间相关
    private var isAllDay: Bool = false
    private var selectedTimePoint: Date?
    private var selectedStartTime: Date?
    private var selectedEndTime: Date?
    
    // 分数相关
    private var selectedPointValue: Int?
    
    // 分配对象相关
    //    private var selectedAssignTarget: String?
    private var selectedAssignIndex: Int?
    private var assignStatusImageView: UIImageView!
    /// 当前 Assign 状态栏要显示的用户 UUID，异步头像回调只在该 UUID 仍匹配时更新，避免两个用户头像重叠
    private var assignStatusExpectedUUID: String?
    
    // 日期相关
    var selectedDate: Date? = nil

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private let timeFormatterWithAMPM: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a" // 12小时制 + AM/PM
        formatter.locale = Locale(identifier: "en_US_POSIX") // 强制英文，避免本地化
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    override init() {
        super.init()
        setupUI()
        setupKeyboardRasterizeObservers()
    }
    
    /// 键盘弹起时对 backView 光栅化，减轻渐变/阴影重绘对第三方键盘的 GPU 争抢
    private func setupKeyboardRasterizeObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.backView.window != nil else { return }
            self.backView.layer.shouldRasterize = true
            self.backView.layer.rasterizationScale = UIScreen.main.scale
        }
        nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            self?.backView.layer.shouldRasterize = false
        }
    }
    
    private func setupUI() {
        backView = ViewGradientView()
        backView.layer.cornerRadius = 24
        backView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backView.clipsToBounds = true
        backView.backgroundColor = .white
        
//        let gradientView = ViewGradientView()
        let gradientView = UIView()
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
        titleLabel.text = "New Task"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        textFiledView = BorderGradientView()
//        textFiledView.backgroundColor = .color(hexString: "#F8F8FC")
        textFiledView.layer.cornerRadius = 18
        backView.addSubview(textFiledView)
        
        textFiledView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(closeButton.snp.bottom).offset(19)
            make.width.equalToSuperview().multipliedBy(337.0 / 375.0)
            make.height.equalTo(115)
        }
        
        titleTextFiled = UITextField()
        titleTextFiled.attributedPlaceholder = NSAttributedString(string: "What needs to be done?", attributes: [.foregroundColor : UIColor.color(hexString: "#CACACA")])
        titleTextFiled.layer.cornerRadius = 18
        titleTextFiled.backgroundColor = .clear
        titleTextFiled.keyboardType = .default
        titleTextFiled.returnKeyType = .done
        // ✅ 必须设置 delegate，系统键盘右下角「对勾/完成」才会走 textFieldShouldReturn；否则只换行或不收键盘
        titleTextFiled.delegate = self
        titleTextFiled.enablesReturnKeyAutomatically = false
        titleTextFiled.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleTextFiled.textColor = .color(hexString: "#322D3A")
//        titleTextFiled.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        textFiledView.addSubview(titleTextFiled)
        
        titleTextFiled.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(42.0 / 115.0)
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
        notesTextView.layer.cornerRadius = 18
        notesTextView.backgroundColor = .clear
        notesTextView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        notesTextView.text = ""
        notesTextView.textColor = .color(hexString: "#999DAB")
        notesTextView.font = UIFont(name: "SFCompactRounded-Medium", size: 15)
        notesTextView.delegate = self
        notesTextView.isEditable = true
        notesTextView.isUserInteractionEnabled = true
        notesTextView.textContainerInset = .zero
        notesTextView.textContainer.lineFragmentPadding = 0
        notesTextView.returnKeyType = .done
        textFiledView.addSubview(notesTextView)
        notesTextView.snp.makeConstraints { make in
            make.top.equalTo(textFiledLine.snp.bottom).offset(11)
            make.left.equalTo(15)
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        notesPlaceholderLabel = UILabel()
        notesPlaceholderLabel.text = "Add a note…"
        notesPlaceholderLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 15)
        notesPlaceholderLabel.textColor = .color(hexString: "#CACACA")
        notesPlaceholderLabel.isUserInteractionEnabled = false
        textFiledView.addSubview(notesPlaceholderLabel)
        notesPlaceholderLabel.snp.makeConstraints { make in
            make.top.left.equalTo(notesTextView)
        }
        
        titleTextFiled.inputAccessoryView = nil
        notesTextView.inputAccessoryView = nil
        // 关闭两个输入框原本的点击弹出键盘，仅能通过下方两个 trigger view 点击唤起
        titleTextFiled.isUserInteractionEnabled = false
        notesTextView.isUserInteractionEnabled = false
        
        // 两个点击才唤起键盘的遮罩
        titleInputTriggerView = UIView()
        titleInputTriggerView.backgroundColor = .clear
        titleInputTriggerView.isUserInteractionEnabled = true
        textFiledView.addSubview(titleInputTriggerView)
        titleInputTriggerView.snp.makeConstraints { make in
            make.edges.equalTo(titleTextFiled)
        }
        let titleTap = UITapGestureRecognizer(target: self, action: #selector(onTitleTriggerTapped))
        titleInputTriggerView.addGestureRecognizer(titleTap)
        
        notesInputTriggerView = UIView()
        notesInputTriggerView.backgroundColor = .clear
        notesInputTriggerView.isUserInteractionEnabled = true
        textFiledView.addSubview(notesInputTriggerView)
        notesInputTriggerView.snp.makeConstraints { make in
            make.edges.equalTo(notesTextView)
        }
        let notesTap = UITapGestureRecognizer(target: self, action: #selector(onNotesTriggerTapped))
        notesInputTriggerView.addGestureRecognizer(notesTap)
        
        dataView = BorderGradientView()
        dataView.layer.cornerRadius = 18
        backView.addSubview(dataView)
        
        dataView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(textFiledView.snp.bottom).offset(16)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(104)
        }
        
        let dataViewLine = UIView()
        dataViewLine.backgroundColor = .color(hexString: "#484848").withAlphaComponent(0.05)
        dataView.addSubview(dataViewLine)
        
        dataViewLine.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(307.0 / 335.0)
            make.height.equalTo(1)
            make.center.equalToSuperview()
        }
        
        dateButton = UIButton()
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
            datePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
        }
        dataView.addSubview(dateButton)
        
        dateButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalToSuperview().dividedBy(2)
            make.width.equalToSuperview()
        }
        
        let dateButtondown = UIImageView(image: .adddown)
        dateButton.addSubview(dateButtondown)
        
        dateButtondown.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
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
        
        let dataImage = UIImageView(image: .dateimage)
        dateButton.addSubview(dataImage)
        
        dataImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        
        let dataLabel = UILabel()
        dataLabel.text = "Day"
        dataLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        dataLabel.textColor = .color(hexString: "#322D3A")
        dateButton.addSubview(dataLabel)
        
        dataLabel.snp.makeConstraints { make in
            make.left.equalTo(dataImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        timeButton = UIButton()
        timeButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.backView.endEditing(true)
            let timePopup = TimePopup()
            timePopup.onTimeSelected = { [weak self] isAllDay, timePoint, startTime, endTime in
                guard let self = self else { return }
                self.isAllDay = isAllDay
                self.selectedTimePoint = timePoint
                self.selectedStartTime = startTime
                self.selectedEndTime = endTime
                
                // MARK: 1. 选择时间时显示 AM/PM
                if isAllDay {
                    self.timeDisplayLabel.text = "All Day"
                } else if let timePoint = timePoint {
                    self.timeDisplayLabel.text = self.timeFormatterWithAMPM.string(from: timePoint)
                } else if let startTime = startTime, let endTime = endTime {
                    let startText = self.timeFormatterWithAMPM.string(from: startTime)
                    let endText = self.timeFormatterWithAMPM.string(from: endTime)
                    self.timeDisplayLabel.text = "\(startText) - \(endText)"
                }
                
                timePopup.popup.dismiss(animated: true)
            }
            timePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
        }
        dataView.addSubview(timeButton)
        
        timeButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.height.equalToSuperview().dividedBy(2)
            make.width.equalToSuperview()
        }
        
        let timeButtondown = UIImageView(image: .adddown)
        timeButton.addSubview(timeButtondown)
        
        timeButtondown.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
        }
        
        let timeImage = UIImageView(image: .timeimage)
        timeButton.addSubview(timeImage)
        
        timeImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        
        let timeLabel = UILabel()
        timeLabel.text = "Time"
        timeLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        timeLabel.textColor = .color(hexString: "#322D3A")
        timeButton.addSubview(timeLabel)
        
        timeLabel.snp.makeConstraints { make in
            make.left.equalTo(timeImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        timeDisplayLabel = UILabel()
        timeDisplayLabel.isUserInteractionEnabled = false
        timeDisplayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        timeDisplayLabel.textColor = .color(hexString: "#999DAB")
        //        timeDisplayLabel.text = "Select Time" // 初始提示文本
        timeButton.addSubview(timeDisplayLabel)
        
        timeDisplayLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(timeButtondown.snp.left).offset(-8)
        }
        
        reminderView = BorderGradientView()
        reminderView.layer.cornerRadius = 18
        backView.addSubview(reminderView)
        
        reminderView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(52)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(dataView.snp.bottom).offset(16)
        }
        
        switchView = UISwitch()
        switchView.onTintColor = .color(hexString: "#5DCF51")
        switchView.addTarget(self, action: #selector(switchViewChanged(_:)), for: .valueChanged)
        // ✅ 缩小 switch 按钮（缩放为原来的 0.75 倍）
        switchView.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        reminderView.addSubview(switchView)
        
        switchView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
        }
        
        let remiImage = UIImageView(image: .reminderimage)
        reminderView.addSubview(remiImage)
        
        remiImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        let remiLabel = UILabel()
        remiLabel.text = "Reminder"
        remiLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        remiLabel.textColor = .color(hexString: "#322D3A")
        reminderView.addSubview(remiLabel)
        
        remiLabel.snp.makeConstraints { make in
            make.left.equalTo(remiImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
//        pointsButton = BorderGradientButton()
//        pointsButton.layer.cornerRadius = 18
//        pointsButton.reactive.controlEvents(.touchUpInside).observeValues {
//            [weak self] _ in
//            guard let self = self else { return }
//            let pointsPopup = PointsPopup()
//            pointsPopup.onPointselected = { [weak self] selectedPoints in
//                guard let self = self else { return }
//                self.selectedPointValue = Int(selectedPoints)
//                self.underunderpointsDisplayLabel.text = "\(selectedPoints)"
//                self.underpointsDisplayLabel.text = "\(selectedPoints)"
//                self.pointsDisplayLabel.text = "\(selectedPoints)"
//                self.pointsDisplayLabel.text = "\(selectedPoints)"
//                self.pointsDisplayLabel.isHidden = false
//                self.underunderpointsDisplayLabel.isHidden = false
//                self.underpointsDisplayLabel.isHidden = false
//                pointsPopup.popup.dismiss(animated: true)
//            }
//            pointsPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
//        }
//        backView.addSubview(pointsButton)
        
//        pointsButton.snp.makeConstraints { make in
//            make.centerX.equalToSuperview()
//            make.height.equalTo(52)
//            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
//            make.top.equalTo(reminderView.snp.bottom).offset(16)
//        }
        
//        let pointsButtondown = UIImageView(image: .adddown)
//        pointsButton.addSubview(pointsButtondown)
//        
//        pointsButtondown.snp.makeConstraints { make in
//            make.centerY.equalToSuperview()
//            make.right.equalTo(-14)
//        }
//        
//        let pointsImage = UIImageView(image: .coin)
//        pointsButton.addSubview(pointsImage)
//        
//        pointsImage.snp.makeConstraints { make in
//            make.centerY.equalToSuperview()
//            make.left.equalTo(14)
//        }
        
        
//        underunderpointsDisplayLabel = StrokeShadowLabel()
//        underunderpointsDisplayLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
//        underunderpointsDisplayLabel.shadowOffset = CGSize(width: 0, height: 1)
//        underunderpointsDisplayLabel.shadowBlurRadius = 2.0
//        underunderpointsDisplayLabel.text = "100"
//        underunderpointsDisplayLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)!
//        pointsButton.addSubview(underunderpointsDisplayLabel)
//        
//        underunderpointsDisplayLabel.snp.makeConstraints { make in
//            make.centerY.equalToSuperview()
//            make.right.equalTo(pointsButtondown.snp.left)
//        }
//        
//        underpointsDisplayLabel = StrokeShadowLabel()
//        underpointsDisplayLabel.shadowColor = UIColor.black.withAlphaComponent(0.03)
//        underunderpointsDisplayLabel.text = "100"
//        underpointsDisplayLabel.shadowOffset = CGSize(width: 0, height: 1)
//        underpointsDisplayLabel.shadowBlurRadius = 4.0
//        underpointsDisplayLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)!
//        pointsButton.addSubview(underpointsDisplayLabel)
//        
//        underpointsDisplayLabel.snp.makeConstraints { make in
//            make.center.equalTo(underunderpointsDisplayLabel)
//        }
//        
//        
//        pointsDisplayLabel = GradientMaskLabel()
//        pointsDisplayLabel.isUserInteractionEnabled = false
//        pointsDisplayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)!
//        pointsDisplayLabel.gradientStartColor = .color(hexString: "#FFC251")
//        pointsDisplayLabel.gradientEndColor = .color(hexString: "#FF7738")
//        pointsDisplayLabel.gradientDirection = (start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1))
//        pointsButton.addSubview(pointsDisplayLabel)
//        pointsDisplayLabel.snp.makeConstraints { make in
//            make.center.equalTo(underunderpointsDisplayLabel)
//        }
        
//        let pointsLabel = UILabel()
//        pointsLabel.text = "Points"
//        pointsLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
//        pointsLabel.textColor = .color(hexString: "#322D3A")
//        pointsButton.addSubview(pointsLabel)
//        
//        pointsLabel.snp.makeConstraints { make in
//            make.left.equalTo(pointsImage.snp.right).offset(3)
//            make.centerY.equalToSuperview()
//        }
        
        assignButton = BorderGradientButton()
        assignButton.layer.cornerRadius = 18
        assignButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            let assignPopup = AssignPopup()
            assignPopup.assignselected = { [weak self] index in
                guard let self = self else { return }
                self.selectedAssignIndex = index
                self.updateAssignStatusImage(index: index)
                assignPopup.popup.dismiss(animated: true)
            }
            assignPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
        }
        backView.addSubview(assignButton)
        
        assignButton.snp.makeConstraints { make in
//            make.centerX.equalToSuperview()
//            make.height.equalTo(52)
//            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
//            make.top.equalTo(pointsButton.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.height.equalTo(52)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(reminderView.snp.bottom).offset(16)
        }
        
        let assignButtondown = UIImageView(image: .adddown)
        assignButton.addSubview(assignButtondown)
        
        assignButtondown.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-14)
        }
        
        let assignImage = UIImageView(image: .assignimage)
        assignButton.addSubview(assignImage)
        
        assignImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(14)
        }
        let assignLabel = UILabel()
        assignLabel.text = "Assign To"
        assignLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        assignLabel.textColor = .color(hexString: "#322D3A")
        assignButton.addSubview(assignLabel)
        
        assignLabel.snp.makeConstraints { make in
            make.left.equalTo(assignImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
        }
        
        assignStatusImageView = UIImageView()
        assignStatusImageView.isUserInteractionEnabled = false
        assignStatusImageView.contentMode = .scaleAspectFit
        assignStatusImageView.isHidden = true
        assignButton.addSubview(assignStatusImageView)
        assignStatusImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(assignButtondown.snp.left).offset(-8)
            make.size.equalTo(addSingleAvatarSize)
        }
        
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.layer.borderWidth = 1
        continueButton.setTitle("Create Task", for: .normal)
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
        
        updateDateButtonTitle()
        
        popup = WavesPopup(contentView: backView,
                           showType: .slideInFromBottom,
                           dismissType: .slideOutToBottom,
                           maskType: .dimmed,
                           dismissOnBackgroundTouch: true,
                           dismissOnContentTouch: false,
                           dismissPanView: hintView)
    }
    
    /// 添加弹窗头像：单人/双方分开布局（与 DetailedViewController、EditViewPopup 一致）
    private let addSingleAvatarSize: CGFloat = 30
    private let addCombinedAvatarSize: CGFloat = 60
    
    /// 根据用户性别返回默认头像图名（指定用户为默认头像时按性别显示）
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }
    
    /// 默认头像不显示阴影：移除阴影 sublayer 并关闭主 layer 阴影，避免与旧自定义头像重叠
    private func clearAssignStatusAvatarShadow() {
        guard let iv = assignStatusImageView else { return }
        iv.layer.shadowOpacity = 0
        if let sub = iv.layer.sublayers?.first(where: { $0.name == "avatarShadowSecondLayer" }) {
            sub.removeFromSuperlayer()
        } else if let first = iv.layer.sublayers?.first {
            first.removeFromSuperlayer()
        }
    }

    /// 只能指定一个用户，仅显示单人头像；选谁就只显示谁，避免两个用户头像重叠
    private func updateAssignStatusImage(index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.applyAssignStatusPlaceholderOnly(index: index)
            let currentUUID = CoupleStatusManager.getUserUniqueUUID()
            let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
            let partnerUUID = partnerUser?.id ?? ""
            let displayIndex = (index == TaskAssignIndex.both.rawValue) ? TaskAssignIndex.partner.rawValue : index
            
            switch displayIndex {
            case TaskAssignIndex.myself.rawValue:
                self.assignStatusExpectedUUID = currentUUID
                let defaultName = self.defaultImageName(forGender: currentUser?.gender)
                self.loadAvatarForUser(uuid: currentUUID, defaultImage: UIImage(named: defaultName), imageView: self.assignStatusImageView)
            case TaskAssignIndex.partner.rawValue:
                self.assignStatusExpectedUUID = partnerUUID.isEmpty ? nil : partnerUUID
                if !partnerUUID.isEmpty {
                    let defaultName = self.defaultImageName(forGender: partnerUser?.gender)
                    self.loadAvatarForUser(uuid: partnerUUID, defaultImage: UIImage(named: defaultName), imageView: self.assignStatusImageView)
                }
            default:
                break
            }
        }
    }
    
    /// 仅更新占位图与显示状态，不触发抠图（用于键盘可见时或与 updateAssignStatusImage 共用前半段）
    private func applyAssignStatusPlaceholderOnly(index: Int) {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        let displayIndex = (index == TaskAssignIndex.both.rawValue) ? TaskAssignIndex.partner.rawValue : index
        
        assignStatusImageView.snp.updateConstraints { make in
            make.size.equalTo(addSingleAvatarSize)
        }
        assignStatusImageView.clipsToBounds = true
        
        switch displayIndex {
        case TaskAssignIndex.myself.rawValue:
            assignStatusExpectedUUID = currentUUID
            assignStatusImageView.image = UIImage(named: defaultImageName(forGender: currentUser?.gender))
            clearAssignStatusAvatarShadow()
            assignStatusImageView.isHidden = false
        case TaskAssignIndex.partner.rawValue:
            assignStatusExpectedUUID = partnerUUID.isEmpty ? nil : partnerUUID
            assignStatusImageView.image = UIImage(named: defaultImageName(forGender: partnerUser?.gender))
            clearAssignStatusAvatarShadow()
            assignStatusImageView.isHidden = false
        default:
            assignStatusExpectedUUID = nil
            assignStatusImageView.isHidden = true
        }
    }
    
    // ✅ 不读/不写缓存，按 addSingleAvatarSize 抠图；仅当仍是当前要显示的用户时才应用结果，避免两个用户头像重叠
    // ✅ Base64 解码与抠图均在后台执行，避免主线程阻塞导致第三方键盘卡顿
    private func loadAvatarForUser(uuid: String, defaultImage: UIImage?, imageView: UIImageView) {
        imageView.image = defaultImage
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 0
        let userModel = UserManger.manager.getUserModelByUUID(uuid)
        let avatarString = userModel?.avatarImageURL ?? ""
        guard !avatarString.isEmpty else { return }
        let expectedUUID = uuid
        let outputSize = CGSize(width: addSingleAvatarSize, height: addSingleAvatarSize)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let image = self.imageFromBase64String(avatarString) else { return }
            ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 8, outputSize: outputSize, cacheKey: avatarString) { [weak self, weak imageView] processed in
                let final = processed ?? image
                DispatchQueue.main.async {
                    guard let self = self, let imageView = imageView else { return }
                    if self.assignStatusExpectedUUID != expectedUUID { return }
                    imageView.image = final
                    imageView.contentMode = .scaleAspectFit
                    imageView.clipsToBounds = false
                    imageView.applyAvatarCutoutShadow()
                }
            }
        }
    }
    
    // ✅ 不读缓存，按 addCombinedAvatarSize 抠图+组合；Base64 解码在后台执行，减轻主线程压力
    private func loadCombinedAvatar(myUUID: String, partnerUUID: String, imageView: UIImageView) {
        imageView.image = UIImage(named: "wwwww")
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.layer.cornerRadius = 0
        var myAvatarStr = ""; var partnerAvatarStr = ""
        if let s = UserManger.manager.getUserModelByUUID(myUUID)?.avatarImageURL { myAvatarStr = s }
        if let s = UserManger.manager.getUserModelByUUID(partnerUUID)?.avatarImageURL { partnerAvatarStr = s }
        let size = addCombinedAvatarSize
        let cutoutSize = CGSize(width: size, height: size)
        let combineSize = CGSize(width: size, height: size)
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
                imageView.image = combined
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = false
                imageView.applyAvatarCutoutShadow()
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
    
    private func updateDateButtonTitle() {
        let dateText: String
        
        if let date = selectedDate {
            // 如果选中了日期，显示选中的日期
            dateText = dateFormatter.string(from: date)
            dateDisplayLabel.text = dateText
        } else {
            dateText = "Today"
        }
    }
    
    /// dismissKeyboard 为 false 时由 show 使用，由 presenter 先 endEditing，减轻第三方键盘卡顿
    private func resetInputFields(dismissKeyboard: Bool = true) {
        titleTextFiled.text = nil
        notesTextView.text = ""
        notesTextView.textColor = .color(hexString: "#999DAB")
        updateNotesPlaceholderVisibility()
        titleInputTriggerView?.isHidden = false
        notesInputTriggerView?.isHidden = false
        titleTextFiled.isUserInteractionEnabled = false
        notesTextView.isUserInteractionEnabled = false
        
        // 2. 日期时间类重置
        selectedDate = nil // 清空选中日期
        dateDisplayLabel.text = nil
        dateDisplayLabel.textColor = .color(hexString: "#999DAB") // 恢复提示色
        
        timeDisplayLabel.text = nil
        timeDisplayLabel.textColor = .color(hexString: "#999DAB") // 恢复提示色
        isAllDay = false
        selectedTimePoint = nil
        selectedStartTime = nil
        selectedEndTime = nil
        
        // 3. 分数相关重置
//        selectedPointValue = nil
//        underunderpointsDisplayLabel.isHidden = true
//        underpointsDisplayLabel.isHidden = true
//        pointsDisplayLabel.isHidden = true // 隐藏分数显示
        
        
        // 4. 分配对象相关重置
        selectedAssignIndex = nil
        assignStatusExpectedUUID = nil
        assignStatusImageView.image = nil
        assignStatusImageView.isHidden = true // 隐藏选中图片
        
        // 5. 提醒状态重置
        switchView.isOn = false
        
        if dismissKeyboard {
            forceDismissKeyboardForPopup()
        }
    }
    
    private func updateNotesPlaceholderVisibility() {
        notesPlaceholderLabel?.isHidden = !(notesTextView.text?.isEmpty ?? true)
    }
    
    @objc func handleContinueButton() {
        print("🔍 Continue 按钮被点击，开始校验数据")
        
        // ========== 前置校验必填项：未输入标题时弹窗提醒 ==========
        guard let title = titleTextFiled.text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AlertManager.showSingleButtonAlert(message: "Please enter a title", target: self)
            return
        }
        let notes = (notesTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        
        let taskDate = selectedDate ?? Date()
//        guard let points = selectedPointValue, points > 0 else {
//            let pointsPopup = PointsPopup()
//            pointsPopup.onPointselected = { [weak self] selectedPoints in
//                guard let self = self else { return }
//                self.selectedPointValue = Int(selectedPoints)
//                self.underunderpointsDisplayLabel.text = "\(selectedPoints)"
//                self.underpointsDisplayLabel.text = "\(selectedPoints)"
//                self.pointsDisplayLabel.text = "\(selectedPoints)"
//                self.pointsDisplayLabel.text = "\(selectedPoints)"
//                self.pointsDisplayLabel.isHidden = false
//                self.underunderpointsDisplayLabel.isHidden = false
//                self.underpointsDisplayLabel.isHidden = false
//                pointsPopup.popup.dismiss(animated: true)
//            }
//            pointsPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing)
//            return
//        }
        // 未选择 Assign 时弹窗提醒
        guard let assignIndex = selectedAssignIndex,
              (assignIndex.isMyself || assignIndex.isPartner || assignIndex.isBoth) else {
            AlertManager.showSingleButtonAlert(message: "Please select Assign", target: self)
            return
        }
        let isReminderOn = switchView.isOn
        
        let calendar = Calendar.current
        let baseDate = selectedDate ?? Date()
        let targetTime = selectedTimePoint ?? Date()
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: targetTime)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        let finalTaskDateTime = calendar.date(from: dateComponents) ?? Date()
        
        var timeString = ""
        if isAllDay {
            timeString = "All Day"
        } else if let timePoint = selectedTimePoint {
            timeString = self.timeFormatterWithAMPM.string(from: timePoint)
        } else if let startTime = selectedStartTime, let endTime = selectedEndTime {
            let startText = self.timeFormatterWithAMPM.string(from: startTime)
            let endText = self.timeFormatterWithAMPM.string(from: endTime)
            timeString = "\(startText) - \(endText)"
        } else {
            timeString = self.timeFormatterWithAMPM.string(from: Date())
        }
        
        if let homeVC = self.homeViewController {
            if isReminderOn {
                self.submitTaskToHomeVC(homeVC: homeVC, title: title, notes: notes, finalTaskDateTime: finalTaskDateTime, timeString: timeString, isAllDay: self.isAllDay, points: 1, assignIndex: assignIndex, isReminderOn: true)
            } else {
                self.submitTaskToHomeVC(homeVC: homeVC, title: title, notes: notes, finalTaskDateTime: finalTaskDateTime, timeString: timeString, isAllDay: isAllDay, points: 1, assignIndex: assignIndex, isReminderOn: false)
            }
        } else {
            // 兜底：TabBar 未注入 homeVC 时直接写 Core Data，保证能保存
            _ = DbManager.manager.addModel(
                titleLabel: title,
                notesLabel: notes,
                taskDate: finalTaskDateTime,
                timeString: timeString,
                isAllDay: isAllDay,
                points: 1,
                assignIndex: assignIndex,
                isReminderOn: isReminderOn
            )
            self.resetInputFields()
            self.popup.dismiss(animated: true)
        }
    }
    
    // ✅ 开关变化处理（与 AllowView 逻辑一致）
    @objc private func switchViewChanged(_ sender: UISwitch) {
        if sender.isOn {
            // ✅ 开关打开：检查系统权限，如果没有则请求
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .authorized {
                        // ✅ 已有权限，开关保持打开
                        print("✅ AddViewPopup: 系统已有通知权限")
                    } else {
                        // ✅ 没有权限，弹出系统权限请求
                        LocalNotificationManager.shared.requestNotificationPermission { granted in
                            if granted {
                                // ✅ 用户授权，开关保持打开
                                print("✅ AddViewPopup: 用户已授权通知权限")
                            } else {
                                // ✅ 用户拒绝权限，关闭开关
                                DispatchQueue.main.async {
                                    sender.isOn = false
                                    
                                    // ✅ 显示提示并引导到设置
                                    let alert = UIAlertController(
                                        title: "Notification Permission Denied",
                                        message: "Please enable notification permission in Settings to receive task reminders",
                                        preferredStyle: .alert
                                    )
                                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                    alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    })
                                    
                                    // ✅ 在当前的 view controller 上显示提示
                                    if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                                        rootVC.present(alert, animated: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // ✅ 开关关闭：不需要任何操作
            print("✅ AddViewPopup: 用户关闭了通知开关")
        }
    }
    
    // ✅ 抽离任务提交逻辑（复用）
    private func submitTaskToHomeVC(homeVC: HomeViewController, title: String, notes: String, finalTaskDateTime: Date, timeString: String, isAllDay: Bool, points: Int, assignIndex: Int, isReminderOn: Bool) {
        homeVC.addNewItem(
            title: title,
            notes: notes,
            taskDate: finalTaskDateTime,
            timeString: timeString,
            isAllDay: isAllDay,
            points: points,
            assignIndex: assignIndex,
            isReminderOn: isReminderOn
        )
        self.resetInputFields()
        self.popup.dismiss(animated: true)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if textView === notesTextView, text == "\n" {
            forceDismissKeyboardForPopup()
            return false
        }
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView === notesTextView {
            updateNotesPlaceholderVisibility()
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView === notesTextView {
            updateNotesPlaceholderVisibility()
            notesTextView.isUserInteractionEnabled = false
            notesInputTriggerView?.isHidden = false
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView === notesTextView {
            updateNotesPlaceholderVisibility()
        }
    }
    
    /// 弹窗在 FFPopup 的 window 里时，只打一次 endEditing，避免连续 resign×2 + endEditing×2 + sendAction 叠动画、像弹两次键盘。
    /// 顺序：优先弹窗所在 window 整块收键；无 window 时再 backView；仍不收则用 sendAction 兜底。
    private func forceDismissKeyboardForPopup() {
        if let w = backView.window {
            w.endEditing(true)
            return
        }
        backView.endEditing(true)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - UITextFieldDelegate（Title 完成键 / 系统键盘对勾）
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        forceDismissKeyboardForPopup()
        return true
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
    
    @objc private func onNotesTriggerTapped() {
        notesInputTriggerView.isHidden = true
        notesTextView.isUserInteractionEnabled = true
        notesTextView.becomeFirstResponder()
    }
    
    func show(width: CGFloat, bottomSpacing: CGFloat) {
        // 先 layout 再 show，reset 延后到下一 runloop，避免与弹窗动画、第三方键盘争抢主线程
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
        DispatchQueue.main.async { [weak self] in
            self?.resetInputFields(dismissKeyboard: false)
        }
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        let screenHeight = UIScreen.main.bounds.height
        let popupHeight = screenHeight * (695.0 / 812.0)
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: popupHeight)
        backView.layoutIfNeeded()
    }
}

