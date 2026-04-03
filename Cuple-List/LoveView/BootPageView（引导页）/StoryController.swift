//
//  StoryController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class StoryController: UIViewController {
    
    var backButton: UIButton!
    var continueButton: UIButton!
    
    private let storyImageNames = ["stroya", "stroyb", "stroyc", "stroyd"]
    private let storyHeights: [CGFloat] = [54, 60, 60, 60]
    private var storyImageViews: [UIImageView] = []
    private let animationContainer = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.story)
        startStoryAnimation()
    }
    
    func setUI() {
        view.backgroundColor = .white
        
        let inView = ViewGradientView()
        view.addSubview(inView)
        inView.snp.makeConstraints { make in
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
        
//        let titleLabel = UILabel()
//        titleLabel.text = "Story"
//        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
//        titleLabel.textColor = .color(hexString: "#322D3A")
//        titleLabel.numberOfLines = 2
//        titleLabel.textAlignment = .center
//        view.addSubview(titleLabel)
//        titleLabel.snp.makeConstraints { make in
//            make.centerX.equalToSuperview()
//            make.top.equalTo(backButton.snp.bottom).offset(view.height() * 80 / 812)
//        }
        
        view.addSubview(animationContainer)
        animationContainer.snp.makeConstraints { make in
            make.top.equalTo(backButton.snp.bottom).offset(43)
            make.centerX.equalToSuperview()
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalToSuperview().multipliedBy(335.0 / 812.0)
        }
        
        setupStoryImages()
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 18
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-4)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
    }
    
    private func setupStoryImages() {
        var topOffset: CGFloat = 0
        for (index, name) in storyImageNames.enumerated() {
            guard let image = UIImage(named: name) else { continue }
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFill
//            iv.setContentHuggingPriority(.defaultLow, for: .horizontal)
//            iv.setContentHuggingPriority(.defaultLow, for: .vertical)
//            iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
//            iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            iv.alpha = 0
            iv.transform = CGAffineTransform(translationX: 0, y: 60)
            animationContainer.addSubview(iv)
            storyImageViews.append(iv)
            
            let height = storyHeights[index]
            let spacing = view.height() * 28 / 812
            iv.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
//                make.left.equalTo(30)
//                make.right.equalTo(-30)
                make.width.equalToSuperview()
                make.height.equalToSuperview().multipliedBy(height / 335.0)
                make.top.equalToSuperview().offset(topOffset)
            }
            topOffset += height + spacing
        }
    }
    
    private func startStoryAnimation() {
        let duration: TimeInterval = 0.7
        let delayBetween: TimeInterval = 0.55
        let slideUpOffset: CGFloat = 30
        let overshootUp: CGFloat = -1.5
        let bounceDown: CGFloat = 1.5
        
        for (index, iv) in storyImageViews.enumerated() {
            iv.alpha = 0
            iv.transform = CGAffineTransform(translationX: 0, y: slideUpOffset)
        
            let delay = Double(index) * delayBetween
            
            UIView.animateKeyframes(withDuration: duration, delay: delay, options: [.calculationModeCubic]) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.55) {
                    iv.alpha = 1
                    iv.transform = .identity
                }
                UIView.addKeyframe(withRelativeStartTime: 0.55, relativeDuration: 0.15) {
                    iv.transform = CGAffineTransform(translationX: 0, y: overshootUp)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.15) {
                    iv.transform = CGAffineTransform(translationX: 0, y: bounceDown)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.85, relativeDuration: 0.15) {
                    iv.transform = .identity
                }
            }
        }
    }
    
    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func continueButtonTapped() {
        BootOnboardingFeedback.playContinueButton()
        navigationController?.pushViewController(SetView(), animated: true)
    }
}
