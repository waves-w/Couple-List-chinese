//
//  AdvancePopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class AdvancePopup: NSObject {
    //    var homeViewController2: HomeViewController!
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    private var isTimePointMode = true // 默认时间点模式（That day）
    var neverButton: BorderGradientButton!
    private var isNeverSelected: Bool = false
    let selectedImage = UIImage(named: "assignSelect")
    let unselectedImage = UIImage(named: "assignUnselect")
    var neverLabel: UILabel!
    
    var neverButtonImage: UIImageView!
    var timeSegmentSliderView = TimeSegmentSliderView()
    // 选择器相关 - 改造核心：替换为自定义UIPickerView
    private var timePointPicker: UIDatePicker! // That day模式：原有时间点选择器
    private var advancePicker: UIPickerView!   // In advance模式：自定义4列滚轮选择器
    private var pickerContainer: UIView!       // 选择器容器
    var continueButton: UIButton!
    
    // MARK: 新增：传递友好文本的回调闭包
    var onAdvanceSelected: ((_ isNever: Bool, _ timePointText: String?, _ advanceText: String?) -> Void)?
    
    // 提前时间选中值存储
    private var selectedAdvanceDay = 0
    private var selectedAdvanceHour = 1
    private var selectedAdvanceMinute = 0
    private var selectedAdvancePeriod = "AM"
    
    // 原始基础数据
    private let originalDayData: [String] = (0...99).map { String(format: "%02d", $0) } // 00-99
    private let originalHourData: [String] = (1...12).map { String(format: "%02d", $0) } // 01-12
    private let originalMinuteData: [String] = (0...59).map { String(format: "%02d", $0) } // 00-59
    private let originalPeriodData = ["AM", "PM"] // 上午/下午
    
    // 扩容后的数据源（用于PickerView显示，实现循环）
    private var dayData: [String]!
    private var hourData: [String]!
    private var minuteData: [String]!
    private var periodData: [String]!
    
    // 中间初始位置（扩容后的数据中间点）
    private let middleHourOffset: Int!
    private let middleMinuteOffset: Int!
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // 新增：优化时间显示格式（12小时制）
    private let displayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    override init() {
        // 初始化扩容数据源（前后各复制1份，形成3倍长度，实现无缝循环）
        hourData = originalHourData + originalHourData + originalHourData
        minuteData = originalMinuteData + originalMinuteData + originalMinuteData
        dayData = originalDayData
        periodData = originalPeriodData
        
        // 中间初始位置（指向第2份原始数据的起始位置）
        middleHourOffset = originalHourData.count
        middleMinuteOffset = originalMinuteData.count
        
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
        titleLabel.text = "Time"
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
            make.width.equalToSuperview().multipliedBy(120.0 / 375.0)
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
        neverLabel.text = "No reminder"
        neverLabel.textColor = .color(hexString: "#999DAB")
        neverLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        neverView.addSubview(neverLabel)
        
        neverLabel.snp.makeConstraints { make in
            make.left.equalTo(neverButtonImage.snp.right)
            make.centerY.equalToSuperview()
        }
        
        timeSegmentSliderView = TimeSegmentSliderView()
        timeSegmentSliderView.titles = ["That day" , "In advance"]
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
        
        // MARK: That day模式 - 原有时间点选择器
        timePointPicker = UIDatePicker()
        timePointPicker.datePickerMode = .time
        timePointPicker.locale = Locale(identifier: "en_US")
        timePointPicker.preferredDatePickerStyle = .wheels
        pickerContainer.addSubview(timePointPicker)
        timePointPicker.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // MARK: In advance模式 - 自定义4列滚轮选择器
        advancePicker = UIPickerView()
        advancePicker.delegate = self
        advancePicker.dataSource = self
        advancePicker.isHidden = true // 初始隐藏，默认显示That day模式
        pickerContainer.addSubview(advancePicker)
        advancePicker.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 初始化选中值（默认0天、1时、0分、AM），小时/分钟列选中中间扩容位置
        advancePicker.selectRow(0, inComponent: 0, animated: false)
        advancePicker.selectRow(middleHourOffset, inComponent: 1, animated: false)
        advancePicker.selectRow(middleMinuteOffset, inComponent: 2, animated: false)
        advancePicker.selectRow(0, inComponent: 3, animated: false)
        
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.layer.borderWidth = 1
        continueButton.setTitle("Continue", for: .normal)
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
            onAdvanceSelected?(true, nil, nil)
            print("Selected: No reminder")
        } else if isTimePointMode {
            // 2. That day模式 - 时间点
            let selectedTime = timePointPicker.date
            let timeText = displayTimeFormatter.string(from: selectedTime)
            onAdvanceSelected?(false, timeText, nil)
            print("Selected time point: \(timeText)")
        } else {
            var advanceText = ""
            if selectedAdvanceDay > 0 {
                advanceText += "\(selectedAdvanceDay) day\(selectedAdvanceDay > 1 ? "s" : "") "
            }
            advanceText += "\(selectedAdvanceHour):\(selectedAdvanceMinute),\(selectedAdvancePeriod)"
            onAdvanceSelected?(false, nil, advanceText)
            print("Selected in advance: \(advanceText)")
        }
        self.popup.dismiss(animated: true)
    }
    
    private func resetTimePickersToCurrent() {
        let now = Date()
        
        // 1. That day模式 - 重置时间点选择器
        timePointPicker.setDate(now, animated: true)
        
        // 2. In advance模式 - 重置自定义滚轮为默认值
        selectedAdvanceDay = 0
        selectedAdvanceHour = 1
        selectedAdvanceMinute = 0
        selectedAdvancePeriod = "AM"
        
        advancePicker.selectRow(0, inComponent: 0, animated: true)
        advancePicker.selectRow(middleHourOffset, inComponent: 1, animated: true)
        advancePicker.selectRow(middleMinuteOffset, inComponent: 2, animated: true)
        advancePicker.selectRow(0, inComponent: 3, animated: true)
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
        // index 0: That day（时间点）, index 1: In advance（自定义提前时间）
        let isTimePointMode = (index == 0)
        
        // Update internal state
        self.isTimePointMode = isTimePointMode
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            // 切换两个选择器的显示/隐藏
            self.timePointPicker.isHidden = !isTimePointMode
            self.advancePicker.isHidden = isTimePointMode
        }
    }
    
    /// 展示弹窗，可传入当前已选提醒文案使弹窗内默认选中（如 "No reminder" / "02:30 PM" / "2 days 01:30,PM"）
    func show(width: CGFloat, bottomSpacing: CGFloat, initialAdvanceText: String? = nil) {
        let raw = (initialAdvanceText ?? "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "Advance:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        if raw == "No reminder" {
            // 用户之前选过 No reminder，回显
            isNeverSelected = true
            pickerContainer.isUserInteractionEnabled = false
            pickerContainer.alpha = 0.5
            updateNeverButtonAppearance()
        } else if raw.isEmpty {
            // 一进来/未选过：不默认选中 No reminder，默认 That day + 当前时间
            isNeverSelected = false
            isTimePointMode = true
            timeSegmentSliderView.selectedIndex = 0
            timePointPicker.setDate(Date(), animated: false)
            timePointPicker.isHidden = false
            advancePicker.isHidden = true
            pickerContainer.isUserInteractionEnabled = true
            pickerContainer.alpha = 1.0
            updateNeverButtonAppearance()
        } else if let date = displayTimeFormatter.date(from: raw) {
            // That day 格式：hh:mm a
            isNeverSelected = false
            isTimePointMode = true
            timeSegmentSliderView.selectedIndex = 0
            timePointPicker.setDate(date, animated: false)
            timePointPicker.isHidden = false
            advancePicker.isHidden = true
            pickerContainer.isUserInteractionEnabled = true
            pickerContainer.alpha = 1.0
            updateNeverButtonAppearance()
        } else {
            // In advance 格式：X days HH:MM,AM/PM 或 HH:MM,AM/PM
            isNeverSelected = false
            isTimePointMode = false
            timeSegmentSliderView.selectedIndex = 1
            timePointPicker.isHidden = true
            advancePicker.isHidden = false
            pickerContainer.isUserInteractionEnabled = true
            pickerContainer.alpha = 1.0
            updateNeverButtonAppearance()
            var day = 0
            var timePart = raw
            let lower = raw.lowercased()
            if lower.contains("days") {
                let parts = raw.components(separatedBy: "days")
                if let firstPart = parts.first?.trimmingCharacters(in: .whitespaces),
                   let d = Int(firstPart.split(separator: " ").last.map(String.init) ?? "") {
                    day = d
                }
                timePart = parts.last?.trimmingCharacters(in: .whitespaces) ?? raw
            } else if lower.contains("day ") {
                let parts = raw.components(separatedBy: "day ")
                if let firstPart = parts.first?.trimmingCharacters(in: .whitespaces),
                   let d = Int(firstPart.split(separator: " ").last.map(String.init) ?? "") {
                    day = d
                }
                timePart = parts.last?.trimmingCharacters(in: .whitespaces) ?? raw
            }
            if timePart.contains(",") {
                let parts = timePart.split(separator: ",", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                let timeStr = parts[0]
                let periodStr = parts.count > 1 ? parts[1] : "AM"
                let timeComponents = timeStr.split(separator: ":").map { String($0) }
                let hour = timeComponents.first.flatMap { Int($0) } ?? 1
                let minute = timeComponents.count > 1 ? (Int(timeComponents[1]) ?? 0) : 0
                selectedAdvanceDay = min(max(day, 0), 99)
                selectedAdvanceHour = min(max(hour, 1), 12)
                selectedAdvanceMinute = min(max(minute, 0), 59)
                selectedAdvancePeriod = (periodStr.uppercased() == "PM") ? "PM" : "AM"
                let dayRow = selectedAdvanceDay
                let hourRow = middleHourOffset + (selectedAdvanceHour - 1)
                let minuteRow = middleMinuteOffset + selectedAdvanceMinute
                let periodRow = selectedAdvancePeriod == "AM" ? 0 : 1
                advancePicker.selectRow(dayRow, inComponent: 0, animated: false)
                advancePicker.selectRow(hourRow, inComponent: 1, animated: false)
                advancePicker.selectRow(minuteRow, inComponent: 2, animated: false)
                advancePicker.selectRow(periodRow, inComponent: 3, animated: false)
            }
        }
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutIfNeeded()
        
        // 修复width()不存在的问题，替换为bounds.width
        backView.bounds = CGRect(x: 0, y: 0, width: backView.bounds.width, height: pickerContainer.frame.maxY + 100 + bottomSpacing)
    }
    
    // 处理滚轮无缝循环（通用方法）
    private func handleSeamlessCycle(for component: Int, pickerView: UIPickerView) {
        switch component {
        case 1: // 小时列
            let currentRow = pickerView.selectedRow(inComponent: 1)
            let originalCount = originalHourData.count
            
            // 滚动到扩容后的数据左边界（第1份原始数据末尾）
            if currentRow < middleHourOffset {
                // 无动画切回中间对应位置，视觉无缝
                pickerView.selectRow(currentRow + originalCount, inComponent: 1, animated: false)
            }
            // 滚动到扩容后的数据右边界（第3份原始数据起始）
            else if currentRow >= middleHourOffset + originalCount {
                // 无动画切回中间对应位置，视觉无缝
                pickerView.selectRow(currentRow - originalCount, inComponent: 1, animated: false)
            }
            // 更新选中值（取原始数据对应的索引）
            let actualRow = (pickerView.selectedRow(inComponent: 1) - middleHourOffset) % originalCount
            selectedAdvanceHour = Int(originalHourData[actualRow]) ?? 1
            
        case 2: // 分钟列
            let currentRow = pickerView.selectedRow(inComponent: 2)
            let originalCount = originalMinuteData.count
            
            // 滚动到扩容后的数据左边界
            if currentRow < middleMinuteOffset {
                pickerView.selectRow(currentRow + originalCount, inComponent: 2, animated: false)
            }
            // 滚动到扩容后的数据右边界
            else if currentRow >= middleMinuteOffset + originalCount {
                pickerView.selectRow(currentRow - originalCount, inComponent: 2, animated: false)
            }
            // 更新选中值
            let actualRow = (pickerView.selectedRow(inComponent: 2) - middleMinuteOffset) % originalCount
            selectedAdvanceMinute = Int(originalMinuteData[actualRow]) ?? 0
            
        default:
            return
        }
    }
}

// MARK: - TimeSegmentSliderViewDelegate Implementation
extension AdvancePopup: TimeSegmentSliderViewDelegate {
    // This is the correct implementation matching the protocol
    func timeSegmentSliderView(_ view: TimeSegmentSliderView, didSelectSegmentAt index: Int) {
        // Call the new refactored method to switch the pickers
        updatePickerVisibility(for: index)
    }
}

// MARK: - UIPickerViewDataSource & UIPickerViewDelegate（自定义4列滚轮）
extension AdvancePopup: UIPickerViewDataSource, UIPickerViewDelegate, UIScrollViewDelegate {
    // 列数：4列（天、时、分、AM/PM）
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 4
    }
    
    // 每列的行数
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0: return dayData.count // 天：100行（00-99）
        case 1: return hourData.count // 小时：36行（3*12）
        case 2: return minuteData.count // 分钟：180行（3*60）
        case 3: return periodData.count // 时段：2行（AM/PM）
        default: return 0
        }
    }
    
    // 每列的显示内容
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch component {
        case 0: return dayData[row] + " day" // 显示“00 day”
        case 1:
            let actualRow = row % originalHourData.count
            return originalHourData[actualRow]
        case 2:
            let actualRow = row % originalMinuteData.count
            return originalMinuteData[actualRow]
        case 3: return periodData[row] // 显示“AM”/“PM”
        default: return nil
        }
    }
    
    // 选中某行后的回调（更新选中值）
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            selectedAdvanceDay = Int(dayData[row]) ?? 0
        case 1:
            selectedAdvanceHour = Int(hourData[row]) ?? 1
        case 2:
            selectedAdvanceMinute = Int(minuteData[row]) ?? 0
        case 3:
            selectedAdvancePeriod = periodData[row]
        default:
            break
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didEndScrollingAnimationForComponent component: Int) {
        // 覆盖自动滚动（代码触发的selectRow）
        handleSeamlessCycle(for: component, pickerView: pickerView)
    }
    
    // 监听用户手动拖动的滚动停止（核心：补全手动滚动的循环触发）
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // 确保是advancePicker的滚动
        guard scrollView === advancePicker else { return }
        
        // 遍历小时列和分钟列，检查是否需要循环
        [1, 2].forEach { component in
            handleSeamlessCycle(for: component, pickerView: advancePicker)
        }
    }
    
    // 可选：设置每列的宽度（按需调整）
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        switch component {
        case 0: return 80 // 天列宽度
        case 1: return 70 // 小时列宽度
        case 2: return 70 // 分钟列宽度
        case 3: return 60 // 时段列宽度
        default: return 60
        }
    }
    
    // 可选：设置文字样式
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        label.textAlignment = .center
        label.font = UIFont(name: "SFPro-Medium", size: 17) ?? UIFont.systemFont(ofSize: 17)
        label.textColor = .color(hexString: "#111111")
        
        switch component {
        case 0: label.text = dayData[row] + " day"
        case 1:
            let actualRow = row % originalHourData.count
            label.text = originalHourData[actualRow]
        case 2:
            let actualRow = row % originalMinuteData.count
            label.text = originalMinuteData[actualRow]
        case 3: label.text = periodData[row]
        default: label.text = nil
        }
        
        return label
    }
}
