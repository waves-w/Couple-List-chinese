//
//  ProductView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import StoreKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class ProductView: UIView {
    
    // ✅ 普通标签
    var timeLabel: UILabel!
    var priceLabel: UILabel!
    var rightLabel: UILabel!
    
    var selectImage: UIImageView!
    var frameView: UIView!
    private var mostPopularImageView: UIImageView!
    
    /// 是否一直显示 "Most Popular" 角标（仅周订阅使用）
    var showMostPopularBadgeWhenSelected = false
    
    // ✅ 保存原始约束，用于动画
    private var timeLabelTopConstraint: Constraint?
    private var priceLabelTopConstraint: Constraint?
    private var selectImageTopConstraint: Constraint?
    private var selectImageBottomConstraint: Constraint? // ✅ selectImage 相对于底边的约束
    private var priceLabelGradientTopConstraint: Constraint?
    
    // ✅ 保存 frameView 的约束，用于选中时增加尺寸
    private var frameViewTopConstraint: Constraint?
    private var frameViewLeftConstraint: Constraint?
    private var frameViewRightConstraint: Constraint?
    private var frameViewBottomConstraint: Constraint?
    
    let pipe = Signal<Int, Never>.pipe()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    func set(priceString: String , time: String ,rightTimeLabel:String) {
        // ✅ 更新普通标签
        timeLabel.text = time
        priceLabel.text = priceString
        rightLabel.text = rightTimeLabel
        
    }
    func configure() {
        layer.cornerRadius = 10
        clipsToBounds = false // ✅ 允许 frameView 超出边界
        
        let tap = UITapGestureRecognizer()
        tap.reactive.stateChanged.observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.pipe.input.send(value: 1)
        }
        addGestureRecognizer(tap)
        
        let borderView = BorderGradientView()
        borderView.useVividGradient = true  // 订阅页使用 AECBFF→CDB0FF 渐变边框
        borderView.cornerRadius = 18
        borderView.backgroundColor = UIColor.color(hexString: "#FBFBFB")
        frameView = borderView
        addSubview(frameView)
        
        // ✅ 创建普通标签（未选中时显示）
        timeLabel = UILabel()
        timeLabel.textColor = .color(hexString: "#111111")
        timeLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        timeLabel.textAlignment = .left
        addSubview(timeLabel)
        
        priceLabel = UILabel()
        priceLabel.textColor = .color(hexString: "#C5C5C5")
        priceLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 13)
        priceLabel.textAlignment = .left
        addSubview(priceLabel)
        
        rightLabel = UILabel()
        rightLabel.textColor = .color(hexString: "#111111")
        rightLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        addSubview(rightLabel)
        
        frameView.snp.makeConstraints { make in
            frameViewTopConstraint = make.top.equalToSuperview().constraint
            frameViewLeftConstraint = make.left.equalToSuperview().constraint
            frameViewRightConstraint = make.right.equalToSuperview().constraint
            frameViewBottomConstraint = make.bottom.equalToSuperview().constraint
        }
        
        // 设计基准 375×812，与工程内其它比例间距一致
        let padW = UIScreen.main.bounds.width * 12.0 / 375.0
        let padH = UIScreen.main.bounds.height * 12.0 / 812.0
        
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(padH)
            make.left.equalTo(padW)
        }
        
        priceLabel.snp.makeConstraints { make in
            make.bottom.equalTo(-padH)
            make.left.equalTo(padW)
        }
        
        selectImage = UIImageView(image: UIImage(named: "pointsSharedButton"))
        addSubview(selectImage)
        
        selectImage.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.centerY.equalToSuperview()
        }
        
        rightLabel.snp.makeConstraints { make in
            make.right.equalTo(selectImage.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        mostPopularImageView = UIImageView(image: UIImage(named: "mostpopular"))
        mostPopularImageView.contentMode = .scaleAspectFit
//        mostPopularImageView.isHidden = true
        addSubview(mostPopularImageView)
        mostPopularImageView.snp.makeConstraints { make in
            make.top.equalTo(-12)
            make.right.equalTo(-14)
//            make.width.equalTo(72)
//            make.height.equalTo(20)
        }
    }
       
    func setSelected(_ selected: Bool) {
        selectImage.image = selected ? UIImage(named: "pointsSharedButton") : UIImage(named: "pointsUnSharedButton")
        
        mostPopularImageView.isHidden = !showMostPopularBadgeWhenSelected
        
        if selected {
            // ✅ 选中状态：渐变边框
            (frameView as? BorderGradientView)?.borderWidth = 2
            frameView.layer.borderWidth = 0
            layoutIfNeeded()
        } else {
            // ✅ 未选中状态：纯色边框 #EEEEEE
            (frameView as? BorderGradientView)?.borderWidth = 0
            frameView.layer.borderWidth = 2
            frameView.layer.borderColor = UIColor.color(hexString: "#EEEEEE").cgColor
            frameView.layer.cornerRadius = 18
            layoutIfNeeded()
        }
    }
    
}
