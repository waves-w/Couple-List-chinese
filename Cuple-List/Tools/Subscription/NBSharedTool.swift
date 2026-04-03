//
//  NBSharedTool.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import MessageUI
import Social

enum NBShardPlatform {
    case message
    case systemShared
}

class NBSharedTool: NSObject{
    
    enum NBShardStatus {
        case success
        case cancel
        case unkonw
        case fail
    }
    
    static let shard = NBSharedTool()
    private var block: ((_ shardStatus: NBShardStatus)->())?
    private override init() {
        super.init()
    }
    
    private var vc: UIViewController?
    //检查facebook 和ins  是否有安装
    static func canOpen(platform: NBShardPlatform) -> Bool{
        switch platform {
        case .message:
            return true
        case .systemShared:
            return true
        }
    }
    
    
    
    static func shard(to platform: NBShardPlatform, shardContent:String!, shardImage: UIImage?, linkUrl: URL?,fromVC: UIViewController,_ sourceRect: CGRect = .zero, _ callBack: ((_ shardStatus: NBShardStatus)->())? = nil){
        
        switch platform {
        case .message:
            shard.sharedToMessage(shardContent: shardContent, shardImage: shardImage, fromVC: fromVC, callBack: callBack)
        case .systemShared:
            shard.presentSystemShard(shardContent: shardContent, sharedImage: shardImage, fromVC: fromVC, sourceRect: sourceRect,callBack: callBack)
        }
    }
    
    /**message*/
    private func sharedToMessage(shardContent:String!, shardImage: UIImage?, fromVC: UIViewController, callBack: ((_ shardStatus: NBShardStatus)->())? = nil){
        block = callBack
        let picker = MFMessageComposeViewController()
        picker.body =  shardContent
        picker.messageComposeDelegate = self
        if let cardData = shardImage?.pngData(){
            if picker.addAttachmentData(cardData, typeIdentifier: "public.png", filename: "test.png"){
                fromVC.present(picker, animated: true, completion: nil)
            }
        }
    }
    /**系统分享*/
    private func presentSystemShard(shardContent:String!, sharedImage: UIImage?, fromVC: UIViewController, sourceRect: CGRect = .zero, callBack: ((_ isSuccess: NBShardStatus)->())? = nil){
        //        block = callBack
        var activityItems = [Any]()
        if shardContent != nil {
            activityItems.append(shardContent!)
        }
        if let sharedImage = sharedImage {
            activityItems.append(sharedImage)
        }
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityVC.completionWithItemsHandler =  { (activityType, isCompleted, result, error) -> () in
            if error == nil && isCompleted {
                callBack?(.success)
                if let activityType = activityType{
                    print(activityType.rawValue)
                }
            }else{
                callBack?(.fail)
            }
            activityVC.completionWithItemsHandler = nil
        }
        fromVC.present(activityVC, animated: true, completion: nil)
    }
}



extension NBSharedTool: MFMessageComposeViewControllerDelegate {
    //MARK:--MFMessageComposeViewControllerDelegate
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        print("分享完成")
        block?(.success)
        block = nil
        controller.dismiss(animated: true, completion: nil)
    }
}
