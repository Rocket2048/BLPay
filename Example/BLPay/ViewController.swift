//
//  ViewController.swift
//  BLPay
//
//  Created by ok@linbok.com on 04/16/2020.
//  Copyright (c) 2020 ok@linbok.com. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    func updateHUD(_ b: Bool, text: String = "") {
        print("updateHUD \(b)" + text)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func butAction(_ sender: Any) {
        
        /// 支付入口
        AppPay.shared.pay(.pay50)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /// 支付过程回调（App启动的时候可能也会触发）
        BLPay.shared.setProgressCallback {[weak self] (result, pID) in
            guard let vc = self else {
                return
            }
            
            switch result {
                
            case .none:
                break
                
            case .started:
                vc.updateHUD(true, text: "支付中")
                
            case .purchasing:
                break
                
            case .purchased:
                break
                
            case .payFailed:
                vc.updateHUD(false)
                BLPayALog("支付取消")
            case .payRestored:
                vc.updateHUD(false)
                
            case .payDeferred:
                vc.updateHUD(false)
                
            case .payOther:
                vc.updateHUD(false)
                
            case .checking:
                vc.updateHUD(true, text: "充值中")
                
            case .checkedSuccess:
                vc.updateHUD(false)
                BLPayALog("充值成功")
                //                vc.updateData()
                
            case .checkedButError:
                vc.updateHUD(false)
                BLPayALog("服务器验证失败")
                //                vc.updateData()
                
            case .firstCheckedFailed:
                vc.updateHUD(false)
                
            case .checkedFailed:
                vc.updateHUD(false)
                BLPayALog("充值失败，请检测网络")
                //                vc.updateData()
            case .tryChecking:
                BLPayALog("正在恢复历史订单")

            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        
        /// 离开页面清除回调（也可全局监听）
        BLIAPHelper.shared.setProgressCallback(callback: nil)
    }
}

