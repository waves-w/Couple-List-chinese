//
//  GreenLabelView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class GreenLabelView: UIView {
    let imageView = UIImageView()
    let textLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        
        textLabel.textColor = .color(hexString: "#8A8E9D")
        textLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        textLabel.numberOfLines = 0
        addSubview(textLabel)
        
        
        imageView.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        
        textLabel.snp.makeConstraints { make in
            make.left.equalTo(imageView.snp.right).offset(8)
            make.centerY.equalToSuperview()
            make.right.equalTo(-12)
            make.top.equalToSuperview()
        }
    }
    
    // 设置图片和文字内容的方法
    func configure(image: UIImage?, text: String) {
        imageView.image = image
        textLabel.text = text
    }
}
