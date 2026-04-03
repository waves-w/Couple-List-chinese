//
//  BootTogetherDateViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

final class BootTogetherDateViewController: UIViewController {
    
    private var datePicker: UIDatePicker!
    private var continueButton: UIButton!
    private var backButton: UIButton!
    private var selectedDate: Date = {
        let cal = Calendar.current
        return cal.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        if let existing = UserManger.manager.getUserModelByUUID(UserManger.manager.currentUserUUID)?.relationshipStartDate {
            selectedDate = existing
        }
        datePicker.date = selectedDate
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.togetherDate)
    }
    
    private func setUI() {
        view.backgroundColor = .white
        
        let bg = UIImageView(image: .bootbackiamge)
        bg.contentMode = .scaleAspectFill
        bg.clipsToBounds = true
        view.addSubview(bg)
        bg.snp.makeConstraints { make in
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
        title.text = "When did your relationship begin?"
        title.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        title.textColor = .color(hexString: "#322D3A")
        title.textAlignment = .center
        title.numberOfLines = 0
        view.addSubview(title)
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(view.height() * 200 / 812)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: "en_US")
        let calendar = Calendar.current
        var minComponents = DateComponents()
        minComponents.year = 1900
        minComponents.month = 1
        minComponents.day = 1
        if let minDate = calendar.date(from: minComponents) {
            datePicker.minimumDate = minDate
        }
        datePicker.maximumDate = Date()
        view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(title.snp.bottom).offset(36)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalToSuperview().multipliedBy(202.0 / 812.0)
        }
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
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
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func continueTapped() {
        BootOnboardingFeedback.playContinueButton()
        let uuid = UserManger.manager.currentUserUUID
        let dateToSave = datePicker.date
        UserManger.manager.updateRelationshipStartDate(uuid: uuid, date: dateToSave)
        // 「在一起」纪念日仅在伴侣链接成功后创建（见 AnniManger.handleCoupleDidLink）
        navigationController?.pushViewController(BootThingsViewController(), animated: true)
    }
}
