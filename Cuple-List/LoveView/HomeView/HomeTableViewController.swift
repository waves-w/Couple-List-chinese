//
//  HomeTableViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import CoreData
import MagicalRecord
import ReactiveSwift
import MGSwipeTableCell
import SnapKit

class HomeTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, MGSwipeTableCellDelegate {
    
    // Core Data 监听控制器
    var fetchedResultsController: NSFetchedResultsController<ListModel>!
    var separatorViews: [UIView] = []
    var emptyView: UIImageView!
    var listModel: ListModel?
    var editPopup = EditViewPopup()
    
    // ✅ 保持删除弹窗的引用，防止被释放
    private var deletePopup: DeleteConfirmPopup?
    
    // 自定义删除按钮图片名称（可以修改为你的图片名称）
    var customDeleteIconName: String = "delete_icon"
    
    // 日期筛选条件
    var datePredicate: NSPredicate? {
        didSet {
            // ✅ 安全检查：确保 fetchedResultsController 已初始化
            guard let fetchedResultsController = fetchedResultsController else {
                print("⚠️ FetchedResultsController 未初始化，跳过更新")
                return
            }
            
            // 当过滤条件变化时，重新执行查询
            fetchedResultsController.fetchRequest.predicate = datePredicate
            do {
                try fetchedResultsController.performFetch()
            } catch {
                // ✅ 改为打印错误而不是 fatalError
                print("❌ 更新 FetchedResultsController 失败: \(error)")
                let nsError = error as NSError
                print("   - 错误代码: \(nsError.code)")
                print("   - 错误信息: \(nsError.localizedDescription)")
            }
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
        
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.register(HomeSwipeTableCell.self, forCellReuseIdentifier: "HomeCell")
        tableView.separatorStyle = .none
        
        tableView.allowsMultipleSelectionDuringEditing = false
        tableView.isEditing = false
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avatarDidUpdate),
            name: UserManger.avatarDidUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(taskDidUpdate(_:)),
            name: DbManager.dataDidUpdateNotification,
            object: nil
        )
        
        emptyView = UIImageView(image: .noHome)
        emptyView.contentMode = .scaleAspectFit
        emptyView.isUserInteractionEnabled = false
        view.addSubview(emptyView)
        
        // 用整屏高度比例算底部间距（266 为 812 设计稿上的数值，适配不同机型）
        let screenHeight = UIScreen.main.bounds.height
        let emptyBottomOffset = screenHeight * (266.0 / 812.0)
        emptyView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-emptyBottomOffset)
            make.width.equalToSuperview().multipliedBy(192.0 / 375.0)
            make.height.equalTo(171)
        }
        
        let nohomelittleImage = UIImageView(image: .nohomelittle)
        emptyView.addSubview(nohomelittleImage)
        
        nohomelittleImage.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-10)
            make.centerX.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadVisibleCellsAvatars()
    }
    
    @objc private func avatarDidUpdate() {
        guard isViewLoaded, view.window != nil else { return }
        reloadVisibleCellsAvatars()
    }
    
    /// 修改页 dismiss 后收到通知，按 taskDate 重排后整表刷新（含从详情页编辑后 pop 回列表）
    @objc private func taskDidUpdate(_ notification: Notification) {
        guard notification.userInfo?[DbManager.dataDidUpdateItemIdKey] as? String != nil else { return }
        guard isViewLoaded, view.window != nil else { return }
        try? fetchedResultsController.performFetch()
        tableView.reloadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 识别到用户数据修改后调用：对当前可见的 Home cell 重新拉取头像并刷新（从 UserManger 取最新）
    private func reloadVisibleCellsAvatars() {
        guard let visibleIndexPaths = tableView.indexPathsForVisibleRows else { return }
        for indexPath in visibleIndexPaths {
            if let cell = tableView.cellForRow(at: indexPath) as? HomeSwipeTableCell,
               let listModel = fetchedResultsController?.object(at: indexPath) {
                cell.configure(with: listModel)
            }
        }
    }
    
    // MARK: - FetchedResultsController Setup
    private func setupFetchedResultsController() {
        // ✅ NSManagedObjectContext.mr_default() 返回非可选类型，直接使用
        let context = NSManagedObjectContext.mr_default()
        
        let fetchRequest: NSFetchRequest<ListModel> = ListModel.fetchRequest()
        
        // ✅ 按任务截止时间从早到晚排序，修改时间后列表会立即重排；同时间按创建时间升序
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "taskDate", ascending: true),
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]
        
        // 初始筛选条件
        fetchRequest.predicate = datePredicate
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: context,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            print("✅ FetchedResultsController 初始化成功")
        } catch {
            // ✅ 改为打印错误而不是 fatalError，避免崩溃
            let nsError = error as NSError
            print("❌ FetchedResultsController 初始化失败:")
            print("   - 错误代码: \(nsError.code)")
            print("   - 错误域: \(nsError.domain)")
            print("   - 错误信息: \(nsError.localizedDescription)")
            print("   - 详细信息: \(nsError.userInfo)")
            
            // ✅ 备用：仅按 taskDate 升序
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "taskDate", ascending: true)]
            do {
                try fetchedResultsController.performFetch()
                print("✅ 使用备用排序方式成功")
            } catch {
                print("❌ 备用排序方式也失败: \(error)")
                // 如果还是失败，至少让应用继续运行
            }
        }
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        let sectionCount = fetchedResultsController.sections?.count ?? 0
        emptyView.isHidden = (fetchedResultsController.fetchedObjects?.count ?? 0) > 0
        return sectionCount
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 102
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HomeCell", for: indexPath) as? HomeSwipeTableCell else {
            return UITableViewCell()
        }
        
        let currentModel = fetchedResultsController.object(at: indexPath)
        cell.configure(with: currentModel)
        cell.delegate = self
        cell.onCompletionStateChanged = { [weak self] isCompleted in
            guard let self = self else { return }
            guard SubscriptionPaywallGate.requireSubscription(from: self) else {
                cell.isCompleted = !isCompleted
                return
            }
            guard let itemId = currentModel.id else {
                print("❌ 同步失败：当前模型 ID 为空")
                cell.isCompleted = !isCompleted
                return
            }
            
            // 1. 更新 Core Data 模型状态
            currentModel.isCompleted = isCompleted
            // 2. 调用 DbManager 保存并同步到 Firebase
            DbManager.manager.updateModel(currentModel)
            
            // 立即更新 Cell UI（确保状态一致）
            cell.isCompleted = isCompleted
            print("📤 同步完成状态：\(itemId) → \(isCompleted)")
        }
        return cell
    }
    
    // MARK: - Core Data 操作
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let listModel = fetchedResultsController.object(at: indexPath)
            DbManager.manager.deleteModel(listModel)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        let selectedItem = fetchedResultsController.object(at: indexPath)
        let detailedVC = DetailedViewController()
        detailedVC.hidesBottomBarWhenPushed = true
        detailedVC.listModelToDelete = selectedItem
        
        // 日期格式化
        if let taskDate = selectedItem.taskDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            detailedVC.itemDate = formatter.string(from: taskDate)
        } else {
            detailedVC.itemDate = "No Date"
        }
        
        detailedVC.itemTitle = selectedItem.titleLabel
        detailedVC.itemNotes = selectedItem.notesLabel
        detailedVC.itemPoints = String(selectedItem.points)
        navigationController?.pushViewController(detailedVC, animated: true)
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .update:
            if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) as? HomeSwipeTableCell, let listModel = anObject as? ListModel {
                cell.configure(with: listModel)
            }
        case .move:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .fade)
            }
        @unknown default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        emptyView.isHidden = (fetchedResultsController.fetchedObjects?.count ?? 0) > 0
    }
    
    // MARK: - MGSwipeTableCellDelegate
    func swipeTableCell(_ cell: MGSwipeTableCell, swipeButtonsFor direction: MGSwipeDirection, swipeSettings: MGSwipeSettings, expansionSettings: MGSwipeExpansionSettings) -> [UIView]? {
        if direction == .rightToLeft {
            // 删除按钮 - 使用自定义图片并确保居中显示
            let deleteIcon = UIImage(named: customDeleteIconName) ?? UIImage(named: "delete_icon")
            
            // 创建按钮（不设置 icon，稍后手动添加居中的图片视图）
            let deleteButton = MGSwipeButton(title: "", icon: nil, backgroundColor: .clear) { [weak self] (cell) -> Bool in
                guard let self = self, let indexPath = self.tableView.indexPath(for: cell) else { return false }
                guard SubscriptionPaywallGate.requireSubscription(from: self) else { return false }
                let listModel = self.fetchedResultsController.object(at: indexPath)
                
                // ✅ 使用自定义删除确认弹窗
                self.deletePopup = DeleteConfirmPopup(
                    title: "Delete task?",
                    message: "Are you sure you want to delete this task?",
                    imageName: self.customDeleteIconName,
                    cancelTitle: "Cancel",
                    confirmTitle: "Delete",
                    confirmBlock: { [weak self] in
                        DbManager.manager.deleteModel(listModel)
                        cell.hideSwipe(animated: true)
                        self?.deletePopup = nil // ✅ 删除后释放引用
                    },
                    cancelBlock: { [weak self] in
                        cell.hideSwipe(animated: true)
                        self?.deletePopup = nil // ✅ 取消后释放引用
                    }
                )
                self.deletePopup?.show()
                return false
            }
            
            // 设置按钮宽度
            deleteButton.buttonWidth = 60
            
            // 创建居中的图片视图
            let deleteImageView = UIImageView(image: deleteIcon)
            deleteImageView.contentMode = .scaleAspectFit
            deleteImageView.isUserInteractionEnabled = false // 让点击事件传递到按钮
            deleteButton.addSubview(deleteImageView)
            
            // 使用 SnapKit 确保图片在按钮中心
            deleteImageView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
                make.width.height.equalTo(30) // 可以根据你的图片大小调整
            }
            
            // 编辑按钮
            let editButton = MGSwipeButton(title: "", icon: UIImage(named: "edit_icon"), backgroundColor: .clear) { [weak self] (cell) -> Bool in
                guard let self = self, let indexPath = self.tableView.indexPath(for: cell) else { return true }
                guard SubscriptionPaywallGate.requireSubscription(from: self) else { return false }
                let modelToEdit = self.fetchedResultsController.object(at: indexPath)
                
                editPopup.configureUI(with: modelToEdit)
                editPopup.onEditComplete = { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        // 修改时间后重新拉取并按 taskDate 从早到晚重排，整表刷新以反映新顺序
                        try? self.fetchedResultsController.performFetch()
                        self.tableView.reloadData()
                    }
                }
                
                editPopup.show(width: self.view.width(), bottomSpacing: self.view.window?.safeAreaInsets.bottom ?? 34)
                return true
            }
            
            // 设置编辑按钮宽度，使其更靠近 cell
            editButton.buttonWidth = 60
            
            // 设置按钮间距为 -26 像素
            swipeSettings.buttonsDistance = -10
            // 删除按钮在最右边与 cell 平齐
            swipeSettings.offset = 10
            
            return [deleteButton, editButton]
        }
        
        return nil
    }
}
