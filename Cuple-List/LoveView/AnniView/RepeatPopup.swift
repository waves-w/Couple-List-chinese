//
//  RepeatPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class RepeatPopup: NSObject, UIPickerViewDelegate, UIPickerViewDataSource{
    var homeViewController1: AnniViewController?
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    var neverLabel: UILabel!
    
    var neverButton: BorderGradientButton!
    private var isNeverSelected: Bool = false
    let selectedImage = UIImage(named: "assignSelect")
    let unselectedImage = UIImage(named: "assignUnselect")
    
    var neverButtonImage: UIImageView!
    var repeatPickerView: UIPickerView!
    var repeatPickerContainer: UIView!
    let numberData: [String] = (1...99).map { String($0) } // ✅ 修复：从1开始，去掉0
    let unitData: [String] = ["Day", "Week", "Month", "Year"]
    // 存储当前选中的值 (可选)
    var selectedNumber: Int = 1
    var selectedUnit: String = "Day"
    var continueButton: UIButton!
    
    var onDateSelected: ((Date) -> Void)?
    var onRepeatSelected: ((_ isNever: Bool, _ number: Int, _ unit: String) -> Void)?
    
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
        titleLabel.text = "Repeat"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
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
        neverLabel.text = "Never"
        neverLabel.textColor = .color(hexString: "#322D3A")
        neverLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        neverView.addSubview(neverLabel)
        
        neverLabel.snp.makeConstraints { make in
            make.left.equalTo(neverButtonImage.snp.right).offset(4)
            make.centerY.equalToSuperview()
        }
        
        updateNeverButtonAppearance()
        
        repeatPickerContainer = UIView()
        repeatPickerContainer.layer.cornerRadius = 18
        backView.addSubview(repeatPickerContainer)
        
        repeatPickerContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(25)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            // 给 Picker View 足够的高度，例如 200
            make.height.equalTo(200)
        }
        
        // 2. 创建 UIPickerView
        repeatPickerView = UIPickerView()
        repeatPickerView.delegate = self
        repeatPickerView.dataSource = self
        repeatPickerContainer.addSubview(repeatPickerView)
        
        repeatPickerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
            self.onRepeatSelected?(self.isNeverSelected, self.selectedNumber, self.selectedUnit)
            self.popup.dismiss(animated: true)
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
    
    /// 展示弹窗，可传入当前已选重复使弹窗内默认选中
    func show(width: CGFloat, bottomSpacing: CGFloat,
              initialIsNever: Bool? = nil,
              initialNumber: Int? = nil,
              initialUnit: String? = nil) {
        if let never = initialIsNever, never {
            isNeverSelected = true
            selectedNumber = 1
            selectedUnit = "Day"
            repeatPickerView.isUserInteractionEnabled = false
            repeatPickerView.alpha = 0.5
        } else {
            isNeverSelected = false
            repeatPickerView.isUserInteractionEnabled = true
            repeatPickerView.alpha = 1.0
            if let num = initialNumber, num >= 1, num <= 99 {
                selectedNumber = num
                let row = num - 1
                repeatPickerView.selectRow(row, inComponent: 1, animated: false)
            } else {
                selectedNumber = 1
                repeatPickerView.selectRow(0, inComponent: 1, animated: false)
            }
            if let unit = initialUnit, let unitIndex = unitData.firstIndex(of: unit) {
                selectedUnit = unit
                repeatPickerView.selectRow(unitIndex, inComponent: 2, animated: false)
            } else {
                selectedUnit = "Day"
                repeatPickerView.selectRow(0, inComponent: 2, animated: false)
            }
        }
        updateNeverButtonAppearance()
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: repeatPickerContainer.maxY() + 90 + bottomSpacing)
    }
    
    @objc func toggleNeverButton() {
        // 切换状态
        isNeverSelected.toggle()
        updateNeverButtonAppearance()
        
        if isNeverSelected {
            self.repeatPickerView.selectRow(0, inComponent: 1, animated: true) // ✅ 修复：索引0对应数字1
            repeatPickerView.isUserInteractionEnabled = false
            repeatPickerView.alpha = 0.5
        } else {
            // 如果取消选中 Never，启用滚轮 (如果之前禁用了)
            repeatPickerView.isUserInteractionEnabled = true
            repeatPickerView.alpha = 1.0
        }
    }
    
    private func updateNeverButtonAppearance() {
        // 切换图片
        let image = isNeverSelected ? selectedImage : unselectedImage
        neverButtonImage.image = image
        neverLabel.textColor = isNeverSelected ? .color(hexString: "#322D3A") : .color(hexString: "#999DAB")
        // 可选：切换背景颜色以提供视觉反馈
        let newAlpha: CGFloat = isNeverSelected ? 0.08 : 0.03
        neverButton.subviews.first?.backgroundColor = .color(hexString: "#322D3A").withAlphaComponent(newAlpha)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        // 3 列: Every, 数字, 单位
        return 3
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0:
            return 1 // 第一列: "Every" (固定)
        case 1:
            return numberData.count // 第二列: 数字 (0-99)
        case 2:
            return unitData.count // 第三列: 单位 (Day, Week, Month, Year)
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let pickerLabel = UILabel()
        pickerLabel.textAlignment = .center
        pickerLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 18)
        pickerLabel.textColor = .color(hexString: "#111111")
        
        var text: String = ""
        
        switch component {
        case 0:
            text = "Every"
        case 1:
            text = numberData[row]
        case 2:
            text = unitData[row]
        default:
            break
        }
        
        pickerLabel.text = text
        return pickerLabel
    }
    
    // 2. 选中行时的处理
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if component == 1 {
            // 选中数字
            if let number = Int(numberData[row]) {
                selectedNumber = number
            }
        } else if component == 2 {
            // 选中单位
            selectedUnit = unitData[row]
        }
        
        // 在这里，您可以更新一些 UI 元素来显示选中的 "Every [Number] [Unit]"
        print("Selected Repeat: Every \(selectedNumber) \(selectedUnit)")
    }
    
    // 3. 设置每列的宽度 (可选, 但推荐)
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        let pickerWidth = pickerView.bounds.width
        switch component {
        case 0:
            return pickerWidth * 0.35 // Every 占 35%
        case 1:
            return pickerWidth * 0.25 // 数字占 25%
        case 2:
            return pickerWidth * 0.40 // 单位占 40%
        default:
            return 0
        }
    }
}
