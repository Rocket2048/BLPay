//
//  BLPay.swift
//  BLPay
//
//  Created by lin bo on 2020/4/16.
//

import Foundation

func BLShowAlert(_ msg: String) {
    print("BLShowAlert: " + msg)
}

func BLPayALog(_ msg: String) {
    print("BLPayALog: " + msg)
}

public enum BLPayWay {
    
    case applePay
}

public struct BLPayItem {
    
    public init() {
        
    }
    
    // 内购需要指定ID
    public var iapPriductId: BL_APP_ID?
    
    /// 其他附加参数
    public var userID: String?
    public var name: String?
    public var price: Float = 0.0
    public var orderId: String?
    public var orderNo: String?
    public var remark: String?
    public var payWay: BLPayWay = .applePay
}

public class BLPay {
    
    public static let shared = BLPay()
    
    /// 设置内购商品IDs
    public func configApplePay(keychainGroup: String, productIDs: [BL_APP_ID]) {
        
        BLIAPHelper.shared.configApplePay(keychainGroup: keychainGroup, productIDs: productIDs)
    }
    
    /// 设置支付过程回调
    public func setProgressCallback(callback: ((_ type: BLIAPProgress, _ pID: BL_APP_ID?) -> ())?) {
        
        BLIAPHelper.shared.setProgressCallback(callback: callback)
    }
    
    /// 设置校验接口
    public func regiestPayCheckBlock(callback: @escaping BLCheckCallback) {
        
        BLIAPHelper.shared.regiestPayCheckBlock(callback: callback)
    }
    
    /// 苹果支付手动提交后端检测
    public func submitIAPCheck() {
                
        BLIAPHelper.shared.submitCheck()
    }
    
    /// 支付入口
    ///
    /// - Parameter item: 支付参数模型
    /// - Returns: 是否允许支付
    @discardableResult
    public func pay(item: BLPayItem) -> Bool {
        
        switch item.payWay {
        case .applePay:
            return applePay(item: item)
        }
    }
    
    /// 苹果支付
    /// 1、若未初始化，则会自动执行一次初始化
    /// 2、若有单未提交后台校验，则会再次尝试提交后台
    /// - Parameter item: 支付参数
    fileprivate func applePay(item: BLPayItem) -> Bool {
        
        guard let id = item.iapPriductId else {
            BLPayALog("支付参数错误")
            return false
        }
        let p = BLIAPHelper.shared.pay(pID: id, userID: item.userID)
        var result = false
        
        switch p {
        case .ok:
            result = true
            break
        case .notInit, .initFailed:// 第一次初始化失败的情况下，尝试在初始化一次
            BLIAPHelper.shared.initPayments { (c) in
                
                if c == .ok {
                    
                    if BLIAPHelper.shared.pay(pID: id, userID: item.userID) == .ok {
                        result = true
                    }
                }
            }
        case .needCheck:// 支付时，若有单未完成，先完成这一单
            submitIAPCheck()
        default:
            break
        }
        return result
    }
}
