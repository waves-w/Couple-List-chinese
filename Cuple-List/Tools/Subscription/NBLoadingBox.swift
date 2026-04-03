//
//  NBLoadingBox.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit


class NBLoadingBox: NBBasePopUpBox {
    
    private var contenView: UIView?
    private var effectView: UIVisualEffectView?
    private var titleLabel: UILabel?
    private var active: UIActivityIndicatorView?
    
    static let shard = NBLoadingBox()
    
    static func startLoadingAnimation(_ info:String? = nil,_ closeUserInteraction: Bool = true){       
        if let info = info{
           shard.titleLabel?.text = info
        }else{
            shard.titleLabel?.text = "" // R.string.localizable.pleaseLater()
        }
        if let window = getWindow(){
            window.isUserInteractionEnabled = !closeUserInteraction
        }

        shard.active?.startAnimating()
        shard.showActionSheet()
    }

    static func stopLoadAnimation(){
        shard.stopLoadingAnimation()
    }
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
        contenView = UIView()
        contenView?.layer.cornerRadius = 24
        contenView?.layer.masksToBounds = true
//        contenView?.alpha = 0
        addSubview(contenView!)
        
//        let blurEffect = UIBlurEffect(style: .light)
//        effectView = UIVisualEffectView(effect: blurEffect)
//        effectView?.alpha = 0
//        contenView?.addSubview(effectView!)
        
        titleLabel = UILabel()
        titleLabel?.font = .systemFont(ofSize: 18)
        titleLabel?.textColor = .black
        titleLabel?.textAlignment = .center
        titleLabel?.numberOfLines = 0
        titleLabel?.text =  "" //R.string.localizable.pleaseLater()
        titleLabel?.isHidden = true
        contenView?.addSubview(titleLabel!)
		active = UIActivityIndicatorView(style: .large)
        contenView?.addSubview(active!)
        contenView?.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.left.equalTo(24)
            make.right.equalTo(-24)
        }
        
        effectView?.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        
        titleLabel?.snp.makeConstraints({ (make) in
            make.top.equalTo(32)
            make.left.equalTo(24)
            make.right.equalTo(-24)
        })
        
        active?.snp.makeConstraints({ (make) in
            make.top.equalTo(titleLabel!.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-32)
        })
        
    }
    
    override func showActionSheet() {
        super.showActionSheet()
    }
    
    private func stopLoadingAnimation() {
        DispatchQueue.main.async {
            self.removeFromSuperview()
            if let window = NBLoadingBox.getWindow(){
                window.isUserInteractionEnabled = true
            }
            self.hiddenPopup()
        }
    }
    
  
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
}
