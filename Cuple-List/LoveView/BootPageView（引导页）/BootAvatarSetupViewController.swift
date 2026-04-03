//
//  BootAvatarSetupViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

final class BootAvatarSetupViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private var avatarImageView: UIImageView!
    private var acaterButton: UIButton!
    private var continueButton: UIButton!
    private var backButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        refreshAvatarPlaceholder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.avatar)
    }
    
    private func setUI() {
        view.backgroundColor = .white
        
        let bg = UIImageView(image: .bootbackiamge)
        bg.contentMode = .scaleAspectFill
        bg.clipsToBounds = true
        view.addSubview(bg)
        bg.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        backButton = UIButton()
        backButton.setImage(UIImage(named: "arrow"), for: .normal)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        let title = UILabel()
        title.text = "Choose your avatar"
        title.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        title.textColor = .color(hexString: "#322D3A")
        title.textAlignment = .center
        view.addSubview(title)
        title.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(view.height() * 200 / 812)
        }
        
        
        avatarImageView = UIImageView()
        avatarImageView.contentMode = .scaleAspectFit
        avatarImageView.isUserInteractionEnabled = true
        avatarImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTapped)))
        view.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(title.snp.bottom).offset(20)
            make.width.equalToSuperview().multipliedBy(124.0 / 375.0)
            make.height.equalTo(avatarImageView.snp.width)
        }
        
        acaterButton = UIButton()
        acaterButton.setImage(UIImage(named: "setpicimage"), for: .normal)
        acaterButton.addTarget(self, action: #selector(avatarTapped), for: .touchUpInside)
        view.addSubview(acaterButton)
        acaterButton.snp.makeConstraints { make in
            make.right.equalTo(avatarImageView.snp.right).offset(20)
            make.bottom.equalTo(avatarImageView.snp.bottom).offset(20)
        }
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 18
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-4)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
    }
    
    private func refreshAvatarPlaceholder() {
        let uuid = UserManger.manager.currentUserUUID
        if let s = UserManger.manager.getUserModelByUUID(uuid)?.avatarImageURL, !s.isEmpty,
           let img = imageFromBase64(s) {
            ImageProcessor.shared.processAvatarWithAICutout(image: img, borderWidth: 10, cacheKey: s) { [weak self] out in
                DispatchQueue.main.async {
                    self?.avatarImageView.image = out ?? img
                    self?.avatarImageView.applyAvatarCutoutShadow()
                }
            }
            return
        }
        let gender = (UserManger.manager.getUserModelByUUID(uuid)?.gender ?? "").lowercased()
        let name: String
        if gender == "male" || gender == "男" { name = "maleImageback" }
        else if gender == "female" || gender == "女" { name = "femaleImageback" }
        else { name = "userText" }
        avatarImageView.image = UIImage(named: name) ?? UIImage(named: "userText")
        avatarImageView.layer.shadowOpacity = 0
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func continueTapped() {
        BootOnboardingFeedback.playContinueButton()
        navigationController?.pushViewController(BootTogetherDateViewController(), animated: true)
    }
    
    @objc private func avatarTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
            self?.presentPicker(.camera)
        })
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPicker(.photoLibrary)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = acaterButton
            pop.sourceRect = acaterButton.bounds
        }
        present(alert, animated: true)
    }
    
    private func presentPicker(_ source: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else {
            AlertManager.showSingleButtonAlert(message: "Not available", target: self)
            return
        }
        let p = UIImagePickerController()
        p.sourceType = source
        p.delegate = self
        present(p, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let img = info[.originalImage] as? UIImage,
              let data = compressImage(img, maxMB: 1) else {
            AlertManager.showSingleButtonAlert(message: "Image processing failed", target: self)
            return
        }
        ImageProcessor.shared.processAvatarWithAICutout(image: img, borderWidth: 10) { [weak self] processed in
            guard let self = self, self.isViewLoaded else { return }
            DispatchQueue.main.async {
                self.avatarImageView.image = processed ?? img
                self.avatarImageView.applyAvatarCutoutShadow()
                let b64 = "data:image/jpeg;base64,\(data.base64EncodedString())"
                UserManger.manager.updateAvatarURL(uuid: UserManger.manager.currentUserUUID, avatarURL: b64)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func imageFromBase64(_ base64String: String) -> UIImage? {
        var b = base64String
        if b.hasPrefix("data:image/"), let r = b.range(of: ",") { b = String(b[r.upperBound...]) }
        guard let d = Data(base64Encoded: b, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: d)
    }
    
    private func compressImage(_ image: UIImage, maxMB: Double) -> Data? {
        let maxB = Int(maxMB * 1024 * 1024)
        var q: CGFloat = 0.8
        var img = image
        for _ in 0..<6 {
            if let d = img.jpegData(compressionQuality: q), d.count <= maxB { return d }
            q -= 0.12
        }
        for scale in stride(from: CGFloat(0.75), through: 0.35, by: -0.15) {
            let sz = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(sz, false, img.scale)
            img.draw(in: CGRect(origin: .zero, size: sz))
            if let scaled = UIGraphicsGetImageFromCurrentImageContext() {
                img = scaled
            }
            UIGraphicsEndImageContext()
            if let d = img.jpegData(compressionQuality: 0.5), d.count <= maxB { return d }
        }
        return img.jpegData(compressionQuality: 0.35)
    }
}
