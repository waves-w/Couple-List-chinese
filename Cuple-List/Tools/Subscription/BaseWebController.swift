//
//  BaseWebController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import WebKit
class BaseWebController: UIViewController,WKNavigationDelegate{

    /// 以底部弹层展示网页；默认即用 large，一上来就是展开高度，无需再上拉。
    static func presentAsSheet(from presenter: UIViewController, urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let vc = BaseWebController()
        vc.urlStr = trimmed
        vc.shouldLoadHtmlStr = false
        vc.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = vc.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }
        presenter.present(vc, animated: true)
    }

    var urlStr:String = ""
    var isPresent:Bool = false
    var shouldLoadHtmlStr:Bool = false
    var needGetTitle:Bool = false
    
    
    private var webView:WKWebView?
    private var proressView:UIView?
    private var closeBtn: UIButton?
    var timer:DispatchSourceTimer?
    
    func loadUrl() {
        if shouldLoadHtmlStr {
            webView?.loadHTMLString(urlStr, baseURL: nil)
        }else{
            if let url = URL(string: urlStr){
                let request = URLRequest(url: url)
                webView?.load(request)
            }
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        if #available(iOS 11.0, *) {
            webView?.scrollView.contentInsetAdjustmentBehavior = .never
        } else{
            automaticallyAdjustsScrollViewInsets = false;
        }
        creatSubviews()
        loadUrl()
        // Do any additional setup after loading the view.
    }
    func creatSubviews() {
        webView = WKWebView()
        webView?.backgroundColor = .white
        webView?.navigationDelegate = self
        webView?.scrollView.decelerationRate = UIScrollView.DecelerationRate(rawValue: 1)
        webView?.isOpaque = false
        webView?.frame = view.bounds
        view.addSubview(webView!)
        
        closeBtn = UIButton(type: .custom)
        closeBtn?.setImage(UIImage(named: "Icon_Close_Gray"), for: .normal)
        closeBtn?.addTarget(self, action: #selector(closePage(_:)), for: .touchUpInside)
        closeBtn?.frame = CGRect(x: view.frame.size.width - 20 - 44, y:  50, width: 44, height: 44)
        view.addSubview(closeBtn!)
        
//        proressView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 4))
//        proressView?.backgroundColor = UIColor.clear
//        view.addSubview(proressView!)
//        navigationController?.interactivePopGestureRecognizer?.delegate = self as? UIGestureRecognizerDelegate
    }
    
    //MARK: --WKNavigationDelegate
    // 页面开始加载时调用
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("开始加载")
//        proressView?.isHidden = false
//        timer = DispatchSource.makeTimerSource(flags: [], queue:DispatchQueue.main)
//        timer?.schedule(deadline: .now(), repeating: 0.01)
//        timer?.setEventHandler(handler: { [weak self] () in
//            DispatchQueue.main.async {
//                self?.waitingForAMinute()
//            }
//        })
//        timer?.resume()
    }
    // 页面加载失败时调用
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("加载失败")
//        timer?.cancel()
//        proressView?.isHidden = true
    }
    
    //当内容开始返回时调用
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("开始返回数据")
    }
    //页面加载完成之后调用
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("加载完成")
        timer?.cancel()
//        UIView.animate(withDuration: 0.2, animations: { [weak self] () in
//            var rect = self?.proressView?.frame
//            rect?.size.width = self?.view.frame.size.width ?? ScreenWidth
//            self?.proressView?.frame = rect ?? CGRect(x: 0, y: 0, width: ScreenWidth, height: 4)
//        }) { [weak self](isFinished) in
//            self?.proressView?.isHidden = true
//            self?.proressView?.frame = CGRect(x: 0, y: 0, width: 0, height: 4)
//        }
    }
    
//    func waitingForAMinute() {
//        if proressView?.frame.size.width ?? ScreenWidth <=  self.view.frame.size.width/10*5{
//            UIView.animate(withDuration: 0.01) { [weak self] () in
//                var rect = self?.proressView?.frame
//                rect?.size.width = (self?.view.frame.size.width ?? ScreenWidth)/1000*4;
//                self?.proressView?.frame = rect ?? CGRect(x: 0, y: 0, width: ScreenWidth, height: 4)
//            }
//        }else if proressView?.frame.size.width ?? ScreenWidth <=  self.view.frame.size.width/10*8{
//            UIView.animate(withDuration: 0.01) { [weak self] () in
//                var rect = self?.proressView?.frame
//                rect?.size.width = (self?.view.frame.size.width ?? ScreenWidth)/10000*4;
//                self?.proressView?.frame = rect ?? CGRect(x: 0, y: 0, width: ScreenWidth, height: 4)
//            }
//        }else if  proressView?.frame.size.width ?? ScreenWidth <=  self.view.frame.size.width/10*9{
//            UIView.animate(withDuration: 0.01) { [weak self] () in
//                var rect = self?.proressView?.frame
//                rect?.size.width = (self?.view.frame.size.width ?? ScreenWidth)/100000*4;
//                self?.proressView?.frame = rect ?? CGRect(x: 0, y: 0, width: ScreenWidth, height: 4)
//            }
//        }
//
//    }
    
    @objc private func closePage(_ sender:UIButton){
        if let viewcontrollers = navigationController?.viewControllers{
            if viewcontrollers.count > 1 {
                if viewcontrollers[viewcontrollers.count - 1] == self {
                    navigationController?.popViewController(animated: true)
                    return
                }
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    deinit {
        #if DEBUG
        print("webViewDeinit")
        #endif
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
