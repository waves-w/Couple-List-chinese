//
//  TimeSegmentSliderView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

// FIX: Renamed the protocol method to follow Swift convention (lower camel case)
protocol TimeSegmentSliderViewDelegate: AnyObject {
    func timeSegmentSliderView(_ view: TimeSegmentSliderView, didSelectSegmentAt index: Int)
}

class TimeSegmentSliderView: UIView {
    
    // MARK: - Properties
    weak var delegate: TimeSegmentSliderViewDelegate?
    private var currentPosition = 0
    
    private var sliderButton: UIButton!
    private var segmentLabels: [UILabel] = []
    private var countLabels: [UILabel] = []
    var titles: [String] = [] {
        didSet {
            setupSegments()
        }
    }
    // Your provided code is already correct for this part.
    var selectedIndex: Int {
        get { return currentPosition }
        set {
            guard newValue >= 0 && newValue < titles.count else { return }
            guard newValue != currentPosition else { return }
            
            currentPosition = newValue
            
            updateButtonPosition(animated: true)
            updateLabelsLayout()
            
            // FIX: Updated delegate call
            delegate?.timeSegmentSliderView(self, didSelectSegmentAt: currentPosition)
        }
    }
    
    // 设置默认颜色
    var sliderColor: UIColor = .black {
        didSet { sliderButton?.backgroundColor = sliderColor }
    }
    
    var selectedTextColor: UIColor = .black
    var normalTextColor: UIColor = .color(hexString: "#111111")
    var dividerColor: UIColor = .lightGray
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        layer.cornerRadius = 18
        clipsToBounds = true
        backgroundColor = .color(hexString: "#F7F7F7")
        
        setupSliderButton()
        setupTapGesture()
    }
    
    // MARK: 建
    private func setupSliderButton() {
        sliderButton = UIButton()
        sliderButton.backgroundColor = sliderColor
        sliderButton.layer.cornerRadius = 14
        sliderButton.isUserInteractionEnabled = false
        addSubview(sliderButton)
    }
    
    private func setupSegments() {
        // 清除旧的视图
        segmentLabels.forEach { $0.removeFromSuperview() }
        countLabels.forEach { $0.removeFromSuperview() }
        segmentLabels.removeAll()
        countLabels.removeAll()
        
        
        // 创建文字标签
        for title in titles {
            let label = UILabel()
            label.text = title
            label.font = UIFont(name: "SFCompactRounded-Bold", size: 14)
            label.textColor = normalTextColor
            label.textAlignment = .center
            addSubview(label)
            segmentLabels.append(label)
        }
        
        
        updateLabelsLayout()
        updateLayout()
    }
    
    func updateCountLabels(counts: [Int]) {
        guard counts.count == countLabels.count else { return }
        
        for (index, count) in counts.enumerated() {
            setCount(count, forSegmentAt: index)
        }
    }
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Layout
    private func updateLayout() {
        guard !titles.isEmpty else { return }
        
        let segmentWidth = bounds.width / CGFloat(titles.count)
        
        // 滑块约束
        sliderButton.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            // 宽度 = 分段宽度 - 16（左右各8，总共减去16）
            make.width.equalToSuperview().dividedBy(titles.count).offset(-16)
            make.top.equalTo(4)
            make.bottom.equalTo(-4)
            make.left.equalToSuperview().offset(CGFloat(currentPosition) * segmentWidth + 6)
        }
        
        // 文字标签约束 - 默认居中
        for (i, label) in segmentLabels.enumerated() {
            let isSelected = i == currentPosition
            
            label.snp.remakeConstraints { make in
                make.centerX.equalToSuperview().multipliedBy((CGFloat(i) * 2 + 1) / CGFloat(titles.count))
                make.width.equalTo(self).dividedBy(titles.count)
                
                if isSelected {
                    make.top.equalToSuperview().offset(8)
                } else {
                    make.centerY.equalToSuperview()
                }
            }
        }
    }
    
    // 更新标签布局（选中状态）
    private func updateLabelsLayout() {
        UIView.animate(withDuration: 0.3) {
            for (i, label) in self.segmentLabels.enumerated() {
                let isSelected = i == self.currentPosition
                
                // 更新文字颜色
                label.textColor = isSelected ? self.selectedTextColor : self.normalTextColor
                
                // 移除旧约束
                if isSelected {
                    label.snp.updateConstraints { make in
                        make.top.equalToSuperview().offset(8)
                    }
                } else {
                    label.snp.updateConstraints { make in
                        make.centerY.equalToSuperview()
                    }
                }
                //
            }
            self.layoutIfNeeded()
        }
    }
    // 设置数字标签的值
    func setCount(_ count: Int, forSegmentAt index: Int) {
        guard index >= 0 && index < countLabels.count else { return }
        countLabels[index].text = "\(count)"
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
    
    // MARK: - User Interaction
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let tapLocation = gesture.location(in: self)
        let segmentWidth = self.frame.width / CGFloat(titles.count)
        let tappedPosition = Int(tapLocation.x / segmentWidth)
        guard tappedPosition != currentPosition, tappedPosition < titles.count else { return }
        
        currentPosition = tappedPosition
        updateButtonPosition(animated: true)
        updateLabelsLayout()
        // FIX: Updated delegate call
        delegate?.timeSegmentSliderView(self, didSelectSegmentAt: currentPosition)
    }
    
    // MARK: - Animation
    private func updateButtonPosition(animated: Bool) {
        let segmentWidth = bounds.width / CGFloat(titles.count)
        let targetX = CGFloat(currentPosition) * segmentWidth
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.sliderButton.snp.updateConstraints { make in
                    make.left.equalToSuperview().offset(targetX)
                }
                self.layoutIfNeeded()
            })
        } else {
            sliderButton.snp.updateConstraints { make in
                make.left.equalToSuperview().offset(targetX)
            }
            layoutIfNeeded()
        }
    }
}
