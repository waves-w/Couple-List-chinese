//
//  CalendarDayCell.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class CalendarDayCell: UICollectionViewCell {
    
    static let reuseIdentifier = "CalendarDayCell"
    let dateView = CalendarBorderGradientView()
    let dayLabel = UILabel()
    let weekLabel = UILabel()
    
    private var isCurrentDay: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.layer.cornerRadius = 12
        contentView.addSubview(dateView)
        dateView.layer.cornerRadius = 12
        dateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dateView.isHidden = true
        
        dayLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        dayLabel.textAlignment = .center
        
        weekLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 12)
        weekLabel.textAlignment = .center
        
        let stackView = UIStackView(arrangedSubviews: [dayLabel, weekLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 1
        
        contentView.addSubview(stackView)
        // 适配周单位滑动的单元格宽度，调整内边距
        stackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
    
    // 选中状态变化时更新 UI
    override var isSelected: Bool {
        didSet {
            let selectedBgColor = UIColor.color(hexString: "#FFFFFF") // 选中背景色
            let selectedTextColor = UIColor.color(hexString: "#322D3A") // 选中文字色
            
            let todayTextColor = UIColor.systemRed // 今日文字色
            let normalTextColor = UIColor.color(hexString: "#322D3A") // 普通日期文字色
            let normalWeekColor = UIColor.color(hexString: "#A097B9") // 普通星期文字色
            
            if isSelected {
                // 状态 1: 选中 (覆盖今天/非今天状态)
                dateView.isHidden = false
                contentView.backgroundColor = selectedBgColor
                dayLabel.textColor = selectedTextColor
                weekLabel.textColor = selectedTextColor
            } else if isCurrentDay {
                // 状态 2: 非选中，但今天是今天 (背景透明，文本红色)
                dateView.isHidden = true
                contentView.backgroundColor = .clear
                dayLabel.textColor = todayTextColor
                weekLabel.textColor = todayTextColor
            } else {
                dateView.isHidden = true
                contentView.backgroundColor = .clear
                dayLabel.textColor = normalTextColor
                weekLabel.textColor = normalWeekColor
            }
        }
    }
    
    func configure(with date: Date, isToday: Bool) {
        self.isCurrentDay = isToday
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd"
        dayLabel.text = dayFormatter.string(from: date)
        
        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "EEE"
        // 转为全大写
        let weekText = weekFormatter.string(from: date).uppercased()
        weekLabel.text = weekText
        
        isSelected = isToday
    }
}
