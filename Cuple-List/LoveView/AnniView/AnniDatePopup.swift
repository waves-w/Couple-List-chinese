//
//  AnniDatePopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class AnniDatePopup: NSObject {
    var homeViewController1: AnniViewController?
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    
    var calendarView: CalendarView!
    var onDateSelected: ((Date) -> Void)?
    var continueButton: UIButton!
    private var selectedDate: Date?
    
    override init() {
        super.init()
        setupUI()
        calendarView.delegate = self
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
        titleLabel.text = "Date"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        let selectView = UIView()
        selectView.backgroundColor = .color(hexString: "#FBFBFB")
        backView.addSubview(selectView)
        
        selectView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(44)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
        }
        
        let selectLabel = UILabel()
        selectLabel.text = "Select a countdown for a future date, \nselect a positive number for a past date"
        selectLabel.numberOfLines = 2
        selectLabel.textAlignment = .center
        selectLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        selectLabel.textColor = .color(hexString: "#999DAB")
        selectView.addSubview(selectLabel)
        
        selectLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        calendarView = CalendarView()
        backView.addSubview(calendarView)
        
        calendarView.snp.makeConstraints { make in
            make.top.equalTo(selectView.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(311)
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
            if let selectedDate = self.selectedDate {
                self.onDateSelected?(selectedDate) // 触发回调，传输数据
                print("通过 Continue 按钮确认日期：\(selectedDate)")
            } else {
                print("未选择日期，不传输数据")
            }
            
            self.popup.dismiss(animated: true) // 确认后关闭弹窗
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
    
    func show(width: CGFloat, bottomSpacing: CGFloat) {
        self.layout(width: width, bottomSpacing: bottomSpacing)
        let currentDate = Date()
        self.selectedDate = currentDate
        if let calendarView = self.calendarView {
            print("初始默认日期：\(currentDate)")
        }
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: calendarView.maxY() + 88 + bottomSpacing)
    }
}

extension AnniDatePopup: CalendarViewDelegate {
    func didSelectDate(_ date: Date) {
        print("日历选中日期（未确认）：\(date)")
        self.selectedDate = date // 仅存储，不调用 onDateSelected
    }
}
