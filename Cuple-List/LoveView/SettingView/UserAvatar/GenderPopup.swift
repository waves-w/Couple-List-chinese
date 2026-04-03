//
//  GenderPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup

class GenderPopup: NSObject {
    var backView: ViewGradientView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    var UserAView: UIView!
    var UserBView: UIView!
    var manImage: UIImageView!
    var womanImage: UIImageView!
    var UserAiconImageView: UIImageView!
    var UserBiconImageView: UIImageView!
    
    let selectedImage = UIImage(named: "assignSelect")
    let unselectedImage = UIImage(named: "assignUnselect")
    
    var isUserASelected: Bool = false  // Male
    var isUserBSelected: Bool = false  // Female
    var continueButton: UIButton!
    var assignselected: ((Date) -> Void)?
    // ✅ 新增：性别选择回调
    var onGenderSelected: ((String) -> Void)?  // 回调：参数为 "Male" 或 "Female"
    
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
        titleLabel.text = "Gender"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        let manView = UIView()
        backView.addSubview(manView)
        
        manView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(216.0 / 375.0)
            make.height.equalTo(108)
            make.top.equalTo(titleLabel.snp.bottom).offset(25)
        }
        
        UserAView = UIView()
        UserAView.isUserInteractionEnabled = true
        manView.addSubview(UserAView)
        
        UserAView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(80.0 / 216.0)
        }
        
        manImage = UIImageView(image: UIImage(named: "maleImage"))
        UserAView.addSubview(manImage)
        
        manImage.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(89.0 / 108.0)
            make.width.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        UserAiconImageView = UIImageView()
        UserAiconImageView.image = unselectedImage
        manView.addSubview(UserAiconImageView)
        
        UserAiconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(manImage.snp.bottom).offset(8)
        }
        
        let partnerLabel = UILabel()
        partnerLabel.text = "Male"
        partnerLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        UserAView.addSubview(partnerLabel)
        
        partnerLabel.snp.makeConstraints { make in
            make.left.equalTo(UserAiconImageView.snp.right).offset(3)
            make.centerY.equalTo(UserAiconImageView)
        }
        
        
        UserBView = UIView()
        UserBView.isUserInteractionEnabled = true
        manView.addSubview(UserBView)
        
        UserBView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(80.0 / 216.0)
        }
        
        womanImage = UIImageView(image: UIImage(named: "femaleImage"))
        UserBView.addSubview(womanImage)
        
        womanImage.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(89.0 / 108.0)
            make.width.equalToSuperview()
        }
        
        UserBiconImageView = UIImageView()
        UserBiconImageView.image = unselectedImage
        UserBView.addSubview(UserBiconImageView)
        
        UserBiconImageView.snp.makeConstraints { make in
            make.left.equalTo(womanImage.snp.left)
            make.top.equalTo(manImage.snp.bottom).offset(8)
        }
        
        let oneselfLabel = UILabel()
        oneselfLabel.text = "Female"
        oneselfLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        UserBView.addSubview(oneselfLabel)
        
        oneselfLabel.snp.makeConstraints { make in
            make.left.equalTo(UserBiconImageView.snp.right).offset(3)
            make.centerY.equalTo(UserBiconImageView)
        }
        
        
        let tapA = UITapGestureRecognizer(target: self, action: #selector(handleUserATap))
        UserAView.addGestureRecognizer(tapA)
        
        let tapB = UITapGestureRecognizer(target: self, action: #selector(handleUserBTap))
        UserBView.addGestureRecognizer(tapB)
        
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
            
            // ✅ 确定选择的性别并调用回调
            let selectedGender: String
            if self.isUserASelected {
                selectedGender = "Male"
            } else if self.isUserBSelected {
                selectedGender = "Female"
            } else {
                // 如果没有选择，不保存
                self.popup.dismiss(animated: true)
                return
            }
            
            print("✅ GenderPopup: 保存性别=\(selectedGender)")
            
            // ✅ 调用回调保存性别
            self.onGenderSelected?(selectedGender)
            
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
    
    @objc private func handleUserATap() {
        // ✅ 修复：性别选择是单选，选择 Male 时取消 Female
        isUserASelected = true
        isUserBSelected = false
        updateSelectionState()
        print("✅ GenderPopup: 选择了 Male")
    }
    
    @objc private func handleUserBTap() {
        // ✅ 修复：性别选择是单选，选择 Female 时取消 Male
        isUserASelected = false
        isUserBSelected = true
        updateSelectionState()
        print("✅ GenderPopup: 选择了 Female")
    }
    
    // ✅ 更新图标状态的方法（单选逻辑）
    private func updateSelectionState() {
        UserAiconImageView.image = isUserASelected ? selectedImage : unselectedImage
        UserBiconImageView.image = isUserBSelected ? selectedImage : unselectedImage
    }
    
    // ✅ 新增：加载当前性别并更新选择状态
    func loadCurrentGender(_ gender: String?) {
        // 重置选择状态
        isUserASelected = false
        isUserBSelected = false
        
        // 根据当前性别设置选择状态
        if let gender = gender {
            if gender.lowercased() == "male" || gender.lowercased() == "男" {
                isUserASelected = true
            } else if gender.lowercased() == "female" || gender.lowercased() == "女" {
                isUserBSelected = true
            }
        }
        
        updateSelectionState()
        print("✅ GenderPopup: 加载当前性别=\(gender ?? "未设置")")
    }
    
    func show(width: CGFloat, bottomSpacing: CGFloat) {
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        self.bottomSpacing = bottomSpacing
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: 0)
        backView.layoutNow()
        backView.bounds = CGRect(x: 0, y: 0, width: backView.width(), height: UserBView.maxY() + 161 + bottomSpacing)
    }
}
