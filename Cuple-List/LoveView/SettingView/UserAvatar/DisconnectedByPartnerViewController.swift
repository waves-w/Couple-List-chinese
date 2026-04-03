//
//  DisconnectedByPartnerViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class DisconnectedByPartnerViewController: UIViewController {
    
//    private var titleLabel: UILabel!
    private var messageLabel: UILabel!
    private var linkAgainButton: UIButton!
    private var closeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let backView = ViewGradientView()
        view.addSubview(backView)
        backView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeButton = UIButton()
        closeButton.setImage(UIImage(named: "breakback"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.size.equalTo(CGSize(width: 44, height: 44))
        }
        
        let lovebreakImage = UIImageView(image: .lovebreak)
        view.addSubview(lovebreakImage)
        
        lovebreakImage.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-60)
        }
        
        let titleLabel = UILabel()
        titleLabel.text = "Your partnership has been \ndisconnected."
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
        titleLabel.textColor = .color(hexString: "#000000")
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(lovebreakImage.snp.bottom).offset(23)
            make.left.right.equalToSuperview().inset(32)
        }
        
        messageLabel = UILabel()
        messageLabel.text = "Shared tasks, points, and wishlists are no longer linked.Thank you for letting this space be part of your story."
        messageLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        messageLabel.textColor = .color(hexString: "#999DAB")
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        view.addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
        }
        
        linkAgainButton = UIButton(type: .custom)
        linkAgainButton.setTitle("Back", for: .normal)
        linkAgainButton.setTitleColor(.white, for: .normal)
        linkAgainButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
        linkAgainButton.backgroundColor = .color(hexString: "#111111")
        linkAgainButton.layer.cornerRadius = 22
        linkAgainButton.clipsToBounds = true
        linkAgainButton.addTarget(self, action: #selector(linkAgainTapped), for: .touchUpInside)
        view.addSubview(linkAgainButton)
        linkAgainButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
            make.height.equalTo(52)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-24)
        }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func linkAgainTapped() {
        dismiss(animated: true)
//        let linkPage = CheekBootPageView()
//        linkPage.modalPresentationStyle = .fullScreen
//        linkPage.isPresentedFromPartnerUnlink = true
//        present(linkPage, animated: true)
    }
}
