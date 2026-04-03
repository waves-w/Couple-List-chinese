//
//  HomeViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit
import MGSwipeTableCell
import CoreData

// MARK: - 数据模型
struct Item {
    let id: String
    let title: String
    let notes: String
    let timestamp: Date // 创建时间
    let taskDate: Date // 任务日期（用户选择的日期）
    let timeString: String // 时间字符串（如 "All Day"、"14:30-16:00"）
    let isAllDay: Bool // 是否全天
    let points: Int // 分数（仅数字）
    let assignIndex: Int
    let isReminderOn: Bool // 是否开启提醒
    let isCompleted: Bool // 是否完成
}

// MARK: - HomeViewController 主体
class HomeViewController: UIViewController, MGSwipeTableCellDelegate{
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ✅ 确保在主页时 TabBar 可见（引导页结束后、从详情返回时都需显示）
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.setTabBarHidden(false)
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
    }
    var dayLabel: UILabel!
    var underdayLabel: StrokeShadowLabel!
    var underunderdayLabel: StrokeShadowLabel!
    var items: [Item] = []
    let hometableView = HomeTableViewController()
    var listener: ListenerRegistration?
    
    // Calendar
    private var calendarCollectionView: UICollectionView!
    private var dates: [Date] = []
    private var todayIndexPath: IndexPath?
    var selectedCalendarDate: Date = Calendar.current.startOfDay(for: Date())
    
    /// 过去方向：从「今天所在周」再往前加载多少整周（历史日期全部出现在日历条里；想更长可把数字调大）
    private static let calendarPastWeeksToLoad = 90
    /// 未来方向：从今天起最多再往后多少天（最后一天为「今天 + 该值」；例如 20 表示再多看 20 天）
    private static let calendarFutureDaysAfterToday = 20
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        generateDates(
            pastWeeks: Self.calendarPastWeeksToLoad,
            futureDaysAfterToday: Self.calendarFutureDaysAfterToday
        )
        setUpuI()
         
        
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
        let defaultPredicate = NSPredicate(format: "taskDate >= %@ AND taskDate < %@",
                                           startOfToday as NSDate,
                                           endOfToday as NSDate)
        hometableView.datePredicate = defaultPredicate
        // ✅ 移除 fetchAndReloadItems() 和通知监听
        // HomeTableViewController 已经通过 NSFetchedResultsController 自动监听 CoreData 变化，不需要手动刷新
        
        // ✅ 监听断开链接通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleDidUnlink),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
    }
    
    @objc private func handleCoupleDidUnlink() {
        guard isViewLoaded else { return }
        
        print("🔔 HomeViewController: 收到断开链接通知，刷新任务列表")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 刷新任务列表（NSFetchedResultsController 会自动处理数据变化）
            // 如果任务列表需要特殊处理，可以在这里添加
            if self.hometableView.isViewLoaded {
                do {
                    try self.hometableView.fetchedResultsController.performFetch()
                    self.hometableView.tableView.reloadData()
                } catch {
                    print("⚠️ HomeViewController: 刷新表格失败: \(error)")
                }
            }
            
            print("✅ HomeViewController: 断开链接UI更新完成")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // 移除 Firestore 监听器
        listener?.remove()
    }
    
    // MARK: Date Generation
    
    /// 过去：从当前周往前 `pastWeeks` 整周起，按天连续排到「今天 + futureDaysAfterToday」为止（未来不超过 20 天）
    private func generateDates(pastWeeks: Int, futureDaysAfterToday: Int) {
        dates.removeAll()
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        
        let today = calendar.startOfDay(for: Date())
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return
        }
        guard let rangeStart = calendar.date(byAdding: .weekOfYear, value: -pastWeeks, to: currentWeekStart),
              let lastDay = calendar.date(byAdding: .day, value: futureDaysAfterToday, to: today) else {
            return
        }
        
        var d = rangeStart
        while d <= lastDay {
            dates.append(d)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        
        if let index = dates.firstIndex(where: { calendar.isDate($0, equalTo: today, toGranularity: .day) }) {
            todayIndexPath = IndexPath(item: index, section: 0)
        }
    }
    
    func setUpuI() {
        view.backgroundColor = .white
        
        let inView = ViewGradientView()
        view.addSubview(inView)
        
        inView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        underunderdayLabel = StrokeShadowLabel()
        underunderdayLabel.text = "Today"
        underunderdayLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderdayLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderdayLabel.shadowBlurRadius = 1.0
//        underunderdayLabel.letterSpacing = 16.0
        underunderdayLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        view.addSubview(underunderdayLabel)
        underunderdayLabel.snp.makeConstraints { make in
            make.left.equalTo(17)
            make.topMargin.equalTo(21)
        }
        
        underdayLabel = StrokeShadowLabel()
        underdayLabel.text = "Today"
        underdayLabel.shadowColor = UIColor.black.withAlphaComponent(0.01)
        underdayLabel.shadowOffset = CGSize(width: 0, height: 2)
        underdayLabel.shadowBlurRadius = 4.0
//        underdayLabel.letterSpacing = 16.0
        underdayLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        view.addSubview(underdayLabel)
        underdayLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderdayLabel)
        }
        
        dayLabel = UILabel()
        dayLabel.text = "Today"
        dayLabel.textColor = .color(hexString: "#322D3A")
        dayLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        view.addSubview(dayLabel)
        
        dayLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderdayLabel)
        }
        
        updateDayHeaderLabels(for: selectedCalendarDate)
        
        // --- 🌟 日历视图设置 ---
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 9.2
        layout.sectionInsetReference = .fromContentInset
        
        calendarCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        calendarCollectionView.backgroundColor = .clear
        calendarCollectionView.showsHorizontalScrollIndicator = false
        calendarCollectionView.delegate = self
        calendarCollectionView.dataSource = self
        calendarCollectionView.decelerationRate = .fast
        calendarCollectionView.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.reuseIdentifier)
        calendarCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        view.addSubview(calendarCollectionView)
        
        let xxx64 = view.height() * 64.0 / 812.0
        
        calendarCollectionView.snp.makeConstraints { make in
            make.topMargin.equalTo(xxx64)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.centerX.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(48.0 / 812.0)
        }
        
        if let indexPath = todayIndexPath {
            DispatchQueue.main.async { [weak self] in
                // ✅ 移除动画，直接选中今天，不滚动
                self?.calendarCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                // ✅ 直接滚动到今天的周起始位置，不使用动画
                self?.scrollToTodayWeekStart(animated: false)
            }
        }
        
        self.addChild(hometableView)
        view.addSubview(hometableView.view)
        
        let tabBarTopInset = (tabBarController as? MomoTabBarController)?.tabBarTopInsetFromBottom() ?? 49
        hometableView.view.snp.makeConstraints { make in
            make.top.equalTo(calendarCollectionView.snp.bottom).offset(15)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.snp.bottom).offset(-tabBarTopInset)
        }
        
        hometableView.didMove(toParent: self)
    }
    
    /// 松手时根据滑动速度决定吸附到上一周/当前周/下一周，短滑即可切换
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView === calendarCollectionView else { return }
        let cv = calendarCollectionView!
        let targetX = targetContentOffset.pointee.x
        let visibleCenterX = targetX + cv.bounds.width / 2
        
        // 找到目标位置最接近的 cell，得到当前“周”
        var closestItem = 0
        var minDistance = CGFloat.greatestFiniteMagnitude
        for item in 0..<dates.count {
            guard let frame = cv.layoutAttributesForItem(at: IndexPath(item: item, section: 0))?.frame else { continue }
            let d = abs(frame.midX - visibleCenterX)
            if d < minDistance { minDistance = d; closestItem = item }
        }
        var weekStartItem = closestItem - (closestItem % 7)
        
        // 速度超过阈值则按方向切到下一周/上一周，短滑即可切换
        let velocityThreshold: CGFloat = 0.2
        if velocity.x > velocityThreshold {
            weekStartItem = min(weekStartItem + 7, dates.count - 1)
            weekStartItem = weekStartItem - (weekStartItem % 7)
        } else if velocity.x < -velocityThreshold {
            weekStartItem = max(weekStartItem - 7, 0)
        }
        weekStartItem = max(0, min(weekStartItem, dates.count - 1))
        
        guard let weekFrame = cv.layoutAttributesForItem(at: IndexPath(item: weekStartItem, section: 0))?.frame else { return }
        var offset = weekFrame.origin.x
        let maxOffset = cv.contentSize.width - cv.bounds.width
        offset = max(0, min(offset, maxOffset))
        targetContentOffset.pointee.x = offset
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === calendarCollectionView else { return }
        nearestWeek()
    }
    
    /// 拖拽结束且不减速时吸附
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView === calendarCollectionView, !decelerate else { return }
        nearestWeek()
    }
    
    /// 滚动到今天所在周的起始位置（用于初始化，无动画）
    private func scrollToTodayWeekStart(animated: Bool) {
        guard let indexPath = todayIndexPath else { return }
        let todayItem = indexPath.item
        let weekStartItem = todayItem - (todayItem % 7)
        guard weekStartItem >= 0, weekStartItem < dates.count else { return }
        let weekStartIndexPath = IndexPath(item: weekStartItem, section: 0)
        
        // 滚动到周起始位置
        calendarCollectionView.scrollToItem(
            at: weekStartIndexPath,
            at: .left,
            animated: animated
        )
    }
    
    /// 吸附到最近的周起始位置核心逻辑
    private func nearestWeek() {
        let visibleRect = CGRect(origin: calendarCollectionView.contentOffset, size: calendarCollectionView.bounds.size)
        let visibleCenterX = visibleRect.midX
        
        // 找到可见区域中最接近中心的单元格
        var closestItem = 0
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        for item in 0..<dates.count {
            let indexPath = IndexPath(item: item, section: 0)
            guard let cellFrame = calendarCollectionView.layoutAttributesForItem(at: indexPath)?.frame else { continue }
            let distance = abs(cellFrame.midX - visibleCenterX)
            if distance < minDistance {
                minDistance = distance
                closestItem = item
            }
        }
        
        // 计算该单元格所在周的起始位置
        let weekStartItem = closestItem - (closestItem % 7)
        guard weekStartItem >= 0, weekStartItem < dates.count else { return }
        let weekStartIndexPath = IndexPath(item: weekStartItem, section: 0)
        
        // 滚动并吸附
        calendarCollectionView.scrollToItem(
            at: weekStartIndexPath,
            at: .left,
            animated: true
        )
    }
    
    func addNewItem(
        title: String,
        notes: String,
        taskDate: Date, // 用户选择的任务日期
        timeString: String, // 时间字符串
        isAllDay: Bool, // 是否全天
        points: Int, // 分数（仅数字）
        assignIndex: Int,
        isReminderOn: Bool // 是否开启提醒
    ) {
        // ✅ 只保存到 Core Data，Firebase 同步由 DbManager.handleContextDidSave 自动处理
        // ✅ 这样可以避免重复上传导致另一个手机上任务被添加两次
        guard let localModel = DbManager.manager.addModel(
            titleLabel: title,
            notesLabel: notes,
            taskDate: taskDate,
            timeString: timeString,
            isAllDay: isAllDay,
            points: points,
            assignIndex: assignIndex,
            isReminderOn: isReminderOn
        ) else {
            print("❌ Failed to save item to Core Data.")
            return
        }
        
        print("✅ Item \(localModel.id ?? "unknown") saved to Core Data. Firebase sync will be handled automatically by DbManager.")
        
        // ✅ 移除手动上传到 Firebase 的代码，避免重复上传
        // ✅ DbManager.handleContextDidSave 会自动监听 CoreData 变化并同步到 Firebase
        // ✅ HomeTableViewController 已经通过 NSFetchedResultsController 自动监听 CoreData 变化，会自动更新 UI
    }
    
    /// 根据选中日期更新顶部标题：Today / Yesterday / Tomorrow /「Mar 13」
    private func updateDayHeaderLabels(for date: Date) {
        let title = Self.dayHeaderTitle(for: date)
        underunderdayLabel.text = title
        underdayLabel.text = title
        dayLabel.text = title
    }
    
    private static func dayHeaderTitle(for date: Date) -> String {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: Date())
        if cal.isDate(day, inSameDayAs: today) {
            return "Today"
        }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
           cal.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: today),
           cal.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: day)
    }
}

extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.reuseIdentifier, for: indexPath) as? CalendarDayCell else {
            // ✅ 改为返回默认 cell 而不是 fatalError，避免崩溃
            print("❌ 无法获取 CalendarDayCell，返回默认 cell")
            return UICollectionViewCell()
        }
        let date = dates[indexPath.item]
        let isToday = (indexPath == todayIndexPath)
        cell.configure(with: date, isToday: isToday)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // ✅ 使用安全的可选绑定，避免强制解包导致崩溃
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            print("❌ 无法获取 UICollectionViewFlowLayout，返回默认大小")
            return CGSize(width: 50, height: 50)
        }
        let totalSpacing = layout.minimumLineSpacing * 6 // 7个单元格有6个间距
        let totalCellWidth = collectionView.bounds.width - totalSpacing // 可用宽度 = 集合视图宽度 - 总间距
        let cellWidth = totalCellWidth / 7 // 平分7列，确保一周刚好占满集合视图宽度
        let cellHeight = collectionView.bounds.height // 高度与集合视图一致
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        let selectedDate = dates[indexPath.item]
        
        // 1. 更新选中日期（取当天的开始时间）
        selectedCalendarDate = Calendar.current.startOfDay(for: selectedDate)
        updateDayHeaderLabels(for: selectedCalendarDate)
        
        // 2. 计算日期范围：当天 00:00:00 到 23:59:59
        let startOfDay = selectedCalendarDate
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            .addingTimeInterval(-1) // 减 1 秒，确保是当天结束
        
        // 3. 创建日期过滤 predicate：taskDate 在 [startOfDay, endOfDay] 之间
        let datePredicate = NSPredicate(format: "taskDate >= %@ AND taskDate <= %@", startOfDay as CVarArg, endOfDay as CVarArg)
        
        // 4. 传递 predicate 给 HomeTableViewController，触发数据刷新
        hometableView.datePredicate = datePredicate
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? CalendarDayCell {
            cell.isSelected = false
        }
    }
}
