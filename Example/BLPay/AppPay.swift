//
//  AppPay.swift
//  BLPay_Example
//
//  Created by lin bo on 2019/8/7.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation

/// 商品列表
enum ACG_PAY_ID: BL_APP_ID {
    
    case pay50
    case pay98
    case pay148
    case pay198
    case pay248
    case pay298
    
    func value() -> String {
        
        switch self {
        case .pay50:
            return "ACG_PAY_50"
        case .pay98:
            return "ACG_PAY_98"
        case .pay148:
            return "ACG_PAY_148"
        case .pay198:
            return "ACG_PAY_198"
        case .pay248:
            return "ACG_PAY_248"
        case .pay298:
            return "ACG_PAY_298"
        }
    }
    
    func price() -> Int {
        
        switch self {
            
        case .pay50: return 50
        case .pay98: return 98
        case .pay148: return 148
        case .pay198: return 198
        case .pay248: return 248
        case .pay298: return 298
        }
    }
}

class AppPay {
    
    static let shared = AppPay()
    
    func configIAP() {
        
        // 设置商品列表
        BLPay.shared.configApplePay(keychainGroup: "my app share key chain",
                                    productIDs: [ACG_PAY_ID.pay50,
                                                 ACG_PAY_ID.pay98,
                                                 ACG_PAY_ID.pay148,
                                                 ACG_PAY_ID.pay198,
                                                 ACG_PAY_ID.pay248,
                                                 ACG_PAY_ID.pay298])
        
        /// 注册支付后端校验
          BLPay.shared.regiestPayCheckBlock { (payload, callback) in
              
            self.requestCheckIAP(payload: payload) { (b) in
                  callback(b)
              }
          }
        
        /// 在一次充值情况下 提示用户,进入支付业务场景就失效了
        BLPay.shared.setProgressCallback { (result, id) in
            
            switch result {
            case .checking:
                BLShowAlert("充值中")
            case .checkedSuccess:
                BLShowAlert("充值成功")
            case .checkedButError:
                BLShowAlert("服务器验证失败")
            case .checkedFailed:
                BLShowAlert("充值失败，请检测网络")
            default:
                break
            }
        }
    }
    
    /// App服务器接口请求
    fileprivate func requestCheckIAP(payload: BLPayloadModel, callback:@escaping ((BLIAPResultCheck) -> ())) {

        // 模拟成功业务
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            
            callback(.checkedSuccess)
        }
        
        /* 业务代码
        guard UserHelper.checklogin() else {
            callback(.checkedFailed)
            return
        }
        
        OrderServer.shared.requestCheckIAP(data) {(code, msg, result) in
            
            switch code {
            case CODE_SUCCESS:
                callback(.checkedSuccess)
            case 1023:
                callback(.checkedButError)
            default:
                callback(.checkedFailed)
            }
        }
        */
    }
    
    /// 购买
    @discardableResult
    func pay(_ id: ACG_PAY_ID) -> Bool {
        
        var item = BLPayItem()
        item.iapPriductId = id
        item.userID = "UserHelper...userID"

        return BLPay.shared.pay(item: item)
    }
}
