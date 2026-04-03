//
//  BootNameInputViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

final class BootNameInputViewController: UIViewController, UITextFieldDelegate {
    
    private var nameTextField: UITextField! // 仅作显示，真正输入在 hiddenTextField
    private var continueButton: UIButton!
    private var backButton: UIButton!
    
    // ✅ 键盘输入相关：view 响应键盘，hiddenTextField 为唯一第一响应者
    private var hiddenTextField: UITextField!
    private var cursorView: UIView! // 自定义光标，键盘弹出时显示
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        setupContinueButton()
        updateContinueState()
        
        // ✅ 添加点击背景区域收起键盘的手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.nameInput)
        hiddenTextField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hiddenTextField?.resignFirstResponder()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !cursorView.isHidden {
            updateCursorPosition()
        }
    }
    
    private func setUI() {
        view.backgroundColor = .white
        
        let inView = UIImageView(image: .bootbackiamge)
        view.addSubview(inView)
        inView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backButton = UIButton()
        backButton.setImage(UIImage(named: "arrow"), for: .normal)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        let title = UILabel()
        title.text = "What’s your name?"
        title.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        title.textColor = .color(hexString: "#322D3A")
        title.textAlignment = .center
        title.numberOfLines = 0
        view.addSubview(title)
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(view.height() * 200 / 812)
        }
        
        
        let fieldShadowWrap = UIView()
        fieldShadowWrap.backgroundColor = .clear
        fieldShadowWrap.layer.shadowColor = UIColor.black.cgColor
        fieldShadowWrap.layer.shadowOffset = CGSize(width: 0, height: 4)
        fieldShadowWrap.layer.shadowRadius = 12
        fieldShadowWrap.layer.shadowOpacity = 0.03
        view.addSubview(fieldShadowWrap)
        fieldShadowWrap.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.top.equalTo(title.snp.bottom).offset(26)
            make.height.equalTo(48)
        }
        
        let fieldBg = UIView()
        fieldBg.backgroundColor = .color(hexString: "#FFFFFF")
        fieldBg.layer.cornerRadius = 16
        fieldBg.layer.masksToBounds = true
        fieldShadowWrap.addSubview(fieldBg)
        fieldBg.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        // ✅ 点击 fieldBg 区域弹出键盘（view 响应，hiddenTextField 成为第一响应者）
        let fieldTap = UITapGestureRecognizer(target: self, action: #selector(fieldAreaTapped))
        fieldBg.addGestureRecognizer(fieldTap)
        fieldBg.isUserInteractionEnabled = true
        
        nameTextField = UITextField()
        nameTextField.placeholder = "Enter your name"
        nameTextField.font = UIFont(name: "SFCompactRounded-Semibold", size: 16)
        nameTextField.textColor = .color(hexString: "#322D3A")
        nameTextField.isUserInteractionEnabled = false // 仅作显示，不直接响应键盘
        fieldBg.addSubview(nameTextField)
        nameTextField.snp.makeConstraints { make in
            make.left.equalTo(16)
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
        }
        
        // ✅ 自定义光标
        cursorView = UIView()
        cursorView.backgroundColor = .color(hexString: "#322D3A")
        cursorView.layer.cornerRadius = 1
        cursorView.isHidden = true
        fieldBg.addSubview(cursorView)
        
        // ✅ 隐藏的 TextField，用于弹出键盘
        hiddenTextField = UITextField()
        hiddenTextField.isHidden = true
        hiddenTextField.returnKeyType = .done
        hiddenTextField.delegate = self
        hiddenTextField.autocorrectionType = .no
        hiddenTextField.addTarget(self, action: #selector(hiddenTextFieldChanged), for: .editingChanged)
        view.addSubview(hiddenTextField)
    }
    
    @objc private func fieldAreaTapped() {
        hiddenTextField.text = nameTextField.text ?? ""
        hiddenTextField.becomeFirstResponder()
    }
    
    @objc private func hiddenTextFieldChanged() {
        nameTextField.text = hiddenTextField.text ?? ""
        updateContinueState()
        updateCursorPosition()
    }
    
    @objc private func keyboardWillShow() {
        guard hiddenTextField.isFirstResponder else { return }
        cursorView.isHidden = false
        updateCursorPosition()
        startCursorBlink()
    }
    
    @objc private func keyboardWillHide() {
        cursorView.isHidden = true
        stopCursorBlink()
    }
    
    private func updateCursorPosition() {
        guard !cursorView.isHidden, let fieldBg = cursorView.superview else { return }
        let text = nameTextField.text ?? ""
        let font = nameTextField.font ?? UIFont.systemFont(ofSize: 16)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let cursorHeight: CGFloat = 20
        let y = (fieldBg.bounds.height - cursorHeight) / 2
        cursorView.frame = CGRect(x: 16 + textWidth, y: y, width: 2, height: cursorHeight)
    }
    
    private func startCursorBlink() {
        stopCursorBlink()
        cursorView.layer.add(blinkAnimation(), forKey: "blink")
    }
    
    private func stopCursorBlink() {
        cursorView.layer.removeAnimation(forKey: "blink")
    }
    
    private func blinkAnimation() -> CAAnimation {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1
        anim.toValue = 0
        anim.duration = 0.5
        anim.autoreverses = true
        anim.repeatCount = .infinity
        return anim
    }
    
    private func setupContinueButton() {
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .systemGray
        continueButton.isEnabled = false
        continueButton.layer.cornerRadius = 18
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-4)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
    }
    
    @objc private func dismissKeyboard(_ gesture: UITapGestureRecognizer) {
        view.endEditing(true)
        hiddenTextField.resignFirstResponder()
    }
    
    private func updateContinueState() {
        let ok = !(nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        continueButton.isEnabled = ok
        continueButton.backgroundColor = ok ? .color(hexString: "#111111") : .systemGray
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        hiddenTextField.resignFirstResponder()
        return true
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func continueTapped() {
        let name = (hiddenTextField.text ?? nameTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        BootOnboardingFeedback.playContinueButton()
        view.endEditing(true)
        continueButton.isEnabled = false
        
        CoupleStatusManager.shared.generateFirstLaunchId { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let uuid = UserManger.manager.currentUserUUID
                var cal = Calendar.current
                var c = DateComponents()
                c.year = 1997
                c.month = 1
                c.day = 1
                let defaultBirthday = cal.date(from: c) ?? Date()
                
                if let _ = UserManger.manager.getUserModelByUUID(uuid) {
                    _ = UserManger.manager.updateUserByUUID(uuid: uuid, userName: name)
                } else {
                    _ = UserManger.manager.addModel(
                        userName: name,
                        userUUID: uuid,
                        birthday: defaultBirthday,
                        deviceModel: UserModel.getCurrentDeviceModel(),
                        isInLinkedState: false
                    )
                }
                self.continueButton.isEnabled = true
                self.navigationController?.pushViewController(WhatView(), animated: true)
            }
        }
    }
}
