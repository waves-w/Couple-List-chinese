//
//  YearMonthWheelPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

private let yearList = Array(1900...2030)
private let monthList: [String] = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    return (1...12).map { formatter.monthSymbols[$0 - 1] }
}()

class YearMonthWheelPopup: NSObject {
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    var pickerView: UIPickerView!
    var continueButton: UIButton!
    var onSelected: ((Int, Int) -> Void)?  // year, month (1...12)

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
        closeButton.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
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
        titleLabel.text = "Month & Year"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }

        pickerView = UIPickerView()
        pickerView.delegate = self
        pickerView.dataSource = self
        backView.addSubview(pickerView)
        pickerView.snp.makeConstraints { make in
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
        continueButton.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
            guard let self = self else { return }
            let monthRow = self.pickerView.selectedRow(inComponent: 0)
            let yearRow = self.pickerView.selectedRow(inComponent: 1)
            let month = monthRow + 1
            let year = yearList[yearRow]
            self.onSelected?(year, month)
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

    func show(width: CGFloat, bottomSpacing: CGFloat, selectedYear: Int, selectedMonth: Int) {
        self.layout(width: width, bottomSpacing: bottomSpacing)
        let yearRow = yearList.firstIndex(of: selectedYear) ?? yearList.count - 1
        let monthRow = (selectedMonth - 1).clamped(to: 0...11)
        pickerView.selectRow(monthRow, inComponent: 0, animated: false)
        pickerView.selectRow(yearRow, inComponent: 1, animated: false)
        popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }

    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: pickerView.maxY() + 88 + bottomSpacing)
    }
}

extension YearMonthWheelPopup: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        component == 0 ? monthList.count : yearList.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        component == 0 ? monthList[row] : "\(yearList[row])"
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
