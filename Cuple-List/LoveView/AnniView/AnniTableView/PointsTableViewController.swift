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

class AnniTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, MGSwipeTableCellDelegate {
    
    var fetchedResultsController: NSFetchedResultsController<PointsModel>!
    var emptyView: UIImageView!
    var pointsModel: PointsModel?
    var editPopup = EditViewPopup()
    
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
                // ✅ 改为打印错误而不是 fatalError，避免崩溃
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
          setupTableView()
          setupDataObserver()
          setupEmptyView()
      }
      
      // MARK: - 初始化配置
      private func setupTableView() {
          tableView.backgroundColor = .clear
          tableView.showsVerticalScrollIndicator = false
          // 注册正确的 Cell 类
          tableView.register(PointsTableViewCell.self, forCellReuseIdentifier: "HomeCell")
          tableView.separatorStyle = .none
          tableView.allowsMultipleSelectionDuringEditing = false
          tableView.isEditing = false
          // 适配新 Cell 的行高（原 102 → 80，匹配新 UI）
          tableView.rowHeight = 80
          tableView.estimatedRowHeight = 80
          // iOS 15+ 适配
          if #available(iOS 15.0, *) {
              tableView.sectionHeaderTopPadding = 0
          }
      }
      
      private func setupDataObserver() {
          PointsManger.manager.updatePipe.output.observeValues { [weak self] (_: Int) in
              // FRC 已处理增删改，此处仅做兜底刷新
              self?.tableView.reloadData()
          }
      }
      
      private func setupEmptyView() {
          // ✅ 统一布局方式：添加到 view 上，确保约束稳定（与其他主页面保持一致）
          emptyView = UIImageView(image: .noWish)
          emptyView.contentMode = .scaleAspectFit
          emptyView.isUserInteractionEnabled = false
          view.addSubview(emptyView)
          emptyView.snp.makeConstraints { make in
              make.centerX.equalToSuperview()
              make.centerY.equalToSuperview().multipliedBy(0.87)
              make.width.equalToSuperview().multipliedBy(170.0 / 375.0)
              make.height.equalTo(emptyView.snp.width)
          }
          // 初始检查空视图状态
          emptyView.isHidden = (fetchedResultsController.fetchedObjects?.count ?? 0) > 0
      }
      
      private func setupFetchedResultsController() {
          let fetchRequest: NSFetchRequest<PointsModel> = PointsModel.fetchRequest()
          
          // 初始排序：按创建时间降序
          fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
          
          // 初始 predicate：如果有日期过滤条件，先设置
          fetchRequest.predicate = datePredicate
          
          fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                managedObjectContext: NSManagedObjectContext.mr_default(),
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
              
              // ✅ 尝试使用更简单的排序方式（不处理 nil）
              fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
              do {
                  try fetchedResultsController.performFetch()
                  print("✅ 使用备用排序方式成功")
              } catch {
                  print("❌ 备用排序方式也失败: \(error)")
                  // 如果还是失败，至少让应用继续运行
              }
          }
      }
      
      // MARK: - TableView 数据源
      override func numberOfSections(in tableView: UITableView) -> Int {
          let sectionCount = fetchedResultsController.sections?.count ?? 0
          // 更新空视图显示状态
          emptyView.isHidden = (fetchedResultsController.fetchedObjects?.count ?? 0) > 0
          return sectionCount
      }
      
      override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
          return .none // 禁用系统默认的删除/插入样式
      }
      
      override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
          return false
      }
      
      override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
          return fetchedResultsController.sections?[section].numberOfObjects ?? 0
      }
      
      // 移除自定义行高，使用注册时的固定行高（或自动行高）
      override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
          return 80 // 匹配新 Cell 的高度
      }
      
      override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
          guard let cell = tableView.dequeueReusableCell(withIdentifier: "HomeCell", for: indexPath) as? PointsTableViewCell else {
              return UITableViewCell()
          }
          
          let currentModel = fetchedResultsController.object(at: indexPath)
          // 配置 Cell 数据（匹配新 Cell 的 configure 方法）
          cell.configure(with: currentModel)
          // 补充共享图标显示逻辑（Cell 未实现，此处提前配置）
          cell.isSharedImage.isHidden = !currentModel.isShared
          
          cell.delegate = self
          return cell
      }
      
      // MARK: - Core Data 删除
      override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
          return true
      }
      
      override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
          if editingStyle == .delete {
              let model = fetchedResultsController.object(at: indexPath)
              PointsManger.manager.deleteModel(model) // 统一使用 PointsManger
          }
      }
      
      // MARK: - 单元格点击
      override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
          tableView.deselectRow(at: indexPath, animated: true) // 取消选中状态
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
          guard let model = anObject as? PointsModel else { return }
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
              if let indexPath = indexPath, let cell = tableView.cellForRow(at: indexPath) as? PointsTableViewCell {
                  cell.configure(with: model)
                  cell.isSharedImage.isHidden = !model.isShared // 同步共享状态
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
          // 更新空视图状态
          emptyView.isHidden = (fetchedResultsController.fetchedObjects?.count ?? 0) > 0
      }
      
      // MARK: - MGSwipeTableCellDelegate
      func swipeTableCell(_ cell: MGSwipeTableCell, swipeButtonsFor direction: MGSwipeDirection, swipeSettings: MGSwipeSettings, expansionSettings: MGSwipeExpansionSettings) -> [UIView]? {
          if direction == .rightToLeft {
              // --- 1. Delete Button ---
              let deleteButton = MGSwipeButton(title: "", icon: UIImage(named: "delete_icon"), backgroundColor: .clear) { [weak self] (cell) -> Bool in
                  guard let self = self, let indexPath = self.tableView.indexPath(for: cell) else { return false }
                  let model = self.fetchedResultsController.object(at: indexPath)
                  
                  let alertController = UIAlertController(title: "确认删除", message: "您确定要删除 “\(model.titleLabel ?? "此条目")” 吗?", preferredStyle: .alert)
                  alertController.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { _ in
                      // 统一使用 PointsManger 删除
                      PointsManger.manager.deleteModel(model)
                      cell.hideSwipe(animated: true)
                  }))
                  alertController.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in
                      cell.hideSwipe(animated: true)
                  }))
                  self.present(alertController, animated: true, completion: nil)
                  return false
              }
              
              // --- 2. Edit Button ---
              let editButton = MGSwipeButton(title: "", icon: UIImage(named: "edit_icon"), backgroundColor: .clear) { [weak self] (cell) -> Bool in
                  guard let self = self, let indexPath = self.tableView.indexPath(for: cell) else { return true }
//                  let modelToEdit = self.fetchedResultsController.object(at: indexPath)
//                  print("✅ 获取到需要编辑的 model：\(modelToEdit.id ?? "无ID")")
                  
//                  editPopup.configureUI(with: modelToEdit)
//                  editPopup.onEditComplete = { [weak self] in
//                      DispatchQueue.main.async {
//                          self?.tableView.reloadRows(at: [indexPath], with: .fade)
//                      }
//                  }
                  
                  editPopup.show(width: self.view.width(), bottomSpacing: self.view.window?.safeAreaInsets.bottom ?? 34)
                  return true
              }
              
              return [deleteButton, editButton]
          }
          return nil
      }
  }
