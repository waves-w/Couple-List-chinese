//
//  TimePopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class TimePopup: NSObject {
    var homeViewController2: HomeViewController!
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    private var isTimePointMode = true // 默认时间点模式
    var neverButton: BorderGradientButton!
    private var isNeverSelected: Bool = false
    let selectedImage = UIImage(named: "assignSelect")
    let unselectedImage = UIImage(named: "assignUnselect")
    var neverLabel: UILabel!
    
    var neverButtonImage: UIImageView!
    var timeSegmentSliderView = TimeSegmentSliderView()
    // 选择器相关
    private var timePointPicker: UIDatePicker! // 时间点选择器
    private var startTimePicker: UIDatePicker! // 开始时间选择器
    private var endTimePicker: UIDatePicker!   // 结束时间选择器
    private var pickerContainer: UIView!       // 选择器容器
    var continueButton: UIButton!
    var onTimeSelected: ((_ isAllDay: Bool, _ timePoint: Date?, _ startTime: Date?, _ endTime: Date?) -> Void)?
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
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
        titleLabel.text = "Choose a time"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15) ?? UIFont.boldSystemFont(ofSize: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        neverButton = BorderGradientButton()
        neverButton.layer.cornerRadius = 14
        neverButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.toggleNeverButton()
        }
        backView.addSubview(neverButton)
        
        neverButton.snp.makeConstraints { make in
            make.right.equalTo(-20)
            make.width.equalToSuperview().multipliedBy(83.0 / 375.0)
            make.height.equalTo(28)
            make.centerY.equalTo(closeButton)
        }
        
        let neverView = UIView()
        neverView.isUserInteractionEnabled = false
        neverView.backgroundColor = .color(hexString: "#322D3A").withAlphaComponent(0.03)
        neverButton.addSubview(neverView)
        
        neverView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        neverButtonImage = UIImageView(image: unselectedImage)
        neverView.addSubview(neverButtonImage)
        
        neverButtonImage.snp.makeConstraints { make in
            make.left.equalTo(6.5)
            make.centerY.equalToSuperview()
        }
        
        neverLabel = UILabel()
        neverLabel.text = "All day"
        neverLabel.textColor = .color(hexString: "#999DAB")
        neverLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        neverView.addSubview(neverLabel)
        
        neverLabel.snp.makeConstraints { make in
            make.left.equalTo(neverButtonImage.snp.right)
            make.centerY.equalToSuperview()
        }
        
        timeSegmentSliderView = TimeSegmentSliderView()
        timeSegmentSliderView.titles = ["Time" , "Scope"]
        timeSegmentSliderView.sliderColor = .color(hexString: "#FFFFFF")
        timeSegmentSliderView.selectedTextColor = .black
        timeSegmentSliderView.normalTextColor = .black
        timeSegmentSliderView.delegate = self
        timeSegmentSliderView.selectedIndex = 0
        backView.addSubview(timeSegmentSliderView)
        
        timeSegmentSliderView.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(36)
            make.centerX.equalToSuperview()
            make.top.equalTo(neverButton.snp.bottom).offset(20)
        }
        
        pickerContainer = UIView()
        backView.addSubview(pickerContainer)
        pickerContainer.snp.makeConstraints { make in
            make.top.equalTo(timeSegmentSliderView.snp.bottom).offset(17)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(202)
        }
        
        timePointPicker = UIDatePicker()
        timePointPicker.datePickerMode = .time
        timePointPicker.locale = Locale(identifier: "en_US")
        timePointPicker.preferredDatePickerStyle = .wheels
        pickerContainer.addSubview(timePointPicker)
        timePointPicker.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        startTimePicker = UIDatePicker()
        startTimePicker.datePickerMode = .time
        startTimePicker.locale = Locale(identifier: "en_US")
        startTimePicker.preferredDatePickerStyle = .wheels
        startTimePicker.isHidden = true
        pickerContainer.addSubview(startTimePicker)
        startTimePicker.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(pickerContainer.snp.height).dividedBy(2)
        }
        
        let dividerLine = UIView()
        dividerLine.backgroundColor = .color(hexString: "#E4E4E4")
        dividerLine.isHidden = true // 初始隐藏（时间点模式下不显示）
        pickerContainer.addSubview(dividerLine)
        dividerLine.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(1)
            make.centerY.equalToSuperview()
        }
        
        endTimePicker = UIDatePicker()
        endTimePicker.datePickerMode = .time
        endTimePicker.locale = Locale(identifier: "en_US")
        endTimePicker.preferredDatePickerStyle = .wheels
        endTimePicker.isHidden = true
        endTimePicker.date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        pickerContainer.addSubview(endTimePicker)
        endTimePicker.snp.makeConstraints { make in
            make.bottom.left.right.equalToSuperview()
            make.height.equalTo(pickerContainer.snp.height).dividedBy(2)
        }
        
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.layer.borderWidth = 1
        continueButton.setTitle("Done", for: .normal)
        continueButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        backView.addSubview(continueButton)
        
        continueButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottomMargin.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(56)
        }
        
        updateNeverButtonAppearance()
        
        popup = WavesPopup(contentView: backView,
                           showType: .slideInFromBottom,
                           dismissType: .slideOutToBottom,
                           maskType: .dimmed,
                           dismissOnBackgroundTouch: true,
                           dismissOnContentTouch: false,
                           dismissPanView: hintView)
    }
    
    @objc func toggleNeverButton() {
        // 切换状态
        isNeverSelected.toggle()
        
        // 关键逻辑：如果选中了 never，将时间重置
        if isNeverSelected {
            resetTimePickersToCurrent()
            // 选中 Never 后，禁用滚轮
            pickerContainer.isUserInteractionEnabled = false
            pickerContainer.alpha = 0.5
        } else {
            // 如果取消选中 Never，启用滚轮
            pickerContainer.isUserInteractionEnabled = true
            pickerContainer.alpha = 1.0
        }
        
        updateNeverButtonAppearance()
    }
    
    @objc private func continueButtonTapped() {
        if isNeverSelected {
            // 1. 选中「All day」模式
            onTimeSelected?(true, nil, nil, nil)
            print("Selected time: All Day")
        } else if isTimePointMode {
            // 2. 时间点模式
            let selectedTime = timePointPicker.date
            onTimeSelected?(false, selectedTime, nil, nil)
            print("Selected time point: \(timeFormatter.string(from: selectedTime))")
        } else {
            // 3. 时间段模式
            let startTime = startTimePicker.date
            let endTime = endTimePicker.date
            onTimeSelected?(false, nil, startTime, endTime)
            print("Selected time range: \(timeFormatter.string(from: startTime)) - \(timeFormatter.string(from: endTime))")
        }
        // 注意：这里不主动 dismiss，让调用方在回调中控制（和 DatePopup 一致）
    }
    
    private func resetTimePickersToCurrent() {
        let now = Date()
        let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        
        // 1. 重置时间点选择器
        timePointPicker.setDate(now, animated: true)
        
        // 2. 重置时间段选择器
        startTimePicker.setDate(now, animated: true)
        
        // 3. 重置结束时间选择器（默认比开始时间晚一小时）
        endTimePicker.setDate(oneHourLater, animated: true)
    }
    
    private func updateNeverButtonAppearance() {
        // 切换图片
        let image = isNeverSelected ? selectedImage : unselectedImage
        neverButtonImage.image = image
        neverLabel.textColor = isNeverSelected ? .color(hexString: "#322D3A") : .color(hexString: "#999DAB")
        
        // 切换背景颜色以提供视觉反馈
        let newAlpha: CGFloat = isNeverSelected ? 0.08 : 0.03
        neverButton.subviews.first?.backgroundColor = .color(hexString: "#322D3A").withAlphaComponent(newAlpha)
    }
    
    // Refactored method to update picker visibility based on segment index
    private func updatePickerVisibility(for index: Int) {
        // index 0: Time Point, index 1: Time Range
        let isTimePointMode = (index == 0)
        
        // Update internal state
        self.isTimePointMode = isTimePointMode
        
        // Find the divider line
        let dividerLine = pickerContainer.subviews.first(where: { $0.backgroundColor == .color(hexString: "#E4E4E4") })
        
        // 临时禁用手势，避免高度变化时误触发滑动关闭
        popup.setPanGestureEnabled(false)
        
        // 使用统一的高度计算方法
        let newHeight = calculateHeight()
        
        // 获取当前弹窗位置
        guard let containerView = popup.containerView,
              let backgroundView = containerView.superview else {
            // 如果无法获取容器视图，使用简单的动画
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                dividerLine?.isHidden = isTimePointMode
                self.timePointPicker.isHidden = !isTimePointMode
                self.startTimePicker.isHidden = isTimePointMode
                self.endTimePicker.isHidden = isTimePointMode
            } completion: { _ in
                self.popup.setPanGestureEnabled(true)
            }
            return
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            // 更新选择器显示状态
            dividerLine?.isHidden = isTimePointMode
            self.timePointPicker.isHidden = !isTimePointMode
            self.startTimePicker.isHidden = isTimePointMode
            self.endTimePicker.isHidden = isTimePointMode
            
            // 更新backView高度
            self.backView.bounds = CGRect(
                x: 0,
                y: 0,
                width: self.backView.width(),
                height: newHeight
            )
            
            // 更新containerView的高度和位置
            // 保持底部对齐，所以当高度增加时，Y坐标需要减少
            containerView.frame = CGRect(
                x: containerView.frame.origin.x,
                y: backgroundView.bounds.height - newHeight,
                width: containerView.frame.width,
                height: newHeight
            )
            
            // 强制布局更新
            self.backView.layoutIfNeeded()
        } completion: { _ in
            // 动画完成后重新启用手势
            self.popup.setPanGestureEnabled(true)
        }
    }
    
    // 确认选择
    @objc private func confirmTimeSelection() {
        if isTimePointMode {
            let selectedTime = timePointPicker.date
            print("Selected time point: \(selectedTime)")
            // 可在这里添加回调，将选择的时间传递给其他页面
        } else {
            let startTime = startTimePicker.date
            let endTime = endTimePicker.date
            print("Selected time range: \(startTime) ～ \(endTime)")
            // 可在这里添加回调，将选择的时间段传递给其他页面
        }
        popup.dismiss(animated: true)
    }
    
    // 计算弹窗高度（根据当前模式）
    private func calculateHeight() -> CGFloat {
        // Scope模式（时间段）需要更高的弹窗，比Time模式多160
        let extraHeight: CGFloat = isTimePointMode ? 100 : 100
        return pickerContainer.maxY() + extraHeight + bottomSpacing
    }
    
    /// 展示弹窗，可传入当前已选时间使弹窗内默认选中
    func show(width: CGFloat, bottomSpacing: CGFloat,
              initialIsAllDay: Bool? = nil,
              initialTimePoint: Date? = nil,
              initialStartTime: Date? = nil,
              initialEndTime: Date? = nil) {
        self.bottomSpacing = bottomSpacing
        
        // 应用初始选中状态（在 layout 前设置，以便高度正确）
        if let allDay = initialIsAllDay, allDay {
            isNeverSelected = true
            pickerContainer.isUserInteractionEnabled = false
            pickerContainer.alpha = 0.5
            updateNeverButtonAppearance()
        } else if let point = initialTimePoint {
            isNeverSelected = false
            isTimePointMode = true
            timeSegmentSliderView.selectedIndex = 0
            timePointPicker.setDate(point, animated: false)
            timePointPicker.isHidden = false
            startTimePicker.isHidden = true
            endTimePicker.isHidden = true
            pickerContainer.subviews.first(where: { $0.backgroundColor == .color(hexString: "#E4E4E4") })?.isHidden = true
            pickerContainer.isUserInteractionEnabled = true
            pickerContainer.alpha = 1.0
            updateNeverButtonAppearance()
        } else if let start = initialStartTime, let end = initialEndTime {
            isNeverSelected = false
            isTimePointMode = false
            timeSegmentSliderView.selectedIndex = 1
            startTimePicker.setDate(start, animated: false)
            endTimePicker.setDate(end, animated: false)
            timePointPicker.isHidden = true
            startTimePicker.isHidden = false
            endTimePicker.isHidden = false
            pickerContainer.subviews.first(where: { $0.backgroundColor == .color(hexString: "#E4E4E4") })?.isHidden = false
            pickerContainer.isUserInteractionEnabled = true
            pickerContainer.alpha = 1.0
            updateNeverButtonAppearance()
        }
        
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
        
        // 确保containerView的高度与backView一致（修复黑色区域问题）
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let containerView = self.popup.containerView else { return }
            let correctHeight = self.calculateHeight()
            containerView.frame = CGRect(
                x: containerView.frame.origin.x,
                y: containerView.frame.origin.y,
                width: containerView.frame.width,
                height: correctHeight
            )
        }
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutIfNeeded()
        
        // 使用统一的高度计算方法
        let height = calculateHeight()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: height)
    }
}

// MARK: - TimeSegmentSliderViewDelegate Implementation

extension TimePopup: TimeSegmentSliderViewDelegate {
    // This is the correct implementation matching the protocol
    func timeSegmentSliderView(_ view: TimeSegmentSliderView, didSelectSegmentAt index: Int) {
        // Call the new refactored method to switch the pickers
        updatePickerVisibility(for: index)
    }
}
