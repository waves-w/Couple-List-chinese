//
//  SetView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class SetView: UIViewController {
    
    private var backButton: UIButton!
    private var setLabel: UILabel!
    private var continueButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.set)
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
        
        setLabel = UILabel()
        setLabel.text = "Keep track of every \nspecial date"
        setLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        setLabel.textColor = .color(hexString: "#322D3A")
        setLabel.textAlignment = .center
        setLabel.numberOfLines = 2
        view.addSubview(setLabel)
        setLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(view.height() * 130 / 812)
        }
        
        let image = UIImageView(image: .setimage)
        view.addSubview(image)
        let xxx71 = view.height() * 71.0 / 812.0
        image.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(setLabel.snp.bottom).offset(xxx71)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(image.snp.width).multipliedBy(233.0 / 335.0)
        }
        
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 18
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        view.bringSubviewToFront(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-4)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
        
    }
    
   
    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
   
    
    @objc func continueButtonTapped() {
        BootOnboardingFeedback.playContinueButton()
        navigationController?.pushViewController(AllowView(), animated: true)
    }
}

