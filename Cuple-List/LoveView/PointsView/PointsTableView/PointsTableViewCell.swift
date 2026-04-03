//
//  PointsTableViewCell.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import MGSwipeTableCell
import CoreData
import MagicalRecord
import ReactiveSwift

class PointsTableViewCell: MGSwipeTableCell {
    
    var middleImageLabel: UILabel!
    var titleLabel: UILabel!
    var notesLabel: UILabel!
    var isSharedImage: UIImageView!
    var pointsMoel: PointsModel?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUI() {
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        let viewcontentView = BorderGradientView()
        viewcontentView.layer.cornerRadius = 18
        contentView.addSubview(viewcontentView)
        
        let verticalSpacing: CGFloat = 12.0
        let horizontalPadding: CGFloat = 20.0
        
        viewcontentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(verticalSpacing / 2)
            make.bottom.equalToSuperview().offset(-verticalSpacing / 2)
            make.left.equalToSuperview().offset(horizontalPadding)
            make.right.equalToSuperview().offset(-horizontalPadding)
        }
        
        middleImageLabel = UILabel()
        middleImageLabel.font = UIFont.systemFont(ofSize: 28)
        viewcontentView.addSubview(middleImageLabel)
        
        middleImageLabel.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
        }
        
        titleLabel = UILabel()
        titleLabel.textColor = .color(hexString: "#322D3A")
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        viewcontentView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(12)
            make.left.equalTo(middleImageLabel.snp.right).offset(8)
        }
        
        notesLabel = UILabel()
        notesLabel.textColor = .color(hexString: "#999DAB")
        notesLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        viewcontentView.addSubview(notesLabel)
        
        notesLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel.snp.left)
            make.bottom.equalTo(-12)
        }
        
        isSharedImage = UIImageView(image: .pinklove)
        isSharedImage.isHidden = true
        viewcontentView.addSubview(isSharedImage)
        
        isSharedImage.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.centerY.equalToSuperview()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        notesLabel.text = nil
        self.backgroundColor = .clear
    }
    
    
    func configure(with pointsModel: PointsModel) {
        titleLabel.text = pointsModel.titleLabel
        notesLabel.text = pointsModel.notesLabel
        let hasNotes = !(pointsModel.notesLabel?.isEmpty ?? true)
        
        if hasNotes {
            titleLabel.snp.remakeConstraints{ make in
                make.top.equalTo(12)
                make.left.equalTo(middleImageLabel.snp.right).offset(8)
            }
            notesLabel.isHidden = false
        } else {
            titleLabel.snp.remakeConstraints{ make in
                make.centerY.equalToSuperview()
                make.left.equalTo(middleImageLabel.snp.right).offset(8)
            }
            notesLabel.isHidden = true
        }
        middleImageLabel.text = pointsModel.wishImage
    }
}
