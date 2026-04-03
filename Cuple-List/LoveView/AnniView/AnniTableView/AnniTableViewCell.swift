//
//  AnniTableViewCell.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import CoreData
import MagicalRecord
import ReactiveSwift

class AnniTableViewCell: UITableViewCell {
    
    var middleImageLabel: UILabel!
    var titleLabel: UILabel!
    var targetLabel: UILabel!
    var daysLabel: UILabel!
    var underdaysLabel: StrokeShadowLabel!
    var underunderdaysLabel: StrokeShadowLabel!
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUI() {
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        let viewcontentView = BorderGradientView()
        viewcontentView.layer.cornerRadius = 18
        contentView.addSubview(viewcontentView)
        
        let verticalSpacing: CGFloat = 12.0
        let horizontalPadding: CGFloat = 20.0
        
        viewcontentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(verticalSpacing / 2)
            make.bottom.equalToSuperview().offset(-verticalSpacing / 2)
            make.left.equalToSuperview().offset(horizontalPadding)
            make.right.equalToSuperview().offset(-horizontalPadding)
        }
        
        middleImageLabel = UILabel()
        middleImageLabel.font = UIFont.systemFont(ofSize: 28)
        viewcontentView.addSubview(middleImageLabel)
        
        middleImageLabel.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
        }
        
        titleLabel = UILabel()
        titleLabel.textColor = .color(hexString: "#322D3A")
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        viewcontentView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(12)
            make.leading.equalTo(middleImageLabel.snp.trailing).offset(12)
        }
        
        targetLabel = UILabel()
        targetLabel.textColor = .color(hexString: "#999DAB")
        targetLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        viewcontentView.addSubview(targetLabel)
        
        targetLabel.snp.makeConstraints { make in
            make.left.equalTo(middleImageLabel.snp.right).offset(12)
            make.bottom.equalTo(-12)
        }
        
        let dayLabel = UILabel()
        dayLabel.text = "day"
        dayLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        dayLabel.textColor = .color(hexString: "#999DAB")
        viewcontentView.addSubview(dayLabel)
        
        dayLabel.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.centerY.equalToSuperview()
        }
        
        underunderdaysLabel = StrokeShadowLabel()
        underunderdaysLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderdaysLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderdaysLabel.shadowBlurRadius = 1.0
        underunderdaysLabel.text = "00000"
        underunderdaysLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)!
        
        viewcontentView.addSubview(underunderdaysLabel)
        
        // ✅ 增加右边距，给阴影留出足够空间（shadowBlurRadius = 5.0 需要约 10 像素空间）
        underunderdaysLabel.snp.makeConstraints { make in
            make.right.equalTo(-36)
            make.centerY.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.trailing.lessThanOrEqualTo(underunderdaysLabel.snp.leading)
        }
        
        underdaysLabel = StrokeShadowLabel()
        underdaysLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        underdaysLabel.shadowOffset = CGSize(width: 0, height: 1)
        underdaysLabel.shadowBlurRadius = 5.0
        underdaysLabel.text = "00000"
        underdaysLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)!
        
        viewcontentView.addSubview(underdaysLabel)
        
        underdaysLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderdaysLabel)
        }
        
        daysLabel = UILabel()
        daysLabel.textColor = .color(hexString: "#322D3A")
        daysLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)
        viewcontentView.addSubview(daysLabel)
        
        daysLabel.snp.makeConstraints { make in
            make.center.equalTo(underdaysLabel)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        targetLabel.text = nil
        daysLabel.text = nil
        self.backgroundColor = .clear
    }
    
    // MARK: ✅ 适配重复逻辑 - 单元格赋值核心方法
    func configure(with anniModel: AnniModel) {
        self.titleLabel.text = anniModel.titleLabel
        self.middleImageLabel.text = anniModel.wishImage
        guard let originalDate = anniModel.targetDate else {
            self.targetLabel.text = "未设置日期"
            return
        }
        
        // 计算最终目标日期+【绝对间隔天数】
        let finalDate = getFinalTargetDate(for: anniModel)
        let absDays = AnniDateCalculator.shared.calculateAbsDaysInterval(targetDate: finalDate)
        let daysText = AnniDateCalculator.shared.formatDays(absDays)
        let datePrefix = getDatePrefix(for: finalDate)
        
        // 赋值UI
        self.targetLabel.text = "\(datePrefix) : \(AnniTableViewCell.dateFormatter.string(from: finalDate))"
        self.underunderdaysLabel.text = daysText
        self.underdaysLabel.text = daysText
        self.daysLabel.text = daysText
    }
    
    // MARK: ✅ 单元格内计算最终目标日期
    private func getFinalTargetDate(for model: AnniModel) -> Date {
        guard let originalDate = model.targetDate,
              let repeatText = model.repeatDate,
              repeatText != "Never" else {
            return model.targetDate ?? Date()
        }
        return AnniDateCalculator.shared.calculateNextTargetDate(originalDate: originalDate, repeatText: repeatText)
    }
    
    // MARK: ✅ 单元格内日期前缀
    private func getDatePrefix(for targetDate: Date) -> String {
        let current = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        let cmp = Calendar.current.compare(target, to: current, toGranularity: .day)
        
        switch cmp {
        case .orderedAscending: return "Start Date"
        case .orderedDescending: return "Target Date"
        case .orderedSame: return "Today"
        @unknown default: return "日期"
        }
    }
}
