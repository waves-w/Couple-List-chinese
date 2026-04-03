//
//  BreakdownViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class BreakdownViewController: UIViewController {
    
    var backButton: UIButton!
    var breakLabel: UILabel!
    var filterButton: UIButton!
    var breakdowntableView: BorderGradientView!
    var tableView: UITableView!
    let filterPopup = FilterPopup()
    
    // 数据源
    private var allRecords: [ScoreRecordModel] = []
    private var filteredRecords: [ScoreRecordModel] = []
    
    // 筛选条件
    private var filterView: FilterViewType = .all // all, partner, oneself
    private var filterStatus: FilterStatusType = .all // all, completed, overdue
    private var filterTime: FilterTimeType = .newest // newest, oldest
    
    // ✅ 新增：按任务ID筛选（只显示单条任务的记录）
    private var filterTaskId: String? = nil
    
    // ✅ 防重复加载和性能优化
    private var isRecordsLoading = false
    private var pendingLoadWorkItem: DispatchWorkItem? // ✅ 用于取消延迟任务
    
    // ✅ 便利初始化方法：可以传入任务ID，只显示该任务的记录
    convenience init(taskId: String?) {
        self.init()
        self.filterTaskId = taskId
    }
    
    enum FilterViewType {
        case all, partner, oneself
    }
    
    enum FilterStatusType {
        case all, completed, overdue
    }
    
    enum FilterTimeType {
        case newest, oldest
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = true
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = true
                tabBarController.homeAddButton?.isHidden = true
            }
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
        loadAllScoreRecords()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = false
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = false
                tabBarController.homeAddButton?.isHidden = false
            }
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        setupTableView()
        
        // ✅ 延迟加载，避免在视图还没完全初始化时加载数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadAllScoreRecords()
        }
        
        // 监听分数更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: ScoreDidUpdateNotification,
            object: nil
        )
        
        // ✅ 不监听 DbManager.dataDidUpdateNotification，避免与本地操作冲突导致用户数据搞反
    }
    
    deinit {
        // ✅ 取消所有待执行的延迟任务（防止内存泄漏）
        pendingLoadWorkItem?.cancel()
        pendingLoadWorkItem = nil
        
        // ✅ 移除通知观察者
        NotificationCenter.default.removeObserver(self)
        
        print("✅ BreakdownViewController 已释放")
    }
    
    
    func setUI() {
        
        view.backgroundColor = .white
        
        let backView = ViewGradientView()
        view.addSubview(backView)
        
        backView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backButton = UIButton()
        backButton.setImage(UIImage(named: "breakback"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        breakLabel = UILabel()
        breakLabel.text = "Breakdown"
        breakLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
        breakLabel.textColor = .color(hexString: "#322D3A")
        view.addSubview(breakLabel)
        
        breakLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        
        filterButton = UIButton()
        filterButton.setImage(UIImage(named: "filterButton"), for: .normal)
        filterButton.addTarget(self, action: #selector(showdFilter), for: .touchUpInside)
        view.addSubview(filterButton)
        
        filterButton.snp.makeConstraints { make in
            make.right.equalTo(-20)
            make.centerY.equalTo(breakLabel)
        }
        
        // 设置 FilterPopup 的回调
        setupFilterPopup()
    }
    
    // ✅ 设置表格视图
    private func setupTableView() {
        
        breakdowntableView = BorderGradientView()
        breakdowntableView.layer.cornerRadius = 18
        view.addSubview(breakdowntableView)
        
        breakdowntableView.snp.makeConstraints { make in
            make.top.equalTo(breakLabel.snp.bottom).offset(21)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.height.equalTo(100)
            // ✅ 移除底部约束，避免产生额外空白
        }
        
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.isScrollEnabled = false // ✅ 禁用滚动，让表格根据内容自适应高度
        tableView.contentInset = .zero
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        
        // ✅ 注册cell复用标识符（提升性能）
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ScoreRecordCell")
        tableView.rowHeight = 82
        
        breakdowntableView.addSubview(tableView)
        
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // ✅ 更新 breakdowntableView 的高度（根据表格内容）
    private func updateTableViewHeight() {
        guard breakdowntableView != nil else { return }
        
        // ✅ 计算表格内容高度
        let rowCount = filteredRecords.count
        let rowHeight: CGFloat = 82
        let separatorHeight: CGFloat = 1 // 分隔线高度
        let separatorSpacing: CGFloat = 10 // 分隔线间距
        let minHeight: CGFloat = 82
        
        // ✅ 修复：正确计算包含分隔线的实际内容高度
        // 每行高度是 82，非最后一行有分隔线（高度1 + 间距10），最后一行没有分隔线
        let contentHeight: CGFloat
        if rowCount == 0 {
            contentHeight = minHeight // 至少显示最小高度
        } else if rowCount == 1 {
            contentHeight = rowHeight // 只有一行，没有分隔线
        } else {
            // 多行：最后一行82，前面的行每行82+分隔线(1+10)
            contentHeight = CGFloat(rowCount - 1) * (rowHeight + separatorSpacing + separatorHeight) + rowHeight
        }
        
        // ✅ 修复：移除额外的24内边距，使用精确的内容高度
        let totalHeight = max(contentHeight, minHeight)
        
        // ✅ 更新 breakdowntableView 的高度约束
        breakdowntableView.snp.updateConstraints { make in
            make.height.equalTo(totalHeight)
        }
        
        // ✅ 强制布局更新（使用动画让变化更平滑）
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    // ✅ 加载所有分数记录（带防重复加载）
    private func loadAllScoreRecords() {
        // ✅ 防重复加载
        guard !isRecordsLoading else {
            print("⚠️ BreakdownViewController: 正在加载中，跳过")
            return
        }
        
        isRecordsLoading = true
        let currentUserId = CoupleStatusManager.getUserUniqueUUID()
        
        // ✅ 先尝试从 Firebase 获取数据
        ScoreManager.shared.getAllScoreRecords { [weak self] records in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isRecordsLoading = false
                
                // ✅ 如果 Firebase 返回空数据（可能是连接不上），使用本地测试数据
                if records.isEmpty {
                    print("⚠️ BreakdownViewController: Firebase 数据为空，从 CoreData 生成测试数据（带去重检查）")
                    // ✅ 再次尝试获取一次数据（检查缓存中是否有之前的数据）
                    ScoreManager.shared.getAllScoreRecords { [weak self] cachedRecords in
                        guard let self = self else { return }
                        // ✅ 使用缓存中的记录进行去重检查（即使 Firebase 连接不上，缓存中可能也有之前的数据）
                        self.generateTestRecordsFromCoreData(existingRecords: cachedRecords) { [weak self] testRecords in
                            guard let self = self else { return }
                            if testRecords.isEmpty {
                                print("⚠️ BreakdownViewController: CoreData 也没有数据，显示空列表")
                            } else {
                                print("✅ BreakdownViewController: 成功生成 \(testRecords.count) 条测试记录（已去重，缓存中有 \(cachedRecords.count) 条记录）")
                            }
                            self.allRecords = testRecords
                            self.applyFilters()
                            // ✅ 更新表格容器高度
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                self.updateTableViewHeight()
                            }
                        }
                    }
                } else {
                    print("✅ BreakdownViewController: 从 Firebase 获取到 \(records.count) 条记录")
                    self.allRecords = records
                    self.applyFilters()
                }
            }
        }
    }
    
    // ✅ 从 CoreData 生成测试数据（用于 Firebase 连接不上时的测试，带去重检查）
    private func generateTestRecordsFromCoreData(existingRecords: [ScoreRecordModel], completion: @escaping ([ScoreRecordModel]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion([])
                return
            }
            
            let allTasks = DbManager.manager.fetchListModels()
            var testRecords: [ScoreRecordModel] = []
            
            let currentUserId = CoupleStatusManager.getUserUniqueUUID()
            let (_, partnerUser) = UserManger.manager.getCoupleUsers()
            let partnerUserId = partnerUser?.id ?? ""
            let coupleId = CoupleStatusManager.getPartnerId() ?? ""
            
            // ✅ 创建现有记录的快速查找集合（基于 taskId + targetUserId + score + isOnTime）
            // 这样可以避免生成重复的记录
            let existingRecordKeys = Set(existingRecords.map { record in
                "\(record.taskId)_\(record.targetUserId)_\(record.score)_\(record.isOnTime)"
            })
            
            for task in allTasks {
                guard let taskId = task.id,
                      task.points > 0 else {
                    continue
                }
                
                let assignIndex = Int(task.assignIndex)
                let taskScore = Int(task.points)
                let taskDate = task.taskDate ?? Date()
                let isCompleted = task.isCompleted
                
                // ✅ 根据任务完成状态和分配类型生成记录
                if isCompleted {
                    // 已完成：生成加分记录
                    let finishTime = taskDate.addingTimeInterval(-3600) // 假设提前1小时完成
                    let isOnTime = finishTime <= taskDate
                    let finalScore = isOnTime ? taskScore : -taskScore
                    
                    switch assignIndex {
                    case TaskAssignIndex.partner.rawValue: // 0 = 给对方
                        if !partnerUserId.isEmpty {
                            // ✅ 检查是否已存在相同的记录
                            let recordKey = "\(taskId)_\(partnerUserId)_\(finalScore)_\(isOnTime)"
                            if !existingRecordKeys.contains(recordKey) {
                                let record = createTestRecord(
                                    taskId: taskId,
                                    taskTitle: task.titleLabel ?? "未命名任务",
                                    taskNotes: task.notesLabel ?? "",
                                    taskSetTime: taskDate,
                                    taskFinishTime: finishTime,
                                    targetUserId: partnerUserId,
                                    score: finalScore,
                                    isOnTime: isOnTime,
                                    coupleId: coupleId
                                )
                                testRecords.append(record)
                            }
                        }
                    case TaskAssignIndex.myself.rawValue: // 1 = 给自己
                        // ✅ 检查是否已存在相同的记录
                        let recordKey = "\(taskId)_\(currentUserId)_\(finalScore)_\(isOnTime)"
                        if !existingRecordKeys.contains(recordKey) {
                            let record = createTestRecord(
                                taskId: taskId,
                                taskTitle: task.titleLabel ?? "未命名任务",
                                taskNotes: task.notesLabel ?? "",
                                taskSetTime: taskDate,
                                taskFinishTime: finishTime,
                                targetUserId: currentUserId,
                                score: finalScore,
                                isOnTime: isOnTime,
                                coupleId: coupleId
                            )
                            testRecords.append(record)
                        }
                    case TaskAssignIndex.both.rawValue: // 2 = 双方
                        // 给自己
                        let myRecordKey = "\(taskId)_\(currentUserId)_\(finalScore)_\(isOnTime)"
                        if !existingRecordKeys.contains(myRecordKey) {
                            let myRecord = createTestRecord(
                                taskId: taskId,
                                taskTitle: task.titleLabel ?? "未命名任务",
                                taskNotes: task.notesLabel ?? "",
                                taskSetTime: taskDate,
                                taskFinishTime: finishTime,
                                targetUserId: currentUserId,
                                score: finalScore,
                                isOnTime: isOnTime,
                                coupleId: coupleId
                            )
                            testRecords.append(myRecord)
                        }
                        // 给对方
                        if !partnerUserId.isEmpty {
                            let partnerRecordKey = "\(taskId)_\(partnerUserId)_\(finalScore)_\(isOnTime)"
                            if !existingRecordKeys.contains(partnerRecordKey) {
                                let partnerRecord = createTestRecord(
                                    taskId: taskId,
                                    taskTitle: task.titleLabel ?? "未命名任务",
                                    taskNotes: task.notesLabel ?? "",
                                    taskSetTime: taskDate,
                                    taskFinishTime: finishTime,
                                    targetUserId: partnerUserId,
                                    score: finalScore,
                                    isOnTime: isOnTime,
                                    coupleId: coupleId
                                )
                                testRecords.append(partnerRecord)
                            }
                        }
                    default:
                        break
                    }
                } else {
                    // 未完成但逾期：生成扣分记录
                    let currentDate = Date()
                    if currentDate > taskDate {
                        let finalScore = -taskScore
                        
                        switch assignIndex {
                        case TaskAssignIndex.partner.rawValue: // 0 = 给对方
                            if !partnerUserId.isEmpty {
                                // ✅ 检查是否已存在相同的记录
                                let recordKey = "\(taskId)_\(partnerUserId)_\(finalScore)_false"
                                if !existingRecordKeys.contains(recordKey) {
                                    let record = createTestRecord(
                                        taskId: taskId,
                                        taskTitle: task.titleLabel ?? "未命名任务",
                                        taskNotes: task.notesLabel ?? "",
                                        taskSetTime: taskDate,
                                        taskFinishTime: currentDate,
                                        targetUserId: partnerUserId,
                                        score: finalScore,
                                        isOnTime: false,
                                        coupleId: coupleId
                                    )
                                    testRecords.append(record)
                                }
                            }
                        case TaskAssignIndex.myself.rawValue: // 1 = 给自己
                            // ✅ 检查是否已存在相同的记录
                            let recordKey = "\(taskId)_\(currentUserId)_\(finalScore)_false"
                            if !existingRecordKeys.contains(recordKey) {
                                let record = createTestRecord(
                                    taskId: taskId,
                                    taskTitle: task.titleLabel ?? "未命名任务",
                                    taskNotes: task.notesLabel ?? "",
                                    taskSetTime: taskDate,
                                    taskFinishTime: currentDate,
                                    targetUserId: currentUserId,
                                    score: finalScore,
                                    isOnTime: false,
                                    coupleId: coupleId
                                )
                                testRecords.append(record)
                            }
                        case TaskAssignIndex.both.rawValue: // 2 = 双方
                            // 给自己
                            let myRecordKey = "\(taskId)_\(currentUserId)_\(finalScore)_false"
                            if !existingRecordKeys.contains(myRecordKey) {
                                let myRecord = createTestRecord(
                                    taskId: taskId,
                                    taskTitle: task.titleLabel ?? "未命名任务",
                                    taskNotes: task.notesLabel ?? "",
                                    taskSetTime: taskDate,
                                    taskFinishTime: currentDate,
                                    targetUserId: currentUserId,
                                    score: finalScore,
                                    isOnTime: false,
                                    coupleId: coupleId
                                )
                                testRecords.append(myRecord)
                            }
                            // 给对方
                            if !partnerUserId.isEmpty {
                                let partnerRecordKey = "\(taskId)_\(partnerUserId)_\(finalScore)_false"
                                if !existingRecordKeys.contains(partnerRecordKey) {
                                    let partnerRecord = createTestRecord(
                                        taskId: taskId,
                                        taskTitle: task.titleLabel ?? "未命名任务",
                                        taskNotes: task.notesLabel ?? "",
                                        taskSetTime: taskDate,
                                        taskFinishTime: currentDate,
                                        targetUserId: partnerUserId,
                                        score: finalScore,
                                        isOnTime: false,
                                        coupleId: coupleId
                                    )
                                    testRecords.append(partnerRecord)
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
            
            // ✅ 按创建时间倒序排序
            testRecords.sort { $0.createTime > $1.createTime }
            
            // ✅ 在主线程返回结果
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    completion([])
                    return
                }
                completion(testRecords)
            }
        }
    }
    
    // ✅ 创建测试记录
    private func createTestRecord(
        taskId: String,
        taskTitle: String,
        taskNotes: String,
        taskSetTime: Date,
        taskFinishTime: Date,
        targetUserId: String,
        score: Int,
        isOnTime: Bool,
        coupleId: String
    ) -> ScoreRecordModel {
        let record = ScoreRecordModel()
        record.recordId = UUID().uuidString
        record.coupleId = coupleId
        record.targetUserId = targetUserId
        record.taskId = taskId
        record.taskTitle = taskTitle
        record.taskNotes = taskNotes
        record.taskSetTime = taskSetTime
        record.taskFinishTime = taskFinishTime
        record.score = score
        record.isOnTime = isOnTime
        record.createTime = taskFinishTime // 使用完成时间作为创建时间
        return record
    }
    
    // ✅ 应用筛选条件（后台处理，避免主线程阻塞）
    private func applyFilters() {
        // ✅ 在后台线程处理筛选和排序（避免主线程阻塞导致发烫）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var filtered = self.allRecords
            
            // ✅ 0. 优先：按任务ID筛选（只显示单条任务的记录）
            if let taskId = self.filterTaskId, !taskId.isEmpty {
                filtered = filtered.filter { $0.taskId == taskId }
                print("✅ 按任务ID筛选：\(taskId)，筛选后记录数：\(filtered.count)")
            }
            
            let currentUserId = CoupleStatusManager.getUserUniqueUUID()
            let (_, partnerUser) = UserManger.manager.getCoupleUsers()
            let partnerUserId = partnerUser?.id ?? ""
            
            // ✅ 1. 先合并双方任务的记录（必须在筛选之前，否则可能丢失其中一条记录）
            var mergedRecords: [ScoreRecordModel] = []
            var processedTaskIds = Set<String>()
            
            for record in filtered {
                let taskId = record.taskId
                
                // 如果已经处理过这个 taskId，跳过
                if processedTaskIds.contains(taskId) {
                    continue
                }
                
                // ✅ 在原始数据中查找同一个 taskId 的所有记录（不经过筛选，确保能找到双方记录）
                let sameTaskRecords = filtered.filter { $0.taskId == taskId }
                
                if sameTaskRecords.count == 2 {
                    // 检查是否是双方任务（一条给自己，一条给对方）
                    let myRecord = sameTaskRecords.first { $0.targetUserId == currentUserId }
                    let partnerRecord = sameTaskRecords.first { $0.targetUserId == partnerUserId }
                    
                    if myRecord != nil && partnerRecord != nil {
                        // ✅ 双方任务：合并为一条记录（使用自己的记录作为代表）
                        // 注意：合并后的记录仍然保留原始的 targetUserId，但显示时会识别为双方任务
                        mergedRecords.append(myRecord!)
                        processedTaskIds.insert(taskId)
                        continue
                    }
                }
                
                // 单条记录，直接添加
                mergedRecords.append(record)
                processedTaskIds.insert(taskId)
            }
            
            // ✅ 2. View 筛选（Partner/Oneself）- 在合并后进行
            // ✅ 辅助方法：判断是否是双方任务
            let isBothTaskRecord: (ScoreRecordModel) -> Bool = { record in
                let sameTaskRecords = self.allRecords.filter { $0.taskId == record.taskId }
                return sameTaskRecords.count >= 2 &&
                sameTaskRecords.contains(where: { $0.targetUserId == currentUserId }) &&
                sameTaskRecords.contains(where: { $0.targetUserId == partnerUserId })
            }
            
            switch self.filterView {
            case .partner:
                mergedRecords = mergedRecords.filter { record in
                    // ✅ 显示：1) 对方的记录 2) 双方任务（因为双方任务包含对方，应该显示）
                    let isBothTask = isBothTaskRecord(record)
                    return record.targetUserId == partnerUserId || isBothTask
                }
            case .oneself:
                mergedRecords = mergedRecords.filter { record in
                    // ✅ 显示：1) 自己的记录 2) 双方任务（因为双方任务包含自己，应该显示）
                    let isBothTask = isBothTaskRecord(record)
                    return record.targetUserId == currentUserId || isBothTask
                }
            case .all:
                break // 显示所有
            }
            
            // ✅ 3. Status 筛选（Completed/Overdue）
            switch self.filterStatus {
            case .completed:
                mergedRecords = mergedRecords.filter { $0.score > 0 && $0.isOnTime }
            case .overdue:
                mergedRecords = mergedRecords.filter { $0.score < 0 || !$0.isOnTime }
            case .all:
                break // 显示所有
            }
            
            // 4. Time 排序（Newest/Oldest）
            switch self.filterTime {
            case .newest:
                mergedRecords = mergedRecords.sorted { $0.createTime > $1.createTime }
            case .oldest:
                mergedRecords = mergedRecords.sorted { $0.createTime < $1.createTime }
            }
            
            // ✅ 在主线程更新UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.filteredRecords = mergedRecords
                self.tableView.reloadData()
                // ✅ 更新表格容器高度
                self.updateTableViewHeight()
            }
        }
    }
    
    // ✅ 新增：设置按任务ID筛选（只显示单条任务的加分减分记录）
    func filterByTaskId(_ taskId: String?) {
        filterTaskId = taskId
        applyFilters()
    }
    
    // ✅ 新增：清除任务ID筛选（显示所有记录）
    func clearTaskIdFilter() {
        filterTaskId = nil
        applyFilters()
    }
    
    // ✅ 设置 FilterPopup 的回调和筛选逻辑
    private func setupFilterPopup() {
        // 重置所有按钮状态
        filterPopup.viewButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
        filterPopup.viewButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
        filterPopup.viewButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        filterPopup.viewButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        
        filterPopup.statusButtonView.leftButton.backgroundColor = .color(hexString: "#FBFBFB")
        filterPopup.statusButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
        filterPopup.statusButtonView.leftButtonImageView.image = UIImage(named: "assignUnselect")
        filterPopup.statusButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        
        filterPopup.timeButtonView.leftButton.backgroundColor = .color(hexString: "#5DCF51").withAlphaComponent(0.05)
        filterPopup.timeButtonView.rightButton.backgroundColor = .color(hexString: "#FBFBFB")
        filterPopup.timeButtonView.leftButtonImageView.image = UIImage(named: "assignSelect")
        filterPopup.timeButtonView.rightButtonImageView.image = UIImage(named: "assignUnselect")
        
        // ✅ 设置 Continue 按钮回调，应用筛选
        filterPopup.onContinueTapped = { [weak self] in
            guard let self = self else { return }
            // 读取筛选条件
            self.readFilterConditions()
            // 应用筛选
            self.applyFilters()
        }
    }
    
    // ✅ 读取筛选条件
    private func readFilterConditions() {
        // View 筛选
        if filterPopup.viewButtonView.leftButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05) {
            filterView = .partner
        } else if filterPopup.viewButtonView.rightButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05) {
            filterView = .oneself
        } else {
            filterView = .all
        }
        
        // Status 筛选
        if filterPopup.statusButtonView.leftButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05) {
            filterStatus = .completed
        } else if filterPopup.statusButtonView.rightButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05) {
            filterStatus = .overdue
        } else {
            filterStatus = .all
        }
        
        // Time 排序
        if filterPopup.timeButtonView.leftButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05) {
            filterTime = .newest
        } else if filterPopup.timeButtonView.rightButton.backgroundColor == .color(hexString: "#5DCF51").withAlphaComponent(0.05) {
            filterTime = .oldest
        } else {
            filterTime = .newest
        }
    }
    
    // ✅ 创建单条分数记录视图（与 PointsView 中的样式一致）
    private func createScoreRecordView(recordId: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // ✅ 为 containerView 添加唯一标识符（用于防止 cell 复用时更新错误的视图）
        containerView.accessibilityIdentifier = recordId
        
        // ✅ 仅单人头像（与 AddViewPopup 一致，不再使用组合/双方肩并肩）
        let partnerAvatarImageView = UIImageView()
        partnerAvatarImageView.contentMode = .scaleAspectFill
        partnerAvatarImageView.clipsToBounds = true
        partnerAvatarImageView.layer.cornerRadius = 18
        partnerAvatarImageView.tag = 98
        partnerAvatarImageView.isHidden = true // 始终隐藏，仅保留用于兼容 viewWithTag
        containerView.addSubview(partnerAvatarImageView)
        partnerAvatarImageView.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        
        // ✅ 单人头像：根据 record.targetUserId 显示对应用户
        let userImage = UIImageView()
        userImage.contentMode = .scaleAspectFill
        userImage.clipsToBounds = true
        userImage.layer.cornerRadius = 18
        userImage.tag = 99
        containerView.addSubview(userImage)
        userImage.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        
        // Title Label（第一行）
        let titleLabel = UILabel()
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 14)
        titleLabel.textColor = .color(hexString: "#322D3A")
        titleLabel.tag = 100
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(userImage.snp.right).offset(8)
            make.top.equalTo(12)
            make.right.lessThanOrEqualToSuperview().offset(-80)
        }
        
        // Notes Label（第二行）
        let notesLabel = UILabel()
        notesLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        notesLabel.textColor = .color(hexString: "#999DAB")
        notesLabel.tag = 101
        containerView.addSubview(notesLabel)
        notesLabel.snp.makeConstraints { make in
            make.left.equalTo(userImage.snp.right).offset(8)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.right.lessThanOrEqualToSuperview().offset(-80)
        }
        
        // ✅ 第三行：状态图片 + 时间
        let statusTimeContainer = UIView()
        statusTimeContainer.tag = 105 // 容器标签
        containerView.addSubview(statusTimeContainer)
        statusTimeContainer.snp.makeConstraints { make in
            make.left.equalTo(userImage.snp.right).offset(8)
            make.top.equalTo(notesLabel.snp.bottom).offset(2)
            make.right.lessThanOrEqualToSuperview().offset(-80)
            make.height.equalTo(20) // 状态图片和时间的高度
        }
        
        // 状态图片（✅/逾期）
        let statusImageView = UIImageView()
        statusImageView.contentMode = .scaleAspectFit
        statusImageView.tag = 106 // 状态图片标签
        statusTimeContainer.addSubview(statusImageView)
        statusImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20) // 图片尺寸
        }
        
        // 时间标签
        let timeLabel = UILabel()
        timeLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        timeLabel.textColor = .color(hexString: "#C0C0C0")
        timeLabel.tag = 107 // 时间标签
        statusTimeContainer.addSubview(timeLabel)
        timeLabel.snp.makeConstraints { make in
            make.left.equalTo(statusImageView.snp.right).offset(6)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualToSuperview()
        }
        
        // 分数显示（右侧）
        let scoreContainer = UIView()
        containerView.addSubview(scoreContainer)
        scoreContainer.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.centerY.equalToSuperview()
        }
        
        // 分数三层Label
        let underunderScoreLabel = StrokeShadowLabel()
        underunderScoreLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderScoreLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderScoreLabel.shadowBlurRadius = 1.0
        underunderScoreLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!
        underunderScoreLabel.tag = 102
        scoreContainer.addSubview(underunderScoreLabel)
        underunderScoreLabel.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        let underScoreLabel = StrokeShadowLabel()
        underScoreLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        underScoreLabel.shadowOffset = CGSize(width: 0, height: 1)
        underScoreLabel.shadowBlurRadius = 5.0
        underScoreLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!
        underScoreLabel.tag = 103
        scoreContainer.addSubview(underScoreLabel)
        underScoreLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderScoreLabel)
        }
        
        let scoreLabel = GradientMaskLabel()
        scoreLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 18)!
        scoreLabel.gradientStartColor = .color(hexString: "#FFC251")
        scoreLabel.gradientEndColor = .color(hexString: "#FF7738")
        scoreLabel.tag = 104
        scoreContainer.addSubview(scoreLabel)
        scoreLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderScoreLabel)
        }
        
        return containerView
    }
    
    // ✅ 更新单条记录视图
    private func updateRecordView(_ recordView: UIView, with record: ScoreRecordModel) {
        // ✅ 检查 recordView 是否仍然有效（防止 cell 复用后更新错误的视图）
        guard recordView.accessibilityIdentifier == record.recordId else {
            return
        }
        
        guard let partnerAvatarImageView = recordView.viewWithTag(98) as? UIImageView,
              let userImage = recordView.viewWithTag(99) as? UIImageView,
              let titleLabel = recordView.viewWithTag(100) as? UILabel,
              let notesLabel = recordView.viewWithTag(101) as? UILabel,
              let statusTimeContainer = recordView.viewWithTag(105) as? UIView,
              let statusImageView = statusTimeContainer.viewWithTag(106) as? UIImageView,
              let timeLabel = statusTimeContainer.viewWithTag(107) as? UILabel,
              let underunderScoreLabel = recordView.viewWithTag(102) as? StrokeShadowLabel,
              let underScoreLabel = recordView.viewWithTag(103) as? StrokeShadowLabel,
              let scoreLabel = recordView.viewWithTag(104) as? GradientMaskLabel else {
            return
        }
        
        // 更新标题和备注
        titleLabel.text = record.taskTitle
        notesLabel.text = record.taskNotes.isEmpty ? "No Notes" : record.taskNotes
        
        // ✅ 更新第三行：状态图片（✅/逾期）+ 时间
        if record.isOnTime {
            // ✅ 按时完成：显示 middleButtonSelected 图片 + 完成时间
            statusImageView.image = UIImage(named: "middleButtonSelected")
            let timeString = formatDate(record.taskFinishTime)
            timeLabel.text = timeString
            timeLabel.textColor = .color(hexString: "#C0C0C0")
        } else {
            // ❌ 逾期：显示 middleButtonOverdue 图片 + 截止时间
            statusImageView.image = UIImage(named: "middleButtonOverdue")
            let timeString = formatDate(record.taskSetTime)
            timeLabel.text = timeString
            timeLabel.textColor = .color(hexString: "#C0C0C0")
        }
        
        // ✅ 根据 cell 加减分状态显示：加分 +N、减分 -N、加0分 显示为 0（与 list cell 一致）
        let scoreValue = abs(record.score)
        let scoreText: String
        if record.score > 0 {
            scoreText = "+\(scoreValue)"
            scoreLabel.gradientStartColor = .color(hexString: "#FFC251")
            scoreLabel.gradientEndColor = .color(hexString: "#FF7738")
        } else if record.score < 0 {
            scoreText = "-\(scoreValue)"
            scoreLabel.gradientStartColor = .color(hexString: "#FF8251")
            scoreLabel.gradientEndColor = .color(hexString: "#FF3838")
        } else {
            scoreText = "0"
            scoreLabel.gradientStartColor = .color(hexString: "#FFC251")
            scoreLabel.gradientEndColor = .color(hexString: "#FF7738")
        }
        scoreLabel.text = scoreText
        underScoreLabel.text = scoreText
        underunderScoreLabel.text = scoreText
        
        // ✅ 加载头像：仅单人头像（与 AddViewPopup 一致）
        loadAvatarForRecord(record, recordView: recordView, partnerImageView: partnerAvatarImageView, userImage: userImage, recordId: record.recordId)
    }
    
    // ✅ 格式化日期显示
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy, h:mm a" // September 25, 2025, 5:30 PM
        return formatter.string(from: date)
    }
    
    /// 根据性别返回默认头像图名（与 HomeCell/Assign 一致）
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }

    /// 默认头像不显示阴影：与 AddPopup 的 clearAssignStatusAvatarShadow 一致
    private func clearAvatarShadow(on imageView: UIImageView) {
        imageView.layer.shadowOpacity = 0
        if let sub = imageView.layer.sublayers?.first(where: { $0.name == "avatarShadowSecondLayer" }) {
            sub.removeFromSuperlayer()
        } else if let first = imageView.layer.sublayers?.first {
            first.removeFromSuperlayer()
        }
    }

    // ✅ 与 HomeCell 一致：用 getCoupleUsers() 的 current/partner 判断「得分者是我还是对方」，用对应 model 的头像与默认图（避免另一台设备头像反了）
    private func loadAvatarForRecord(_ record: ScoreRecordModel, recordView: UIView, partnerImageView: UIImageView, userImage: UIImageView, recordId: String) {
        let targetUUID = record.targetUserId
        partnerImageView.isHidden = true
        partnerImageView.image = nil
        userImage.layer.cornerRadius = 18
        userImage.contentMode = .scaleAspectFill
        userImage.snp.remakeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }
        guard !targetUUID.isEmpty else {
            userImage.image = UIImage(named: "assignimage")
            clearAvatarShadow(on: userImage)
            return
        }
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        let defaultName: String
        let avatarURLToUse: String?
        if targetUUID == currentUUID {
            defaultName = defaultImageName(forGender: currentUser?.gender)
            avatarURLToUse = currentUser?.avatarImageURL
        } else if targetUUID == partnerUUID {
            defaultName = defaultImageName(forGender: partnerUser?.gender)
            avatarURLToUse = partnerUser?.avatarImageURL
        } else {
            let targetUser = UserManger.manager.getUserModelByUUID(targetUUID)
            defaultName = defaultImageName(forGender: targetUser?.gender)
            avatarURLToUse = targetUser?.avatarImageURL
        }
        loadAvatarForUser(uuid: targetUUID, avatarURL: avatarURLToUse, defaultImage: UIImage(named: defaultName), userImage: userImage, recordId: recordId)
    }
    
    // ✅ 与 HomeCell 一致：avatarURL 可选，传入时用传入值（来自 getCoupleUsers 的 current/partner），避免另一台设备查错人
    private func loadAvatarForUser(uuid: String, avatarURL: String? = nil, defaultImage: UIImage?, userImage: UIImageView, recordId: String) {
        userImage.accessibilityIdentifier = recordId
        let avatarString: String? = avatarURL.flatMap { $0.isEmpty ? nil : $0 }
            ?? UserManger.manager.getUserModelByUUID(uuid)?.avatarImageURL
        guard let avatarString = avatarString, !avatarString.isEmpty else {
            applyAvatarOnMain(recordId: recordId, userImage: userImage, image: defaultImage)
            return
        }
        if let cached = UserAvatarDisplayCache.shared.imageForSingle(avatarString: avatarString) {
            applyAvatarOnMain(recordId: recordId, userImage: userImage, image: cached, isProcessed: true)
            return
        }
        applyAvatarOnMain(recordId: recordId, userImage: userImage, image: defaultImage)
        guard let image = imageFromBase64String(avatarString) else { return }
        let outputSize = CGSize(width: 72, height: 72)
        ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 6, outputSize: outputSize, cacheKey: avatarString) { [weak userImage] processed in
            let final = processed ?? image
            UserAvatarDisplayCache.shared.setSingle(final, for: avatarString)
            DispatchQueue.main.async {
                guard let userImage = userImage, userImage.accessibilityIdentifier == recordId else { return }
                userImage.image = final
                userImage.contentMode = .scaleAspectFit
                userImage.clipsToBounds = false
                userImage.applyAvatarCutoutShadow()
            }
        }
    }
    
    private func applyAvatarOnMain(recordId: String, userImage: UIImageView, image: UIImage?, isProcessed: Bool = false) {
        if Thread.isMainThread {
            guard userImage.accessibilityIdentifier == recordId else { return }
            userImage.image = image
            if isProcessed {
                userImage.contentMode = .scaleAspectFit
                userImage.clipsToBounds = false
                userImage.applyAvatarCutoutShadow()
            } else {
                clearAvatarShadow(on: userImage)
            }
        } else {
            DispatchQueue.main.async { [weak self, weak userImage] in
                guard let self = self, let userImage = userImage, userImage.accessibilityIdentifier == recordId else { return }
                userImage.image = image
                if isProcessed {
                    userImage.contentMode = .scaleAspectFit
                    userImage.clipsToBounds = false
                    userImage.applyAvatarCutoutShadow()
                } else {
                    self.clearAvatarShadow(on: userImage)
                }
            }
        }
    }
    
    // ✅ 从Base64字符串解码图片
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        // ✅ 检查是否是Base64格式（可能包含前缀 "data:image/jpeg;base64,"）
        var base64 = base64String
        
        // 移除前缀（如果存在）
        if base64.hasPrefix("data:image/") {
            if let range = base64.range(of: ",") {
                base64 = String(base64[range.upperBound...])
            }
        }
        
        // ✅ 解码Base64字符串
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        
        return UIImage(data: imageData)
    }
    
    // ✅ 调整图片尺寸到指定大小
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func showdFilter() {
        filterPopup.show(width: view.width(), bottomSpacing: view.window?.safeAreaInsets.bottom ?? 34)
    }
    
    // ✅ 分数更新通知回调：防抖，避免另一台设备同步时多次通知导致表格反复重载、头像闪烁
    @objc private func refreshData() {
        pendingLoadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.loadAllScoreRecords()
        }
        pendingLoadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension BreakdownViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // ✅ 使用cell复用机制（提升性能，避免发烫）
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreRecordCell", for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        
        // ✅ 清除旧内容（复用cell时必须清除）
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // ✅ 确保索引有效
        guard indexPath.row < filteredRecords.count else {
            return cell
        }
        
        // 创建记录视图
        let record = filteredRecords[indexPath.row]
        let recordView = createScoreRecordView(recordId: record.recordId)
        cell.contentView.addSubview(recordView)
        recordView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(82) // 行高82
        }
        
        // ✅ 如果不是最后一行，添加横线分隔
        if indexPath.row < filteredRecords.count - 1 {
            let separatorLine = UIView()
            separatorLine.backgroundColor = .color(hexString: "#484848").withAlphaComponent(0.05)
            cell.contentView.addSubview(separatorLine)
            separatorLine.snp.makeConstraints { make in
                make.top.equalTo(recordView.snp.bottom).offset(10)
                make.left.equalToSuperview().offset(12)
                make.right.equalToSuperview().offset(-12)
                make.height.equalTo(1)
                make.bottom.equalToSuperview()
            }
        } else {
            // 最后一行，确保底部对齐
            recordView.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
            }
        }
        
        // 更新记录内容（record 已在上面定义）
        updateRecordView(recordView, with: record)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // ✅ 修复：非最后一行需要包含分隔线的高度（82 + 10间距 + 1分隔线），最后一行只有82
        if indexPath.row < filteredRecords.count - 1 {
            return 82 + 10 + 1 // 行高 + 分隔线间距 + 分隔线高度
        } else {
            return 82 // 最后一行，没有分隔线
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}
