//
//  Message.swift
//  protoo
//
//  Created by xiang on 05/12/2017.
//  Copyright © 2017 dotEngine. All rights reserved.
//

import Foundation
import SwiftyJSON

struct Request {
    public var request: Bool = true
    public var id : Int = 0
    public var method: String = ""
    public var data: Any?
}

struct Response {
    public var response: Bool = true
    public var id : Int = 0
    public var ok : Bool = true
    public var errorCode: Int?
    public var errorReason: String?
    public var data : Any?
}


func randomNumber(MIN: UInt32, MAX: UInt32)-> Int{
    return Int(arc4random_uniform(UInt32(MAX)) + UInt32(MIN));
}


struct Message {
    
    // Request   Response  or nil
    public static func parse(raw:String) -> Any? {
        
        let json = JSON(parseJSON:raw)
        
        if !json["id"].exists() {
            print("id does not exist")
            return nil
        }
        
        if let _ = json["request"].bool {
            var request = Request()
            request.id = json["id"].int!
            request.method = json["method"].string!
            request.request = true
            request.data = json["data"]
            return request
        } else if let _ = json["response"].bool {
            var response = Response()
            response.id = json["id"].int!
            response.response = true
            response.ok = json["ok"].bool!
            response.data = json["data"]
            if !response.ok {
                response.errorCode = json["errorCode"].int
                response.errorReason = json["errorReason"].string
            }
            return response
        }
        return nil
    }
    public static func requestFactory(method:String, data:Any) -> Request{
        var request = Request()
        request.request = true
        request.id = randomNumber(MIN:100,MAX: UInt32.max)
        request.method = method
        request.data = JSON(data)
        return request
    }
    public static func successResponseFactory(request:Request,data:Any) -> Response{
        var response = Response()
        response.response = true
        response.id = request.id
        response.ok = true
        response.data = JSON(data)
        return response
    }
    public static func errorResponseFactory(request:Request,errorCode:Int,errorReason:String?) -> Response{
        var response = Response()
        response.response = true
        response.id = request.id
        response.ok = false
        response.errorCode = errorCode
        response.errorReason = errorReason
        return response
    }
}


