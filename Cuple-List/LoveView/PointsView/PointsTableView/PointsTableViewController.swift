//
//  PointsTableViewController.swift
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
import MGSwipeTableCell

class PointsTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, MGSwipeTableCellDelegate {
    
    var fetchedResultsController: NSFetchedResultsController<PointsModel>!
    var emptyView: UIImageView!
    var pointsModel: PointsModel?
    var editPopup = PointsEditViewPopup()
    
    // ✅ 保持删除弹窗的引用，防止被释放
    private var deletePopup: DeleteConfirmPopup?
    
    var datePredicate: NSPredicate? {
        didSet {
            guard let fetchedResultsController = fetchedResultsController else { return }
            fetchedResultsController.fetchRequest.predicate = datePredicate
            do {
                try fetchedResultsController.performFetch()
            } catch {
                print("❌ 更新 FetchedResultsController 失败: \(error)")
            }
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFetchedResultsController()
        setupTableView()
        setupEmptyView()
        
    }
    
    // MARK: - 初始化配置
    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.register(PointsTableViewCell.self, forCellReuseIdentifier: "HomeCell")
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelectionDuringEditing = false
        tableView.isEditing = false
        tableView.rowHeight = 80
        tableView.estimatedRowHeight = 80
        // 取消 wishlist 自身滑动，由 PointsView 的整体 scrollView 统一滚动
        tableView.isScrollEnabled = false
        // 关闭 table 的 pan，否则会抢掉外层 scrollView 的手势导致划不动
        tableView.panGestureRecognizer.isEnabled = false
        // iOS 15+ 适配
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
    }
    
    private func setupEmptyView() {
        emptyView = UIImageView(image: .noWish)
        emptyView.contentMode = .scaleAspectFit
        emptyView.isUserInteractionEnabled = false
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(0.87)
            make.width.equalToSuperview().multipliedBy(271.0 / 375.0)
            make.height.equalTo(171)
        }
        emptyView.isHidden = (fetchedResultsController.fetchedObjects?.count ?? 0) > 0
    }
    
    private func setupFetchedResultsController() {
        let context = NSManagedObjectContext.mr_default()
        let fetchRequest: NSFetchRequest<PointsModel> = PointsModel.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchRequest.predicate = datePredicate
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: context,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("❌ FetchedResultsController 初始化失败: \(error)")
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
        return 80
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HomeCell", for: indexPath) as? PointsTableViewCell else {
            return UITableViewCell()
        }
        
        let currentModel = fetchedResultsController.object(at: indexPath)
        cell.configure(with: currentModel)
        cell.isSharedImage.isHidden = !currentModel.isShared
        cell.delegate = self
        return cell
    }
    
    // MARK: - Core Data 操作
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let model = fetchedResultsController.object(at: indexPath)
            PointsManger.manager.deleteModel(model)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedItem = fetchedResultsController.object(at: indexPath)
        let pointsVC = PointsDetailedViewController()
        pointsVC.pointsModel = selectedItem
        
        navigationController?.pushViewController(pointsVC, animated: true)
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
            if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) as? PointsTableViewCell, let model = anObject as? PointsModel {
                cell.configure(with: model)
                cell.isSharedImage.isHidden = !model.isShared
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
            let deleteIcon = UIImage(named: "delete_icon")
            
            // 创建按钮（不设置 icon，稍后手动添加居中的图片视图）
            let deleteButton = MGSwipeButton(title: "", icon: nil, backgroundColor: .clear) { [weak self] (cell) -> Bool in
                guard let self = self, let indexPath = self.tableView.indexPath(for: cell) else { return false }
                let pointsmodel = self.fetchedResultsController.object(at: indexPath)
                
                // ✅ 使用自定义删除确认弹窗
                self.deletePopup = DeleteConfirmPopup(
                    title: "Confirm Deletion",
                    message: "Are you sure you want to delete \(pointsmodel.titleLabel ?? "this record")?",
                    imageName: "delete_icon",
                    cancelTitle: "Cancel",
                    confirmTitle: "Delete",
                    confirmBlock: { [weak self] in
                        PointsManger.manager.deleteModel(pointsmodel)
                        cell.hideSwipe(animated: true)
                        self?.deletePopup = nil
                    },
                    cancelBlock: { [weak self] in
                        cell.hideSwipe(animated: true)
                        self?.deletePopup = nil
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
            deleteImageView.isUserInteractionEnabled = false
            deleteButton.addSubview(deleteImageView)
            
            // 使用 SnapKit 确保图片在按钮中心
            deleteImageView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
                make.width.height.equalTo(30)
            }
            
            // 编辑按钮
            let editButton = MGSwipeButton(title: "", icon: UIImage(named: "edit_icon"), backgroundColor: .clear) { [weak self] (cell) -> Bool in
                guard let self = self, let indexPath = self.tableView.indexPath(for: cell) else { return true }
                let modelToEdit = self.fetchedResultsController.object(at: indexPath)
                
                editPopup.configureUI(with: modelToEdit)
                editPopup.onEditComplete = { [weak self] in
                    DispatchQueue.main.async {
                        self?.tableView.reloadRows(at: [indexPath], with: .fade)
                    }
                }
                
                editPopup.show(width: self.view.width(), bottomSpacing: self.view.window?.safeAreaInsets.bottom ?? 34)
                return true
            }
            
            // 设置编辑按钮宽度，使其更靠近 cell
            editButton.buttonWidth = 60
            
            swipeSettings.buttonsDistance = -10
            // 删除按钮在最右边与 cell 平齐
            swipeSettings.offset = 10
            
            return [deleteButton, editButton]
        }
        return nil
    }
}
