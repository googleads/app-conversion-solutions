/*
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import AdSupport
import UIKit


public class CampaignTracker{
    
    private var devToken: String
    private var linkId: String
    private var appEventType: String = "first_open"
    private var rdid: String
    private var idType: String = "idfa"
    private var lat: String
    private var appVersion: String
    private var osVersion: String
    private var sdkVersion: String
    private var attributed: Bool = false
    private var campaignId: Int64?
    private var campaignName: String?
    private var adGroupId: Int64?
    private var adGroupName: String?
    private var adClickTime: Double
    private var timestampInvalidCount: Int
    private var backoffTimeArr: [Int]
    
    init(devToken: String, linkId: String){
        
        self.devToken = devToken
        self.linkId = linkId
        appVersion =  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        sdkVersion = appVersion
        osVersion = UIDevice.current.systemVersion
        adClickTime = 0
        
        let identifierManager = ASIdentifierManager.shared()
        if identifierManager.isAdvertisingTrackingEnabled {
            rdid = identifierManager.advertisingIdentifier.uuidString
            lat = "0"
        }else{
            rdid = ""
            lat = "1"
        }
        timestampInvalidCount = 0
        //todo cutomize backoff time to fit your scenario
        backoffTimeArr = [1,3,5,7,9,11,13]
    }
    
    
    /// 获取安装对应的广告信息
    /// - Parameters:
    ///   - tryTimes: 最多获取google广告点击信息的次数，为1表示不重试
    ///   - timeoutSeconds: 单次获取广告点击信息的超时时间，单位是秒
    ///   - success: 成功获取到广告信息后执行逻辑
    ///   - fail: 获取失败后的执行逻辑
    public func acquireCampaignInfo(tryTimes: Int, timeoutSeconds: Double, success: @escaping() -> Void, fail: @escaping() -> Void) -> Void{
        acquireCampaignInfo(tryTimes: tryTimes, timeoutSeconds: timeoutSeconds, backoffTime: 0, success: success, fail: fail)
    }
    
    /// 获取带来安装的对应的广告campaignid, 如果在设置的时间窗口内没有，返回-1
    /// - Parameter days: 回溯的时间窗口，按天计算，发生在该时间窗口外的广告点击将不会被返回
    public func fetchCampaignIdWithinDays(days: Int) -> Int64?{
        if !attributed{
            return -1
        }
        let now = Date()
        if let deadline = Calendar.current.date(byAdding: .day, value: -days, to: now), deadline.timeIntervalSince1970 <= adClickTime{
            // 广告点击时间在时间窗口内
            return campaignId
        }
        return -1
    }
    
    
    /// 获取带来安装的对应的广告campaign name, 如果在设置的时间窗口内没有，返回空字符串
    /// - Parameter days: 回溯的时间窗口，按天计算，发生在该时间窗口外的广告点击将不会被返回
    public func fetchCampaignNameWithinDays(days: Int) -> String?{
        if !attributed{
            return nil
        }
        let now = Date()
        if let deadline = Calendar.current.date(byAdding: .day, value: -days, to: now), deadline.timeIntervalSince1970 <= adClickTime{
            // 广告点击时间在时间窗口内
            return campaignName
        }
        return nil
    }
    
    /// 获取带来安装的对应的广告ad group id, 如果在设置的时间窗口内没有，返回-1
    /// - Parameter days: 回溯的时间窗口，按天计算，发生在该时间窗口外的广告点击将不会被返回
    public func fetchAdGroupIdWithinDays(days: Int) -> Int64?{
        if !attributed{
            return -1
        }
        let now = Date()
        if let deadline = Calendar.current.date(byAdding: .day, value: -days, to: now), deadline.timeIntervalSince1970 <= adClickTime{
            // 广告点击时间在时间窗口内
            return adGroupId
        }
        return -1
    }
    
    
    /// 获取带来安装的对应的广告ad group name, 如果在设置的时间窗口内没有，返回空字符串
    /// - Parameter days: 回溯的时间窗口，按天计算，发生在该时间窗口外的广告点击将不会被返回
    public func fetchAdGroupNameWithinDays(days: Int) -> String?{
        if !attributed{
            return nil
        }
        let now = Date()
        if let deadline = Calendar.current.date(byAdding: .day, value: -days, to: now), deadline.timeIntervalSince1970 <= adClickTime{
            // 广告点击时间在时间窗口内
            return adGroupName
        }
        return nil
    }
    
    
    private func isNetworkRetriableError(error: Error?)->Bool{
        
        if let error = error as NSError?, error.domain == NSURLErrorDomain && (error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorTimedOut) {
            // 无网络链接或者超时，重试
            // todo 打点记录错误码
            return true
        }
        return false;
        
    }
    
    private func isTimestampInvalid(data: Data?)->Bool{
        //检查response的body中是否有timestamp invalid错误码
        if let data = data{
            do {
                let jsonResult =  try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                if let errorCodes:[String] = jsonResult["errors"] as? [String], errorCodes.contains("timestamp_invalid") {
                    // todo 打印该错误码
                    return true
                }
            }catch {
                return false;
            }
        }
        return false
    }
    
    private func calBackOffTime()->Int{
        // 重试次数超过配置的重试时间个数，默认为3s
        if self.timestampInvalidCount > self.backoffTimeArr.count-1{
            return 3
        }
        let backoffTime = self.backoffTimeArr[self.timestampInvalidCount]
        self.timestampInvalidCount = self.timestampInvalidCount+1
        return backoffTime
    }
    private func acquireCampaignInfo(tryTimes: Int, timeoutSeconds: Double, backoffTime:Int, success: @escaping () -> Void, fail: @escaping () -> Void) -> Void{
        guard tryTimes > 0 else{
            return
        }
        
        let urlRequest:URLRequest = buildURLRequest(timeoutSeconds: timeoutSeconds, backoffTime: backoffTime)
        let task = URLSession.shared.dataTask(with: urlRequest){
            data, response, error in
            do {
                // http请求出现错误
                if error != nil{
                    //判断是否可以重试的网络错误
                    if self.isNetworkRetriableError(error: error){
                        self.acquireCampaignInfo(tryTimes: tryTimes-1, timeoutSeconds: timeoutSeconds, backoffTime: 0, success: success, fail: fail)
                        return
                    }
                    // 非可重试的错误, todo 打印日志，结束
                    fail()
                    return
                }
                // http请求成功的情况下，判断是否有可重试的业务异常
                if self.isTimestampInvalid(data: data){
                    // todo 打印日志，重试
                    self.acquireCampaignInfo(tryTimes: tryTimes-1, timeoutSeconds: timeoutSeconds, backoffTime:self.calBackOffTime(),success: success, fail: fail)
                    return
                }
                
                // 解析数据
                try self.parseResult(data: data)
                
                // 成功寻找到对应的广告点击，打印日志，继续执行DDL的后续逻辑
                if self.isAttributed(){
                    
                    // todo 打印日志
                    // 获取campaign 信息，继续后续逻辑
                    success()
                    return
                }
                
                // 未找到对应的广告点击，打印日志，不触发DDL,执行DDL触发失败的逻辑
                fail()
                
            }catch {
                // todo 异常处理，打印日志
                // 不触发DDL，执行DDL触发失败的逻辑
                fail()
            }
        }
        task.resume()
        
    }
    
    
    private func buildURLRequest(timeoutSeconds: Double, backoffTime: Int) -> URLRequest{
        var curTimestampInSeconds : Double = Date().timeIntervalSince1970
        curTimestampInSeconds = curTimestampInSeconds - Double(backoffTime) //为了防止客户端时间早于server时间，回退
        
        let trackingURL: String = "https://www.googleadservices.com/pagead/conversion/app/1.0?dev_token="+devToken+"&link_id="+linkId+"&app_event_type="+appEventType+"&rdid="+rdid+"&id_type="+idType+"&lat="+lat+"&app_version="+appVersion+"&os_version="+osVersion+"&sdk_version="+sdkVersion+"&timestamp="+String(format: "%.6f", curTimestampInSeconds)
        
        let url = URL(string: trackingURL)!
        var request : URLRequest = URLRequest(url: url)
        request.httpMethod = "POST"
        let postString = "{}"
        request.httpBody = postString.data(using: .utf8)
        request.timeoutInterval = timeoutSeconds
        
        return request;
    }
    
    private func parseResult(data: Data?)throws -> Void{
        
        if data == nil{
            return
        }
        let jsonResult =  try JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
        
        if let attributed = jsonResult["attributed"] as? Int, attributed == 0{
            // 该安装没有找到对应的广告点击信息
            self.attributed=false
            if let errorCodes:[String] = jsonResult["errors"] as? [String], errorCodes.count>0 {
                //todo 打印错误码
                
            }
            return
        }
        self.attributed=true
        let adEventsArray = jsonResult["ad_events"] as! [Any]
        for adEvent in adEventsArray {
            
            if let adEventDict = adEvent as? [String: Any], let curCampaignId = adEventDict["campaign_id"] as? Int64, let curCampaignName = adEventDict["campaign_name"] as? String,
                let curAdGroupId = adEventDict["ad_group_id"] as? Int64, let curAdGroupName = adEventDict["ad_group_name"] as? String,
                let curAdClickTime = adEventDict["timestamp"] as? Double{
                if (curAdClickTime > self.adClickTime) {
                    //更新广告点击信息
                    self.campaignId = curCampaignId
                    self.campaignName = curCampaignName
                    self.adClickTime = curAdClickTime
                    self.adGroupId = curAdGroupId
                    self.adGroupName = curAdGroupName
                }
                
            }
        }
    }
    
    
    public func getAdClickTime() -> Double{
        return self.adClickTime
    }
    
    public func getCampaignId() -> Int64?{
        return self.campaignId
    }
    public func getCampaignName() -> String?{
        return self.campaignName
    }
    
    public func getAdGroupId() -> Int64?{
        return self.adGroupId
    }
    public func getAdGroupName() -> String?{
        return self.adGroupName
    }
    
    public func isAttributed() -> Bool{
        return self.attributed
    }
    
}



extension LosslessStringConvertible {
    var string: String { return .init(self) }
}

