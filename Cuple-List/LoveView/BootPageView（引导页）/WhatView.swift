//
//  WhatView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class WhatView: UIViewController {
    
    private var backButton: UIButton!
    private var whatLabel: UILabel!
    private var continueButton: UIButton!
    
    private var femaleOuter: UIView!
    private var femaleLogo: UIImageView!
    private var femaleHit: UIButton!
    
    private var maleOuter: UIView!
    private var maleLogo: UIImageView!
    private var maleHit: UIButton!
    
    var selectedGender: String?
    
    private let logoSize: CGFloat = 62
    
    // Female
    private let femalePink = UIColor.color(hexString: "#FF4FA3")
    private let femaleFillSelected = UIColor.color(hexString: "#FFBAEA").withAlphaComponent(0.12)
    private let femaleFillUnsel = UIColor.color(hexString: "#FFBAEA").withAlphaComponent(0.12)
    
    // Male
    private let maleBlue = UIColor.color(hexString: "#5BA3F5")
    private let maleFillSelected = UIColor.color(hexString: "#A8DDFF").withAlphaComponent(0.12)
    private let maleFillUnsel = UIColor.color(hexString: "#A8DDFF").withAlphaComponent(0.12)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCurrentGender()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.what)
    }
    
    
    private func setUI() {
        view.backgroundColor = UIColor.color(hexString: "#FDF6FA")
        
        let bg = UIImageView(image: .bootbackiamge)
        bg.contentMode = .scaleAspectFill
        bg.clipsToBounds = true
        view.addSubview(bg)
        bg.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backButton = UIButton()
        backButton.setImage(UIImage(named: "arrow"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        whatLabel = UILabel()
        whatLabel.text = "What's your gender?"
        whatLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        whatLabel.textColor = .color(hexString: "#322D3A")
        whatLabel.textAlignment = .center
        view.addSubview(whatLabel)
        whatLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(view.height() * 200 / 812)
        }
        
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 51
        row.alignment = .center
        row.distribution = .equalSpacing
        view.addSubview(row)
        row.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(whatLabel.snp.bottom).offset(36)
        }
        
        (femaleOuter, femaleLogo, femaleHit) = makeGenderOption(
            logoName: "femalelogo",
            in: row
        )
        (maleOuter, maleLogo, maleHit) = makeGenderOption(
            logoName: "malelogo",
            in: row
        )
        
        femaleHit.addTarget(self, action: #selector(femaleTapped), for: .touchUpInside)
        maleHit.addTarget(self, action: #selector(maleTapped), for: .touchUpInside)
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 18
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        continueButton.isEnabled = false
        continueButton.alpha = 0.5
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        view.bringSubviewToFront(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-4)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
        
        applySelectionUI(animated: false)
    }
    
    /// 圆环 + 居中 logo
    private func makeGenderOption(logoName: String, in stack: UIStackView) -> (UIView, UIImageView, UIButton) {
        let outerSize = view.width() * 120.0 / 375.0
        let outer = UIView()
        outer.layer.cornerRadius = outerSize / 2
        outer.layer.masksToBounds = true
        
        let icon = UIImageView(image: UIImage(named: logoName))
        icon.contentMode = .scaleAspectFill
        
        icon.isUserInteractionEnabled = false
        
        outer.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(logoSize)
        }
        
        let hit = UIButton(type: .custom)
        hit.backgroundColor = .clear
        
        let wrap = UIView()
        wrap.addSubview(outer)
        outer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(outerSize)
        }
        wrap.addSubview(hit)
        hit.snp.makeConstraints { $0.edges.equalToSuperview() }
        wrap.snp.makeConstraints { $0.width.height.equalTo(outerSize) }
        stack.addArrangedSubview(wrap)
        
        return (outer, icon, hit)
    }
    
    private func applySelectionUI(animated: Bool) {
        let fSel = selectedGender == "Female"
        let mSel = selectedGender == "Male"
        
        UIView.animate(withDuration: animated ? 0.22 : 0) {
            self.styleFemaleOuter(selected: fSel)
            self.styleMaleOuter(selected: mSel)
        }
    }
    
    private func styleFemaleOuter(selected: Bool) {
        femaleOuter.layer.borderWidth = selected ? 1 : 0
        femaleOuter.layer.borderColor = selected ? UIColor.color(hexString: "#FFBAEA").cgColor : UIColor.clear.cgColor
        femaleOuter.backgroundColor = selected ? femaleFillSelected : femaleFillUnsel
//        femaleLogo.alpha = selected ? 1 : 0.55
    }
    
    private func styleMaleOuter(selected: Bool) {
        maleOuter.layer.borderWidth = selected ? 1 : 0
        maleOuter.layer.borderColor = selected ? UIColor.color(hexString: "#A8DDFF").cgColor : UIColor.clear.cgColor
        maleOuter.backgroundColor = selected ? maleFillSelected : maleFillUnsel
//        maleLogo.alpha = selected ? 1 : 0.55
    }
    
    @objc private func femaleTapped() {
        guard selectedGender != "Female" else { return }
        BootOnboardingFeedback.playSelectionChanged()
        selectedGender = "Female"
        saveGender("Female")
        applySelectionUI(animated: true)
        updateContinueButtonState()
    }
    
    @objc private func maleTapped() {
        guard selectedGender != "Male" else { return }
        BootOnboardingFeedback.playSelectionChanged()
        selectedGender = "Male"
        saveGender("Male")
        applySelectionUI(animated: true)
        updateContinueButtonState()
    }
    
    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func loadCurrentGender() {
        var gender = CoupleStatusManager.shared.userGender
        if gender == nil || gender!.isEmpty {
            let uuid = UserManger.manager.currentUserUUID
            if let m = UserManger.manager.getUserModelByUUID(uuid), let g = m.gender, !g.isEmpty {
                gender = g
                CoupleStatusManager.shared.userGender = g
            }
        }
        if let g = gender, !g.isEmpty {
            let isMale = (g.lowercased() == "male" || g.lowercased() == "男")
            selectedGender = isMale ? "Male" : "Female"
        }
        applySelectionUI(animated: false)
        updateContinueButtonState()
    }
    
    private func saveGender(_ gender: String) {
        let uuid = UserManger.manager.currentUserUUID
        CoupleStatusManager.shared.userGender = gender
        if UserManger.manager.getUserModelByUUID(uuid) == nil {
            _ = UserManger.manager.addModel(
                userName: "YourName",
                userUUID: uuid,
                gender: gender,
                deviceModel: UserModel.getCurrentDeviceModel(),
                isInLinkedState: false
            )
        } else {
            UserManger.manager.updateUserByUUID(uuid: uuid, gender: gender)
        }
    }
    
    private func updateContinueButtonState() {
        let ok = selectedGender != nil
        continueButton.isEnabled = ok
        continueButton.alpha = ok ? 1 : 0.5
    }
    
    @objc func continueButtonTapped() {
        BootOnboardingFeedback.playContinueButton()
        if let g = selectedGender { saveGender(g) }
        navigationController?.pushViewController(BootAvatarSetupViewController(), animated: true)
    }
}

