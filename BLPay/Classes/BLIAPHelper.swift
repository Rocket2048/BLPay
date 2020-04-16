//
//  BLIAPHelper.swift
//  BLPay
//
//  Created by lin bo on 2020/4/16.
//
//----------------
//模块:内购
//功能:
//备注:
// php+oc http://www.cnblogs.com/wangboy91/p/7162335.html
// oc https://www.jianshu.com/p/d87a3a3cd916
// java https://blog.csdn.net/jianzhonghao/article/details/79343887
//----------------

import Foundation
import UIKit
import StoreKit
import KeychainAccess

/// 回调状态
public enum BLIAPProgress {
    
    /// 初始状态
    case none
    /// 开始
    case started
    /// 购买中
    case purchasing
    
    /// 支付成功
    case purchased
    /// 失败
    case payFailed
    /// 重复购买
    case payRestored
    /// 状态未确认
    case payDeferred
    /// 其他
    case payOther
    
    /// 前面有订单提交后台失败，现在再次提交 v1.1
    case tryChecking
    /// 开始后端校验
    case checking
    /// 后端校验成功
    case checkedSuccess
    /// 后端校验失败,充值无效
    case checkedButError
    /// 后端第一次校验失败(定时器还会再执行2次)
    case firstCheckedFailed
    /// 后端校验失败
    case checkedFailed
}

/// 后台检测回调
public enum BLIAPResultCheck: Int {
    
    /// 后端校验成功
    case checkedSuccess
    /// 后端校验为沙盒,无效
    case checkedButError
    /// 后端校验失败
    case checkedFailed
}

public enum BLIAPPayCheck {
    
    /// 当前有支付正在进行
    case busy
    /// 前面有订单提交后台失败 v1.1
    case needCheck
    /// 未初始化
    case notInit
    /// 初始化失败
    case initFailed
    /// 没有找到该商品，中断
    case notFound
    /// 系统检测失败
    case systemFailed
    /// 可以进行
    case ok
}

/// apple pay ID协议
public protocol BL_APP_ID {
    
    func value() -> String
    
    func price() -> Int
}

/// 回调的模型
public struct BLPayloadModel {
    
    public var userID: String?
    public var transactionID: String?
    public var productID: String?
    public var payload: String
}

public typealias BLCheckCallback = ((_ payload: BLPayloadModel, (@escaping (BLIAPResultCheck) -> ())) -> ())

public class BLIAPHelper: NSObject {
    
    static let shared = BLIAPHelper()

    var keychainGroup: String?
    
    let keyCurrentUserID        = "BLPayCurrectUserID"
    let keyCurrentProductID     = "BLPayCurrectProductID"
    let keyCurrenttransactionID = "BLPayCurrenttransactionID"
    let keyCurrentPayload       = "BLPayCurrentPayload"

    /// 初始化回调
    fileprivate var initCallback: ((_ b: BLIAPPayCheck) -> ())?
    /// 支付回调
    fileprivate var progressCallback: ((_ type: BLIAPProgress, _ pID: BL_APP_ID?) -> ())?
    /// 检测回调
    fileprivate var checkCallback: BLCheckCallback?

    /// 商品列表
    fileprivate var productIDs: [BL_APP_ID] = []
    
    /// 购买的商品
    fileprivate var checkList: [SKPaymentTransaction] = []
    
    /// 当前付费的App用户ID,每次支付传入,校验完成后清空
    fileprivate var userID: String? {
        
        set {
            guard let keychainGroup = keychainGroup else {
                return
            }
            let keychain = Keychain(service: keychainGroup)

            keychain[keyCurrentUserID] = newValue
        }
        
        get {
            guard let keychainGroup = keychainGroup else {
                return nil
            }
            let keychain = Keychain(service: keychainGroup)
            
            if let value = keychain[keyCurrentUserID] {
                return value
            }
            return nil
        }
    }
    
    /// 当前付费的App productID,每次支付传入,校验完成后清空
    fileprivate var productID: String? {

        set {
            guard let keychainGroup = keychainGroup else {
                return
            }
            let keychain = Keychain(service: keychainGroup)

            keychain[keyCurrentProductID] = newValue
        }
        
        get {
            guard let keychainGroup = keychainGroup else {
                return nil
            }
            let keychain = Keychain(service: keychainGroup)
            
            if let value = keychain[keyCurrentProductID] {
                return value
            }
            return nil
        }
    }
    
    /// 当前付费的App transactionID,每次支付成功传入,校验完成后清空
    fileprivate var transactionID: String? {

        set {
            guard let keychainGroup = keychainGroup else {
                return
            }
            let keychain = Keychain(service: keychainGroup)

            keychain[keyCurrenttransactionID] = newValue
        }
        
        get {
            guard let keychainGroup = keychainGroup else {
                return nil
            }
            let keychain = Keychain(service: keychainGroup)
            
            if let value = keychain[keyCurrenttransactionID] {
                return value
            }
            return nil
        }
    }

    /// 当前付费的App payload,每次支付成功传入,校验完成后清空
    fileprivate var payload: String? {

        set {
            guard let keychainGroup = keychainGroup else {
                return
            }
            let keychain = Keychain(service: keychainGroup)

            keychain[keyCurrentPayload] = newValue
        }
        
        get {
            guard let keychainGroup = keychainGroup else {
                return nil
            }
            let keychain = Keychain(service: keychainGroup)
            
            if let value = keychain[keyCurrentPayload] {
                return value
            }
            return nil
        }
    }

    /// 是否正在支付
    fileprivate var isBusy: Bool {
        get {
            switch progress {
            case .none:
                return false
            default:
                return true
            }
        }
    }
    
    /// 购买的状态
    fileprivate var progress: BLIAPProgress = .none {
        didSet {
            /// 状态改变回调
            if let block = progressCallback {
                block(progress, currentPID)
            }
        }
    }
    
    /// 当前付费的ID
    fileprivate var currentPID: BL_APP_ID?
    /// 商品列表
    fileprivate var productList: [SKProduct]?
    
    /// 设置内购商品IDs
    func configApplePay(keychainGroup: String, productIDs: [BL_APP_ID]) {
        
        self.keychainGroup = keychainGroup
        self.productIDs = productIDs
        SKPaymentQueue.default().add(self)
        requestAllProduct()
    }
    
    /// 初始化，请求商品列表
    func initPayments(_ block: @escaping ((_ b: BLIAPPayCheck) -> ())) {
        
        let c = checkPayments()
        
        if c == .notInit {
            
            requestAllProduct()
            initCallback = block
            
        } else {

            block(c)
        }
    }
    
    /// 手动提交后端检测
    @discardableResult
    func submitCheck() -> Bool {
        
        guard progress == .none else {
            return false
        }
        
        progress = .tryChecking
        completeTransaction()
        return true
    }
    
    /// 设置支付过程回调
    func setProgressCallback(callback: ((_ type: BLIAPProgress, _ pID: BL_APP_ID?) -> ())?) {
        
        progressCallback = callback
    }
    
    /// 注册支付检测回调
    func regiestPayCheckBlock(callback: @escaping BLCheckCallback) {
        
        checkCallback = callback
    }
    
    /// 检测支付环境，非.ok不允许充值
    func checkPayments() -> BLIAPPayCheck {
        
        guard let plist = productList, !plist.isEmpty else {
            return .notInit
        }
        
        guard SKPaymentQueue.canMakePayments() else {
            return .systemFailed
        }
        
        if self.payload != nil {
            return .needCheck
        }
        
        guard isBusy == false else {
            return .busy
        }
        
        return .ok
    }
    
    /// 请求商品列表
    private func requestAllProduct() {
        
        guard productIDs.count > 0 else {
            return
        }
        
        let array: [String] = productIDs.compactMap {
            $0.value()
        }
        
        let set: Set<String> = Set(array)
        
        let request = SKProductsRequest(productIdentifiers: set)
        request.delegate = self
        request.start()
    }
    
    /// 支付商品
    @discardableResult
    func pay(pID: BL_APP_ID, userID: String?) -> BLIAPPayCheck {
        
        let c = checkPayments()
        
        if c == .ok {
            
            self.userID = userID //可以充值后，把userID替换成最新。

            guard let plist = productList, !plist.isEmpty else {
                return .notInit
            }
            
            let pdts = plist.filter {
                return $0.productIdentifier == pID.value()
            }
            
            guard let product = pdts.first else {
                return .notFound
            }
            
            currentPID = pID
            requestProduct(pdt: product)
        }
        
        return c
    }
    
    /// 请求充值
    fileprivate func requestProduct(pdt: SKProduct) {
        
        progress = .started
        
        let pay: SKMutablePayment = SKMutablePayment(product: pdt)
        SKPaymentQueue.default().add(pay)
    }
    
    /// 重置
    fileprivate func payFinish() {
        
        self.checkList.forEach({ (transaction) in
            SKPaymentQueue.default().finishTransaction(transaction)
        })
        self.checkList.removeAll()
        
        currentPID = nil
        progress = .none
    }
    
    /// 校验完成，清除本地缓存
    fileprivate func cleanPayload() {
        
        self.userID = nil
        self.productID = nil
        self.transactionID = nil
        self.payload = nil
    }
    
    /// 充值完成后给业务校验
    func completeTransaction() {
        
        BLPayALog("充值校验中...")
        guard let payload = self.payload else {
            BLPayALog("充值,未取到凭证")
            payFinish()
            cleanPayload()
            return
        }
          
        let payloadModel = BLPayloadModel(userID: userID,
                                     transactionID: transactionID,
                                     productID: productID,
                                     payload: payload)
        
        requestCheck(payload: payloadModel) { (b) in
            
            switch b {
            case .checkedSuccess:
                self.progress = .checkedSuccess
                self.cleanPayload()
                
            case .checkedButError:
                self.progress = .checkedButError
                self.cleanPayload()

            case .checkedFailed:
                self.progress = .checkedFailed
            }
            self.payFinish()
        }
    }
    
    /// 请求业务校验
    fileprivate func requestCheck(payload: BLPayloadModel, time: Int = 3, progressCallback: @escaping ((BLIAPResultCheck) -> ())) {
        
        guard time > 0 else {
            return
        }
        // 若失败 1分钟后 和 10分钟后再校验
        let time = time - 1
        BLPayALog("校验第\(3 - time)次")
        
        if let checkCallback = checkCallback {
                        
            /// 去后台请求
            checkCallback(payload) { result in
                
                if result == .checkedSuccess || result == .checkedButError { // 完成
                    progressCallback(result)
                } else if time <= 0 { // 三次验证完成
                    progressCallback(result)
                } else { // 再次验证
                    
                    if time == 2 {
                        self.progress = .firstCheckedFailed
                    }
                    
                    let delay: TimeInterval = (time == 1 ? 300 : 60)
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: {
                        self.requestCheck(payload: payload, time: time, progressCallback: progressCallback)
                    })
                }
            }
        } else {
            BLPayALog("未注册校验方法")
            progressCallback(.checkedFailed)
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension BLIAPHelper: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        BLPayALog("---IAP---")
        
        if currentPID == nil {
            // 列表赋值
            productList = response.products
        }
    }
    
    private func requestDidFinish(_ request: SKRequest) {
        BLPayALog("---IAP---")
        
        if currentPID == nil {
            
            if let block = initCallback {
                
                if let pList = productList, !pList.isEmpty {
                    block(.ok)
                } else {
                    block(.initFailed)
                }
                initCallback = nil
            }
        }
    }
    
    private func request(_ request: SKRequest, didFailWithError error: Error) {
        BLPayALog("---IAP---")
        
        if currentPID == nil {
            
            if let block = initCallback {
                block(.initFailed)
                initCallback = nil
            }
        }
    }
}

// MARK: - SKPaymentTransactionObserver
extension BLIAPHelper: SKPaymentTransactionObserver {
    
    private func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        BLPayALog("---IAP---")
    }
    
    private func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        BLPayALog("---IAP---")
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        BLPayALog("---IAP---")
        
        checkList.removeAll()
        var type: BLIAPProgress = progress
        
        for transaction in transactions {
            
            BLPayALog("苹果支付回调: \(transaction.payment.productIdentifier)")
            
            let pid = transaction.payment.productIdentifier
            switch transaction.transactionState {
                
            case .purchasing:
                
                BLPayALog("支付中:\(pid)")
                type = .purchasing
                
            case .purchased:
                
                checkList.append(transaction)
                BLPayALog("支付成功:\(pid)")
                type = .purchased
                self.transactionID = transaction.transactionIdentifier
                self.productID = transaction.payment.productIdentifier

            case .failed:
                
                BLPayALog("支付失败:\(pid)")
                type = .payFailed
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .restored:
                
                checkList.append(transaction)
                BLPayALog("支付已购买过:\(pid)")
                type = .payRestored
                self.transactionID = transaction.transactionIdentifier
                self.productID = transaction.payment.productIdentifier

            case .deferred:
                
                BLPayALog("支付不确认:\(pid)")
                type = .payDeferred
                SKPaymentQueue.default().finishTransaction(transaction)
                
            @unknown default:
                
                BLPayALog("支付未知状态:\(pid)")
                type = .payOther
                SKPaymentQueue.default().finishTransaction(transaction)
            }
        }
        
        progress = type
        
        if checkList.count > 0 {
            
            // 有内购，需要后台校验
            progress = .checking
            
            guard let rURL = Bundle.main.appStoreReceiptURL, let data = try? Data(contentsOf: rURL) else {
                BLPayALog("appStoreReceiptURL error")
                progress = .checkedFailed
                payFinish()
                return
            }
            
            let str = data.base64EncodedString()
            print(str)
            
            /// 存起来
            self.payload = str
            
            completeTransaction()

        } else if type == .purchasing {
            // 正常情况：内购正在支付
            // 特殊情况：若该商品已购买，未执行finishTransaction，系统会提示（免费恢复项目），回调中断
            // 解决方法：在应用开启的时候捕捉到restored状态的商品，提交后台校验后执行finishTransaction
            
        } else { // 其他状态
            
            payFinish()
        }
    }
    
    private func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        BLPayALog("---IAP---")
    }
    
    private func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        BLPayALog("---IAP---")
    }
    
    private func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        BLPayALog("---IAP---")
        return true
    }
}
