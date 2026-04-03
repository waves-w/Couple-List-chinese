//
//  BootThingsViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class BootThingsViewController: UIViewController {
    var backButton: UIButton!
    var continueButton: UIButton!
    
    private let thingImageNames = ["thingsa", "thingsb", "thingsc", "thingsd"]
    private let thingHeights: [CGFloat] = [107, 98, 109, 100]  // 四张图各自高度
    /// 图片之间的垂直间距（可调整）
    private var thingImageViews: [UIImageView] = []
    private let animationContainer = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.things)
        startThingsAnimation()
    }
    
    func setUI() {
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
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        let pointsLabel = UILabel()
        pointsLabel.text = "Plan things together"
        pointsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        pointsLabel.textColor = .color(hexString: "#322D3A")
        pointsLabel.numberOfLines = 2
        pointsLabel.textAlignment = .center
        view.addSubview(pointsLabel)
        let xxx88 = view.height() * 88.0 / 812.0
        
        pointsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(view.height() * 80 / 812)
        }
        
        // 动画容器：thingsa/b/c/d 从下到上依次跳出
        view.addSubview(animationContainer)
        animationContainer.snp.makeConstraints { make in
            make.top.equalTo(pointsLabel.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(414.0 / 812.0)
        }
        
        setupThingImages()
        
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
    
    private func setupThingImages() {
//        let containerWidth = view.width() * 321.0 / 375.0
//        let imageWidth = containerWidth * 0.6  // 四张图宽度一致
        
        var topOffset: CGFloat = 0
        for (index, name) in thingImageNames.enumerated() {
            guard let image = UIImage(named: name) else { continue }
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFit
            iv.alpha = 0
            iv.transform = CGAffineTransform(translationX: 0, y: 60)
            animationContainer.addSubview(iv)
            thingImageViews.append(iv)
            
            let height = thingHeights[index]
            iv.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.width.equalToSuperview()
                make.height.equalToSuperview().multipliedBy(height / 414.0)
                make.top.equalToSuperview().offset(topOffset)
            }
            
            let imageSpacing = view.height() * 12 / 812
            
            topOffset += height + imageSpacing
        }
    }
    
    private func startThingsAnimation() {
        let duration: TimeInterval = 0.7
        let delayBetween: TimeInterval = 0.55
        let slideUpOffset: CGFloat = 30
        let overshootUp: CGFloat = -1.5
        let bounceDown: CGFloat = 1.5
        
        for (index, iv) in thingImageViews.enumerated() {
            iv.alpha = 0
            iv.transform = CGAffineTransform(translationX: 0, y: slideUpOffset)
        
            let delay = Double(index) * delayBetween
            
            UIView.animateKeyframes(withDuration: duration, delay: delay, options: [.calculationModeCubic]) {
                // 滑到位置
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.55) {
                    iv.alpha = 1
                    iv.transform = .identity
                }
                // 到位置立刻往上弹
                UIView.addKeyframe(withRelativeStartTime: 0.55, relativeDuration: 0.15) {
                    iv.transform = CGAffineTransform(translationX: 0, y: overshootUp)
                }
                // 再弹下去
                UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.15) {
                    iv.transform = CGAffineTransform(translationX: 0, y: bounceDown)
                }
                // 回原位
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
        self.navigationController?.pushViewController(StoryController(), animated: true)
    }
}
