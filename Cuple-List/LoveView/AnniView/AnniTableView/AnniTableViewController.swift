//
//  AnniTableViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit
import CoreData
import MagicalRecord

class AnniTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    var fetchedResultsController: NSFetchedResultsController<AnniModel>!
    var anniModel: AnniModel?
    /// 由 `AnniViewController.presentAnniEditPopup` 使用，与列表点击打开同一编辑弹窗
    var editPopup = AnniEditViewPopup()
    weak var anniView: AnniViewController!
    
    /// 空状态图（与 Home 的 noHome 一致，放在 tableView 所在 view 里）
    var emptyView: UIImageView!
    
    var datePredicate: NSPredicate? {
        didSet {
            guard let predicate = datePredicate else { return }
            fetchedResultsController.fetchRequest.predicate = predicate
            do {
                try fetchedResultsController.performFetch()
            } catch {
                print("Failed to update FetchedResultsController: \(error)")
            }
            tableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ✅ 优化：延迟刷新，避免阻塞页面切换动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isViewLoaded else { return }
            self.refreshTableViewFilter()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
        setupTableView()
        setupEmptyView()
        setupDataObserver()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMidnightRefresh),
                                               name: NSNotification.Name("AnniMidnightRefreshNotification"),
                                               object: nil)
    }
    
    private func setupEmptyView() {
        emptyView = UIImageView(image: .noAnni)
        emptyView.contentMode = .scaleAspectFit
        emptyView.isUserInteractionEnabled = false
        view.addSubview(emptyView)
        let screenHeight = UIScreen.main.bounds.height
        let emptyBottomOffset = screenHeight * (266.0 / 812.0)
        emptyView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-emptyBottomOffset)
            make.width.equalToSuperview().multipliedBy(267.0 / 375.0)
            make.height.equalTo(171)
        }
        emptyView.isHidden = (fetchedResultsController.fetchedObjects?.count ?? 0) > 0
    }
    
    @objc private func handleMidnightRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshTableViewFilter()
        }
    }
    
    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.register(AnniTableViewCell.self, forCellReuseIdentifier: "HomeCell")
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelectionDuringEditing = false
        tableView.isEditing = false
        tableView.rowHeight = 80
        tableView.estimatedRowHeight = 80
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
    }
    
    private func setupDataObserver() {
        AnniManger.manager.updatePipe.output.observeValues { [weak self] (_: Int) in
            self?.refreshTableViewFilter()
        }
    }
    
    private func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<AnniModel> = AnniModel.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "targetDate", ascending: true),
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        
        fetchRequest.predicate = NSPredicate(value: true)
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: NSManagedObjectContext.mr_default(),
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("FetchedResultsController Init Error: \(error)")
            let coreDataError = error as NSError
            print("CoreData Error: \(coreDataError.code) - \(coreDataError.domain)")
        }
    }
    
    // MARK: ✅ 核心1 - 获取所有模型并按规则全局排序
    func getAllSortedModels() -> [AnniModel] {
        let fetchRequest: NSFetchRequest<AnniModel> = AnniModel.fetchRequest()
        fetchRequest.sortDescriptors = []
        
        do {
            let allModels = try NSManagedObjectContext.mr_default().fetch(fetchRequest)
            // ✅ 终极排序规则（唯一标准）：距离今天的绝对天数 从小到大排序
            let sortedModels = allModels.sorted { model1, model2 in
                let date1 = self.getFinalTargetDate(for: model1)
                let date2 = self.getFinalTargetDate(for: model2)
                // 取绝对间隔天数，数值越小越靠前（过去/未来一视同仁）
                let absDays1 = AnniDateCalculator.shared.calculateAbsDaysInterval(targetDate: date1)
                let absDays2 = AnniDateCalculator.shared.calculateAbsDaysInterval(targetDate: date2)
                return absDays1 < absDays2
            }
            return sortedModels
        } catch {
            print("Model Sort Error: \(error)")
            return []
        }
    }
    
    // MARK: ✅ 核心2 - 计算模型最终目标日期
    private func getFinalTargetDate(for model: AnniModel) -> Date {
        guard let originalDate = model.targetDate,
              let repeatText = model.repeatDate,
              repeatText != "Never" else {
            return model.targetDate ?? Date()
        }
        return AnniDateCalculator.shared.calculateNextTargetDate(originalDate: originalDate, repeatText: repeatText)
    }
    
    // MARK: ✅ 核心3 - 刷新表格+顶部卡片（统一入口）
    func refreshTableViewFilter() {
        // NSManagedObjectContext.mr_default() 须在主线程访问；在后台 fetch 会导致列表间歇性不刷新。
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshTableViewFilter()
            }
            return
        }
        guard isViewLoaded else { return }
        
        let allSortedModels = getAllSortedModels()
        let top2Models = Array(allSortedModels.prefix(2))
        let hiddenIDs = top2Models.compactMap { $0.id }.filter { !$0.isEmpty }
        
        let newPredicate = hiddenIDs.isEmpty ? NSPredicate(value: true) : NSPredicate(format: "NOT (id IN %@)", hiddenIDs)
        
        fetchedResultsController.fetchRequest.predicate = newPredicate
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Table Data Refresh Error: \(error)")
        }
        
        tableView.reloadData()
        setupLeftAndRightViewWithNearestModels(models: top2Models)
        // 等本轮约束与 intrinsic 都更新后再铺一次布局（添加纪念日时避免粉卡数字仍按占位尺寸排版）
        DispatchQueue.main.async { [weak self] in
            self?.anniView?.view.setNeedsLayout()
            self?.anniView?.view.layoutIfNeeded()
        }
        let totalCount = allSortedModels.count
        emptyView?.isHidden = totalCount > 0
    }
    
    // MARK: ✅ 给顶部双卡片赋值数据
    private func setupLeftAndRightViewWithNearestModels(models: [AnniModel]) {
        guard let anniVC = self.anniView else { return }
        
        if let first = models.first { anniVC.configureLeftPinkView(with: first) }
        else { anniVC.hideLeftPinkView() }
        
        if models.count >= 2 { anniVC.configureRightPinkView(with: models[1]) }
        else { anniVC.hideRightPinkView() }
    }
    
    // MARK: - TableView 数据源
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 74
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HomeCell", for: indexPath) as? AnniTableViewCell else {
            return UITableViewCell()
        }
        
        let currentModel = fetchedResultsController.object(at: indexPath)
        cell.configure(with: currentModel)
        return cell
    }
    
    // MARK: - 单元格点击（与顶部卡片一致：直接编辑弹窗）
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        let selectedItem = fetchedResultsController.object(at: indexPath)
        anniView?.presentAnniEditPopup(for: selectedItem)
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert: tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete: tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default: break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let model = anObject as? AnniModel else { return }
        switch type {
        case .insert: if let newIndexPath = newIndexPath { tableView.insertRows(at: [newIndexPath], with: .fade) }
        case .delete: if let indexPath = indexPath { tableView.deleteRows(at: [indexPath], with: .fade) }
        case .update: if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) as? AnniTableViewCell { cell.configure(with: model) }
        case .move:
            if let indexPath = indexPath { tableView.deleteRows(at: [indexPath], with: .fade) }
            if let newIndexPath = newIndexPath { tableView.insertRows(at: [newIndexPath], with: .fade) }
        @unknown default: break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        let totalCount = getAllSortedModels().count
        emptyView?.isHidden = totalCount > 0
    }
    
    // ✅ 修复：移除通知观察者，避免内存泄漏
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("✅ AnniTableViewController 已释放")
    }
}
