//
//  CalendarView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

//选中的日期
protocol CalendarViewDelegate: AnyObject {
    func didSelectDate(_ date: Date)
}

class CalendarView: UIView {
    
    weak var delegate: CalendarViewDelegate?//代理属性
    
    // UI Elements
    private let headerView = UIView()
    private let monthYearButton = UIButton(type: .system)
    private let previousMonthButton = UIButton(type: .system)
    private let nextMonthButton = UIButton(type: .system)
    private let weekdayStackView = UIStackView()
    private let dayCollectionView: UICollectionView
    
    // Data/State
    private var currentMonth: Date = Date()
    private var selectedDate: Date? = Date()
    private let calendar = Calendar.current
    private var daysInMonth: [Date?] = []
    
    // Configuration
    private let cellIdentifier = "DayCell"
    private var yearMonthPopup: YearMonthWheelPopup?

    override init(frame: CGRect) {
        // Setup UICollectionViewFlowLayout
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 7
        layout.minimumInteritemSpacing = 0
        dayCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        
        setupUI()
        configureDayCollectionView()
        calculateMonthDates()
        updateMonthYearDisplay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // 1. Header (Month/Year, Prev/Next Buttons)
        addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(40)
        }
        
        // Month/Year Button (For selection)
        monthYearButton.setTitleColor(.color(hexString: "#111111"), for: .normal)
        monthYearButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Semibold", size: 17)
        monthYearButton.addTarget(self, action: #selector(monthYearTapped), for: .touchUpInside)
        headerView.addSubview(monthYearButton)
        monthYearButton.snp.makeConstraints { make in
            make.top.equalTo(13)
            make.left.equalTo(16)
            
        }
        
        // Next Month Button
        nextMonthButton.setTitle("􀆊", for: .normal)
        nextMonthButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Medium", size: 20)
        nextMonthButton.addTarget(self, action: #selector(goToNextMonth), for: .touchUpInside)
        headerView.addSubview(nextMonthButton)
        nextMonthButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-18)
            make.height.equalTo(24)
            make.width.equalTo(15)
        }
        
        // Previous Month Button
        previousMonthButton.setTitle("􀆉", for: .normal)
        previousMonthButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Medium", size: 20)
        previousMonthButton.addTarget(self, action: #selector(goToPreviousMonth), for: .touchUpInside)
        headerView.addSubview(previousMonthButton)
        previousMonthButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.height.equalTo(24)
            make.width.equalTo(15)
            make.right.equalTo(nextMonthButton.snp.left).offset(-26)
        }
        
        addSubview(weekdayStackView)
        weekdayStackView.distribution = .fillEqually
        weekdayStackView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.width.equalToSuperview()
            make.height.equalTo(20)
        }
        
        
        
        let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        for day in weekdays {
            let label = UILabel()
            label.text = day
            label.textAlignment = .center
            label.font = UIFont(name: "SFCompactRounded-Semibold", size: 13)
            label.textColor = .color(hexString: "#3C3C43").withAlphaComponent(0.3)
            weekdayStackView.addArrangedSubview(label)
            
            label.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
            }
        }
        
        
        addSubview(dayCollectionView)
        dayCollectionView.backgroundColor = .clear
        dayCollectionView.snp.makeConstraints { make in
            make.top.equalTo(weekdayStackView.snp.bottom).offset(3)
            make.bottom.equalToSuperview()
            make.width.equalToSuperview()
        }
    }
    
    private func configureDayCollectionView() {
        dayCollectionView.delegate = self
        dayCollectionView.dataSource = self
        dayCollectionView.register(DayCell.self, forCellWithReuseIdentifier: cellIdentifier)
    }
    
    // MARK: - Calendar Logic
    
    private func updateMonthYearDisplay() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        monthYearButton.setTitle(formatter.string(from: currentMonth), for: .normal)
    }
    
    private func calculateMonthDates() {
        daysInMonth.removeAll()
        
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let firstWeekday = calendar.dateComponents([.weekday], from: startOfMonth).weekday else { return }
        
        let paddingDays = firstWeekday - 1
        
        // Add nil for padding days
        for _ in 0..<paddingDays {
            daysInMonth.append(nil)
        }
        
        // Add actual days of the month
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                daysInMonth.append(date)
            }
        }
        
        dayCollectionView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func goToPreviousMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) else { return }
        currentMonth = newMonth
        calculateMonthDates()
        updateMonthYearDisplay()
    }
    
    @objc private func goToNextMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return }
        currentMonth = newMonth
        calculateMonthDates()
        updateMonthYearDisplay()
    }
    
    @objc private func monthYearTapped() {
        let currentYear = calendar.component(.year, from: currentMonth)
        let currentMonthIndex = calendar.component(.month, from: currentMonth)
        let width = window?.bounds.width ?? UIScreen.main.bounds.width
        let bottomSpacing: CGFloat = 34
        let pop = YearMonthWheelPopup()
        pop.onSelected = { [weak self] year, month in
            guard let self = self else { return }
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            if let newMonth = self.calendar.date(from: comps) {
                self.currentMonth = newMonth
                self.calculateMonthDates()
                self.updateMonthYearDisplay()
            }
            self.yearMonthPopup = nil
        }
        yearMonthPopup = pop
        pop.show(width: width, bottomSpacing: bottomSpacing, selectedYear: currentYear, selectedMonth: currentMonthIndex)
    }
    
    /// 获取用于 present 的 ViewController：先走响应链，找不到则用 keyWindow 顶层 VC（弹窗内时响应链常无 VC）
    private var viewController: UIViewController? {
        var next = self.next
        while let n = next {
            if let vc = n as? UIViewController { return vc }
            next = n.next
        }
        // 弹窗 content 可能不在任何 VC 的 view 层级里，用 keyWindow 的顶层 VC
        guard let window = self.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow }) else { return nil }
        var vc = window.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
    
    // ✅ 新增：设置初始选中日期（用于生日选择等场景）
    func setInitialDate(_ date: Date) {
        selectedDate = date
        // ✅ 设置当前月份为该日期所在的月份
        let components = calendar.dateComponents([.year, .month], from: date)
        if let monthDate = calendar.date(from: components) {
            currentMonth = monthDate
            calculateMonthDates()
            updateMonthYearDisplay()
            dayCollectionView.reloadData()
        }
    }
}

// MARK: - UICollectionViewDataSource, Delegate, FlowLayout

extension CalendarView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return daysInMonth.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // ✅ 使用安全的可选绑定，避免强制解包导致崩溃
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? DayCell else {
            print("❌ 无法获取 DayCell，返回默认 cell")
            return UICollectionViewCell()
        }
        
        if let date = daysInMonth[indexPath.item] {
            let day = calendar.component(.day, from: date)
            cell.configure(day: day, date: date, selectedDate: selectedDate, currentMonth: currentMonth)
        } else {
            cell.configureAsEmpty()
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let date = daysInMonth[indexPath.item] else { return }
        
        selectedDate = date
        delegate?.didSelectDate(date)
        collectionView.reloadData()
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / 7
        let height: CGFloat = 44
        return CGSize(width: width, height: height)
    }
}


// MARK: - DayCell Implementation

class DayCell: UICollectionViewCell {
    
    private let dateLabel = UILabel()
    private let todayIndicator = UIView() // For current day circle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        // Indicator for selection/today (background)
        contentView.addSubview(todayIndicator)
        todayIndicator.backgroundColor = .clear
        todayIndicator.layer.cornerRadius = 22
        todayIndicator.clipsToBounds = true
        todayIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(44)
        }
        
        // Date Label
        dateLabel.textAlignment = .center
        dateLabel.font = UIFont(name: "SFCompactRounded-Regular", size: 20)
        contentView.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    func configureAsEmpty() {
        dateLabel.text = nil
        dateLabel.textColor = .clear
        todayIndicator.backgroundColor = .clear
    }
    
    func configure(day: Int, date: Date, selectedDate: Date?, currentMonth: Date) {
        dateLabel.text = "\(day)"
        
        let today = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, equalTo: selectedDate ?? Date(), toGranularity: .day)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
        
        // 1. Selection & Today Background
        if isSelected {
            // Selected: Blue background, Blue text
            todayIndicator.backgroundColor = .color(hexString: "#0088FF").withAlphaComponent(0.12)
            dateLabel.textColor = .color(hexString: "#0088FF")
            
        } else if today && isCurrentMonth {
            // Today (not selected): Blue text, no background
            todayIndicator.backgroundColor = .clear
            dateLabel.textColor = .color(hexString: "#0088FF")
            
        } else {
            todayIndicator.backgroundColor = .clear
            dateLabel.textColor = .color(hexString: "#000000")
        }
        
        // Gray out days not in the current visible month
        if !isCurrentMonth && !isSelected {
            dateLabel.textColor = .color(hexString: "#A9A9A9")
        }
    }
}

