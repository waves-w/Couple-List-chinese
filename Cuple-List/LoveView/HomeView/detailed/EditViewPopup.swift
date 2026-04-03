//
//  EditViewPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup


class EditViewPopup: NSObject, UITextFieldDelegate, UITextViewDelegate {
    var homeViewController: HomeViewController!
    var backView: ViewGradientView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    var textFiledView: UIView!
    var titleTextFiled: UITextField!
    var notesTextView: UITextView!
    
    var dataView: UIView!
    var dateButton: UIButton!
    var timeButton: UIButton!
    
    var reminderView: UIView!
    var switchView: UISwitch!
    
    var pointsButton: UIButton!
    var assignButton: UIButton!
    var continueButton: UIButton!
    
    var dateDisplayLabel: UILabel!
    var timeDisplayLabel: UILabel!
    var pointsDisplayLabel: GradientMaskLabel!
    
    // 时间相关
    private var isAllDay: Bool = false
    private var selectedAssignIndex: Int? // 存储分配索引（1/2/3/0）
    private var assignStatusImageView: UIImageView! // 显示选中图片
    /// 当前 Assign 状态栏要显示的用户 UUID，异步头像回调只在该 UUID 仍匹配时更新，避免两个用户头像重叠
    private var assignStatusExpectedUUID: String?
    private var selectedTimePoint: Date?
    private var selectedStartTime: Date?
    private var selectedEndTime: Date?
    
    // 分数相关
    private var selectedPointValue: Int?
    
    // 分配对象相关
    private var selectedAssignTarget: String?
    
    
    // 日期相关
    var selectedDate: Date? = nil
    
    var editModel: ListModel!
    var onEditComplete: (() -> Void)?
    var onEditAndCloseComplete: (() -> Void)?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    override init() {
        super.init()
        setupUI()
    }
    
    private func setupUI() {
        backView = ViewGradientView()
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
        titleLabel.text = "Edit Task"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        textFiledView = BorderGradientView()
        textFiledView.layer.cornerRadius = 18
        backView.addSubview(textFiledView)
        
        textFiledView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(closeButton.snp.bottom).offset(20)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(117)
        }
        
        titleTextFiled = UITextField()
        titleTextFiled.attributedPlaceholder = NSAttributedString(string: "Title", attributes: [.foregroundColor : UIColor.color(hexString: "#CACACA")])
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
            make.height.equalToSuperview().multipliedBy(42.0 / 117.0)
        }
        
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
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
        notesTextView.text = "Notes"
        notesTextView.textColor = .color(hexString: "#CACACA")
        notesTextView.font = UIFont(name: "SFCompactRounded-Medium", size: 15)
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
            make.bottom.equalToSuperview()
        }
        
        titleTextFiled.inputAccessoryView = nil
        notesTextView.inputAccessoryView = nil
        
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
            
            // 2. 设置 onDateSelected 闭包
            datePopup.onDateSelected = { [weak self] selectedDate in
                self?.selectedDate = selectedDate
                self?.updateDateButtonTitle()
                datePopup.popup.dismiss(animated: true)
            }
            datePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing, initialDate: self.selectedDate)
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
        dateDisplayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
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
        dataLabel.text = "Date"
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
            let timePopup = TimePopup()
            timePopup.onTimeSelected = { [weak self] isAllDay, timePoint, startTime, endTime in
                guard let self = self else { return }
                if isAllDay {
                    self.timeDisplayLabel.text = "All Day"
                } else if let timePoint = timePoint {
                    self.timeDisplayLabel.text = self.timeFormatter.string(from: timePoint)
                } else if let startTime = startTime, let endTime = endTime {
                    let startText = self.timeFormatter.string(from: startTime)
                    let endText = self.timeFormatter.string(from: endTime)
                    self.timeDisplayLabel.text = "\(startText) - \(endText)"
                }
                timePopup.popup.dismiss(animated: true)
            }
            let parsed = parseTimeString(timeDisplayLabel.text)
            timePopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing,
                           initialIsAllDay: parsed.isAllDay,
                           initialTimePoint: parsed.timePoint,
                           initialStartTime: parsed.startTime,
                           initialEndTime: parsed.endTime)
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
        timeDisplayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
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
//                self.pointsDisplayLabel.text = "\(selectedPoints)"
//                self.pointsDisplayLabel.refresh()
//                pointsPopup.popup.dismiss(animated: true)
//            }
//            let initialPoints = selectedPointValue.map { "\($0)" }
//            pointsPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing, initialPoints: initialPoints)
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
//            make.centerY.equalToSuperview()
//            make.right.equalTo(pointsButtondown.snp.left).offset(-8)
//        }
//        
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
                let creatorIndex = self.creatorAssignIndex(displayIndex: index, taskId: self.editModel?.id)
                self.selectedAssignIndex = creatorIndex
                self.updateAssignStatusImage(index: index)
                assignPopup.popup.dismiss(animated: true)
            }
            let displayIndex = self.displayAssignIndexForCurrentViewer(assignIndex: self.selectedAssignIndex ?? -1, taskId: self.editModel?.id)
            let initialForPopup = (displayIndex == TaskAssignIndex.both.rawValue) ? TaskAssignIndex.partner.rawValue : (displayIndex >= 0 && displayIndex <= 1 ? displayIndex : nil)
            assignPopup.show(width: self.backView.width(), bottomSpacing: self.bottomSpacing, initialIndex: initialForPopup)
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
        assignLabel.text = "Assign"
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
        assignStatusImageView.isHidden = true // 初始隐藏
        assignButton.addSubview(assignStatusImageView)
        assignStatusImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(assignButtondown.snp.left).offset(-8)
            make.size.equalTo(editSingleAvatarSize)
        }
        assignStatusImageView.clipsToBounds = true
        
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
        
        updateDateButtonTitle()
        
        popup = WavesPopup(contentView: backView,
                           showType: .slideInFromBottom,
                           dismissType: .slideOutToBottom,
                           maskType: .dimmed,
                           dismissOnBackgroundTouch: true,
                           dismissOnContentTouch: false,
                           dismissPanView: hintView)
    }
    
    /// 编辑弹窗头像：与 AddViewPopup 一致，只能指定一个用户，仅单人布局，避免两个用户头像重叠
    private let editSingleAvatarSize: CGFloat = 30
    
    /// 根据用户性别返回默认头像图名（指定用户为默认头像时按性别显示）
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }
    
    /// 默认头像不显示阴影：移除所有阴影 sublayer，避免与旧自定义头像重叠（与 AddViewPopup 一致）
    private func clearAssignStatusAvatarShadow() {
        guard let iv = assignStatusImageView else { return }
        iv.layer.shadowOpacity = 0
        if let sub = iv.layer.sublayers?.first(where: { $0.name == "avatarShadowSecondLayer" }) {
            sub.removeFromSuperlayer()
        } else if let first = iv.layer.sublayers?.first {
            first.removeFromSuperlayer()
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
    
    /// 将当前查看者在弹窗里选的 0/1 转回创建者视角的 assignIndex（保存用）
    private func creatorAssignIndex(displayIndex: Int, taskId: String?) -> Int {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let creatorUUID = (taskId != nil ? DbManager.manager.getTaskCreatorUUID(taskId: taskId!) : nil) ?? currentUUID
        let isCurrentUserCreator = (creatorUUID == currentUUID)
        if isCurrentUserCreator { return displayIndex }
        if displayIndex == TaskAssignIndex.partner.rawValue { return TaskAssignIndex.myself.rawValue }
        if displayIndex == TaskAssignIndex.myself.rawValue { return TaskAssignIndex.partner.rawValue }
        return displayIndex
    }
    
    /// 与 AddViewPopup 一致：只能指定一个用户，仅显示单人头像；选谁就只显示谁，避免两个用户头像重叠。双方（index==2）时显示伴侣头像
    private func updateAssignStatusImage(index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
//            self.resetAssignStatusImageViewForUpdate()
            let currentUUID = CoupleStatusManager.getUserUniqueUUID()
            let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
            let partnerUUID = partnerUser?.id ?? ""
            let displayIndex = (index == TaskAssignIndex.both.rawValue) ? TaskAssignIndex.partner.rawValue : index
            
            self.assignStatusImageView.snp.updateConstraints { make in
                make.size.equalTo(self.editSingleAvatarSize)
            }
            self.assignStatusImageView.clipsToBounds = true
            
            switch displayIndex {
            case TaskAssignIndex.myself.rawValue:
                self.assignStatusExpectedUUID = currentUUID
                let defaultName = self.defaultImageName(forGender: currentUser?.gender)
                self.assignStatusImageView.image = UIImage(named: defaultName)
                self.clearAssignStatusAvatarShadow()
                self.assignStatusImageView.isHidden = false
                self.loadAvatarForUser(uuid: currentUUID, defaultImage: UIImage(named: defaultName), imageView: self.assignStatusImageView)
            case TaskAssignIndex.partner.rawValue:
                self.assignStatusExpectedUUID = partnerUUID.isEmpty ? nil : partnerUUID
                if !partnerUUID.isEmpty {
                    let defaultName = self.defaultImageName(forGender: partnerUser?.gender)
                    self.assignStatusImageView.image = UIImage(named: defaultName)
                    self.clearAssignStatusAvatarShadow()
                    self.loadAvatarForUser(uuid: partnerUUID, defaultImage: UIImage(named: defaultName), imageView: self.assignStatusImageView)
                } else {
                    self.assignStatusImageView.image = UIImage(named: self.defaultImageName(forGender: partnerUser?.gender))
                    self.clearAssignStatusAvatarShadow()
                }
                self.assignStatusImageView.isHidden = false
            default:
                self.assignStatusExpectedUUID = nil
                self.assignStatusImageView.isHidden = true
            }
        }
    }
    
    // ✅ 不读/不写缓存，按 editSingleAvatarSize 抠图；Base64 解码在后台，避免主线程阻塞第三方键盘
    private func loadAvatarForUser(uuid: String, defaultImage: UIImage?, imageView: UIImageView) {
        imageView.image = defaultImage
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 0
        let userModel = UserManger.manager.getUserModelByUUID(uuid)
        let avatarString = userModel?.avatarImageURL ?? ""
        guard !avatarString.isEmpty else { return }
        let expectedUUID = uuid
        let outputSize = CGSize(width: editSingleAvatarSize, height: editSingleAvatarSize)
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
    
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        guard !base64String.isEmpty, base64String.count < 2_000_000 else { return nil }
        var base64 = base64String
        if base64.hasPrefix("data:image/"), let range = base64.range(of: ",") { base64 = String(base64[range.upperBound...]) }
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters), imageData.count < 1_500_000 else { return nil }
        let image = UIImage(data: imageData)
        return (image != nil && image!.size.width > 0 && image!.size.height > 0) ? image : nil
    }
    
    private func resetInputFields() {
        // 1. 文本输入类重置
        titleTextFiled.text = nil
        notesTextView.text = "Notes"
        notesTextView.textColor = .color(hexString: "#CACACA") // 占位符颜色
        
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
        
        // 4. 分配对象相关重置
        selectedAssignIndex = nil
        assignStatusExpectedUUID = nil
        assignStatusImageView.isHidden = true // 隐藏选中图片
        
        // 5. 提醒状态重置
        switchView.isOn = false
        
        // 6. 关闭键盘（避免残留输入状态）
        titleTextFiled.resignFirstResponder()
        notesTextView.resignFirstResponder()
    }
    
    @objc private func dismissKeyboardFromToolbar() {
        forceDismissKeyboardForPopup()
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
    
    @objc func handleContinueButton() {
        print("🔍 Continue 按钮被点击，开始保存数据")
        
        // 1. 校验必填项：标题、日期
        guard let title = titleTextFiled.text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AlertManager.showSingleButtonAlert(message: "Please enter a title.", target: self)
            return
        }
        
        let notes = (notesTextView.text == "Notes" && notesTextView.textColor == .color(hexString: "#CACACA")) ? "" : (notesTextView.text ?? "")
        
        guard let baseDate = selectedDate else {
            AlertManager.showSingleButtonAlert(message: "Please select a date.", target: self)
            return
        }
        
        // 2. 时间：未选择时使用当前时间（与新增一致，避免因历史数据 "Select Time" 导致无法保存）
        var timeString = (timeDisplayLabel.text?.trimmingCharacters(in: .whitespaces) ?? "")
        var saveIsAllDay = isAllDay
        if timeString.isEmpty || timeString == "Select Time" {
            timeString = timeFormatter.string(from: Date())
            saveIsAllDay = false
        }
        
        // 2.1 与 AddViewPopup 一致：用「日期 + 时间」合成最终截止时间，避免只存当天 00:00 导致修改日期后仍显示逾期
        let taskDate: Date = buildFinalTaskDate(baseDate: baseDate, timeString: timeString, isAllDay: saveIsAllDay)
        
        // 3. 分配对象：未选择或无效时默认「给自己」（避免因历史数据导致无法保存）
        let assignIndex: Int
        if let idx = selectedAssignIndex, (idx.isMyself || idx.isPartner || idx.isBoth) {
            assignIndex = idx
        } else {
            assignIndex = TaskAssignIndex.myself.rawValue
        }
        
        // 4. 打包成更新字典
        let updatedData: [String: Any?] = [
            "titleLabel": title,
            "notesLabel": notes,
            "taskDate": taskDate,
            "timeString": timeString,
            "isAllDay": saveIsAllDay,
            "points": 1,
            "assignIndex": assignIndex,
            "isReminderOn": switchView.isOn
        ]
        
        // 3. 必须有要编辑的 model 和 id
        guard let modelToEdit = editModel else {
            AlertManager.showSingleButtonAlert(message: "Cannot save: task data is missing.", target: self)
            return
        }
        guard let itemId = modelToEdit.id, !itemId.isEmpty else {
            AlertManager.showSingleButtonAlert(message: "Cannot save: task ID is missing.", target: self)
            return
        }
        
        // 4. 调用更新，根据结果决定是否关闭弹窗
        DbManager.manager.updateItem(withId: itemId, updatedData: updatedData) { [weak self] success in
            guard let self = self else { return }
//            if success {
                self.popup.dismiss(animated: true)
                self.resetInputFields()
                self.onEditComplete?()
                self.onEditAndCloseComplete?()
//            } else {
//                AlertManager.showSingleButtonAlert(message: "Save failed. The task may have been deleted.", target: self)
//            }
        }
    }
    
    
    func configureUI(with model: ListModel) {
        self.editModel = model
        print("弹窗接收 model 成功，ID：\(model.id ?? "nil")")
        
        // 2. 加载标题和备注
        titleTextFiled.text = model.titleLabel ?? ""
        let notes = model.notesLabel ?? ""
        notesTextView.text = notes.isEmpty ? "Notes" : notes
        notesTextView.textColor = notes.isEmpty ? .color(hexString: "#CACACA") : .color(hexString: "#322D3A")
        
        // 3. 加载日期（同步 selectedDate 并更新标签显示）
        selectedDate = model.taskDate ?? Date()
        updateDateButtonTitle()
        
        // 4. 加载时间（同步 isAllDay 状态）
        timeDisplayLabel.text = model.timeString ?? "Select Time"
        isAllDay = model.isAllDay
        
//        // 5. 加载分数（同步 selectedPointValue 并更新标签）
//        selectedPointValue = Int(model.points)
//        pointsDisplayLabel.text = "\(model.points)"
//        pointsDisplayLabel.textColor = .color(hexString: "#322D3A")
        
        // 6. 加载分配对象（与 HomeCell 一致：assignIndex 相对创建者，显示时转为当前查看者视角）
        let index = Int(model.assignIndex)
        selectedAssignIndex = index
        let displayIndex = displayAssignIndexForCurrentViewer(assignIndex: index, taskId: model.id)
        if displayIndex == TaskAssignIndex.partner.rawValue || displayIndex == TaskAssignIndex.myself.rawValue || displayIndex == TaskAssignIndex.both.rawValue {
            updateAssignStatusImage(index: displayIndex)
        } else {
            assignStatusImageView.isHidden = true
        }
        
        // 7. 加载提醒状态
        switchView.isOn = model.isReminderOn
        
    }
    
    /// 与 AddViewPopup 一致：根据选中日期 + 时间文案合成最终截止时间；All Day 用当天 23:59:59，避免整天都算逾期
    private func buildFinalTaskDate(baseDate: Date, timeString: String, isAllDay: Bool) -> Date {
        let calendar = Calendar.current
        if isAllDay {
            return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: baseDate) ?? baseDate
        }
        let parsed = parseTimeString(timeString)
        let timeSource: Date
        if let point = parsed.timePoint {
            timeSource = point
        } else if let start = parsed.startTime {
            timeSource = start
        } else {
            timeSource = Date()
        }
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeSource)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        return calendar.date(from: dateComponents) ?? baseDate
    }
    
    /// 解析时间显示文案为弹窗所需参数（All Day / 单点 / 时间段）
    private func parseTimeString(_ text: String?) -> (isAllDay: Bool?, timePoint: Date?, startTime: Date?, endTime: Date?) {
        guard let s = text?.trimmingCharacters(in: .whitespaces), !s.isEmpty, s != "Select Time" else {
            return (nil, nil, nil, nil)
        }
        if s == "All Day" {
            return (true, nil, nil, nil)
        }
        if s.contains(" - ") {
            let parts = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let start = timeFormatter.date(from: parts[0]),
                  let end = timeFormatter.date(from: parts[1]) else {
                return (nil, nil, nil, nil)
            }
            return (false, nil, start, end)
        }
        if let point = timeFormatter.date(from: s) {
            return (false, point, nil, nil)
        }
        return (nil, nil, nil, nil)
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
    
    /// 键盘「完成」键对 TextView 会插换行；拦截换行并收键盘（与 AddViewPopup 一致）
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if textView === notesTextView, text == "\n" {
            forceDismissKeyboardForPopup()
            return false
        }
        return true
    }

    // 2. 当用户停止编辑（键盘隐藏）时调用
    func textViewDidEndEditing(_ textView: UITextView) {
        // 检查用户是否输入了内容
        if textView.text.isEmpty {
            textView.text = "Notes" // 恢复占位符文本
            textView.textColor = .color(hexString: "#CACACA") // 恢复占位符颜色
        }
    }

    // MARK: - UITextFieldDelegate（Title 完成键收起键盘，与 AddViewPopup 一致）
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        forceDismissKeyboardForPopup()
        return true
    }

    func show(width: CGFloat, bottomSpacing: CGFloat) {
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: assignButton.maxY() + 186 + bottomSpacing)
    }
}
