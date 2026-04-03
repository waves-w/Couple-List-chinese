//
//  BirthdayDatePopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class BirthdayDatePopup: NSObject {
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    var datePicker: UIDatePicker!
    var continueButton: UIButton!
    var onDateSelected: ((Date) -> Void)?
    private var selectedDate: Date? // ✅ 保存选中的日期，避免自动重置
    
    override init() {
        super.init()
        setupUI()
    }
    
    private func setupUI() {
        backView = UIView()
        backView.backgroundColor = .white
        backView.layer.cornerRadius = 24
        backView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backView.clipsToBounds = true
        
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
        titleLabel.text = "Birthday"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        // ✅ 滚轮样式的日期选择器
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: "en_US")
        // ✅ 设置日期范围（可选：限制在合理范围内，比如1900年到今天）
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 1900
        components.month = 1
        components.day = 1
        if let minDate = calendar.date(from: components) {
            datePicker.minimumDate = minDate
        }
        datePicker.maximumDate = Date() // 不能选择未来的日期
        // ✅ 监听日期变化，保存选中的日期
        datePicker.addTarget(self, action: #selector(datePickerValueChanged(_:)), for: .valueChanged)
        backView.addSubview(datePicker)
        
        datePicker.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(216)
        }
        
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
            // ✅ 获取选中的日期（优先使用保存的日期，否则使用当前选择器的日期）
            let finalDate = self.selectedDate ?? self.datePicker.date
            self.onDateSelected?(finalDate)
            print("✅ BirthdayDatePopup: 选中日期：\(finalDate)")
            self.dismiss(animated: true)
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
    
    // ✅ 日期选择器值变化监听
    @objc private func datePickerValueChanged(_ sender: UIDatePicker) {
        // ✅ 保存用户选择的日期，防止自动重置
        selectedDate = sender.date
        print("✅ BirthdayDatePopup: 用户选择日期：\(sender.date)")
    }
    
    func show(width: CGFloat, bottomSpacing: CGFloat, initialDate: Date? = nil) {
        print("✅ BirthdayDatePopup: show 被调用 - width: \(width), bottomSpacing: \(bottomSpacing)")
        guard width > 0 else {
            print("❌ BirthdayDatePopup: width 为0，无法显示弹窗")
            return
        }
        self.layout(width: width, bottomSpacing: bottomSpacing)
        // ✅ 如果提供了初始日期，使用它；否则使用当前日期
        let dateToUse = initialDate ?? Date()
        // ✅ 先设置selectedDate，再设置datePicker.date，避免冲突
        selectedDate = dateToUse
        datePicker.date = dateToUse
        print("✅ BirthdayDatePopup: 初始日期：\(dateToUse), backView.bounds: \(backView.bounds)")
        
        // ✅ 直接显示弹窗（通常已经在主线程）
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
        print("✅ BirthdayDatePopup: popup.show 已调用")
    }
    
    // ✅ 添加公共dismiss方法（仿照其他弹窗）
    func dismiss(animated: Bool) {
        popup.dismiss(animated: animated)
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        // ✅ 手动计算高度：titleLabel区域(48) + datePicker顶部间距(20) + datePicker高度(216) + continueButton顶部间距(20) + continueButton高度(56) + bottomSpacing
        let calculatedHeight: CGFloat = 48 + 20 + 216 + 20 + 56 + bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: calculatedHeight)
        print("✅ BirthdayDatePopup: layout - width: \(backView.width()), height: \(calculatedHeight)")
    }
}

