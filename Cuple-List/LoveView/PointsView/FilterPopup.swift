//
//  FilterPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class FilterPopup: NSObject {
    var homeViewController: HomeViewController!
    var backView: ViewGradientView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    var filteView: BorderGradientView!
    var viewButtonView: DualButtonView!
    var statusButtonView: DualButtonView!
    var timeButtonView: DualButtonView!
    
    var continueButton: UIButton!
    
    // ✅ 回调闭包：当点击 Continue 按钮时调用
    var onContinueTapped: (() -> Void)?
    
    // ✅ 用于管理所有 ReactiveSwift 观察者的断开链接
    private let disposables = CompositeDisposable()
    
    override init() {
        super.init()
        setupUI()
    }
    
    deinit {
        // ✅ 清理所有观察者，断开链接
        disposables.dispose()
    }
    
    private func setupUI() {
        backView = ViewGradientView()
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
        // ✅ 保存观察者到 CompositeDisposable 中，确保可以正确断开链接
        disposables += closeButton.reactive.controlEvents(.touchUpInside).observeValues {
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
        titleLabel.text = "Filter"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        filteView = BorderGradientView()
        filteView.layer.cornerRadius = 18
        backView.addSubview(filteView)
        
        filteView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(287)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(25)
        }
        
        viewButtonView = DualButtonView(title: "View", leftButtonTitle: "Partner", leftButtonImage: .assignUnselect, rightButtonTitle: "Oneself", rightButtonImage: .assignUnselect)
        filteView.addSubview(viewButtonView)
        
        viewButtonView.snp.makeConstraints { make in
            make.height.equalToSuperview().dividedBy(3)
            make.width.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        viewButtonView.leftButton.addTarget(self, action: #selector(PartnerButtonTapped), for: .touchUpInside)
        viewButtonView.rightButton.addTarget(self, action: #selector(OneselfButtonTapped), for: .touchUpInside)
        
        statusButtonView = DualButtonView(title: "Status", leftButtonTitle: "Completed", leftButtonImage: .assignUnselect, rightButtonTitle: "Overdue", rightButtonImage: .assignUnselect)
        filteView.addSubview(statusButtonView)
        
        statusButtonView.leftButton.addTarget(self, action: #selector(completedButtonTapped), for: .touchUpInside)
        statusButtonView.rightButton.addTarget(self, action: #selector(overdueButtonTapped), for: .touchUpInside)
        
        statusButtonView.snp.makeConstraints { make in
            make.top.equalTo(viewButtonView.snp.bottom)
            make.width.equalToSuperview()
            make.height.equalToSuperview().dividedBy(3)
        }
        
        
        timeButtonView = DualButtonView(title: "Time", leftButtonTitle: "Newest", leftButtonImage: .assignUnselect, rightButtonTitle: "Oldest", rightButtonImage: .assignUnselect)
        filteView.addSubview(timeButtonView)
        
        timeButtonView.leftButton.addTarget(self, action: #selector(NewestButtonTapped), for: .touchUpInside)
        timeButtonView.rightButton.addTarget(self, action: #selector(OldestButtonTapped), for: .touchUpInside)
        
        timeButtonView.snp.makeConstraints { make in
            make.top.equalTo(statusButtonView.snp.bottom) // 放在 statusButtonView 下方
            make.width.equalToSuperview()
            make.height.equalToSuperview().dividedBy(3)
        }
        
        
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
        
        popup = WavesPopup(contentView: backView,
                           showType: .slideInFromBottom,
                           dismissType: .slideOutToBottom,
                           maskType: .dimmed,
                           dismissOnBackgroundTouch: true,
                           dismissOnContentTouch: false,
                           dismissPanView: hintView)
    }
    
    @objc private func PartnerButtonTapped() {
        // 切换状态：如果已选中则取消，否则选中
        let isSelected = viewButtonView.leftButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05)
        if isSelected {
            viewButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
            viewButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        } else {
            viewButtonView.leftButton.backgroundColor = .color(hexString: "#5DCF51").withAlphaComponent(0.05)
            viewButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
            viewButtonView.leftButtonImageView.image = UIImage(named: "assignSelect")
            viewButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        }
    }
    
    @objc private func OneselfButtonTapped() {
        // 切换状态：如果已选中则取消，否则选中
        let isSelected = viewButtonView.rightButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05)
        if isSelected {
            viewButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
            viewButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        } else {
            viewButtonView.rightButton.backgroundColor = .color(hexString: "#5DCF51").withAlphaComponent(0.05)
            viewButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
            viewButtonView.rightButtonImageView.image = UIImage(named: "assignSelect")
            viewButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        }
    }
    
    @objc private func completedButtonTapped() {
        // 切换状态：如果已选中则取消，否则选中
        let isSelected = statusButtonView.leftButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05)
        if isSelected {
            statusButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
            statusButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        } else {
            statusButtonView.leftButton.backgroundColor = .color(hexString: "#5DCF51").withAlphaComponent(0.05)
            statusButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
            statusButtonView.leftButtonImageView.image = UIImage(named: "assignSelect")
            statusButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        }
    }
    
    @objc private func overdueButtonTapped() {
        // 切换状态：如果已选中则取消，否则选中
        let isSelected = statusButtonView.rightButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05)
        if isSelected {
            statusButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
            statusButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        } else {
            statusButtonView.rightButton.backgroundColor = .color(hexString: "#5DCF51").withAlphaComponent(0.05)
            statusButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
            statusButtonView.rightButtonImageView.image = UIImage(named: "assignSelect")
            statusButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        }
    }
    
    
    @objc private func NewestButtonTapped() {
        // 切换状态：如果已选中则取消，否则选中
        let isSelected = timeButtonView.leftButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05)
        if isSelected {
            timeButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
            timeButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        } else {
            timeButtonView.leftButton.backgroundColor = .color(hexString: "#5DCF51").withAlphaComponent(0.05)
            timeButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
            timeButtonView.leftButtonImageView.image = UIImage(named: "assignSelect")
            timeButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        }
    }
    
    @objc private func OldestButtonTapped() {
        // 切换状态：如果已选中则取消，否则选中
        let isSelected = timeButtonView.rightButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05)
        if isSelected {
            timeButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
            timeButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        } else {
            timeButtonView.rightButton.backgroundColor = .color(hexString: "#5DCF51").withAlphaComponent(0.05)
            timeButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
            timeButtonView.rightButtonImageView.image = UIImage(named: "assignSelect")
            timeButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        }
    }
    
    @objc private func continueButtonTapped() {
        // 调用回调
        onContinueTapped?()
        // 关闭弹窗
        popup.dismiss(animated: true)
    }
    
    func show(width: CGFloat, bottomSpacing: CGFloat) {
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: filteView.maxY() + 90 + bottomSpacing)
    }
}
