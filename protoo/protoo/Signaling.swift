//
//  Peer.swift
//  protoo
//
//  Created by xiang on 05/12/2017.
//  Copyright © 2017 dotEngine. All rights reserved.
//

import Foundation
import SwiftyJSON

let REQUEST_TIMEOUT = 20.0

class RequestHandler {
    public let request:Request
    public var timer:Timer?
    private var timeoutHandler: (() -> Void)?
    private var resolveHandler: (() -> Void)?
    private var rejectHandler: (() -> Void)?
    init(request:Request) {
        self.request = request
    }
    func resolve(){
        self.resolveHandler!()
    }
    func rejct(){
        self.rejectHandler!()
    }
    func start() {
        self.timer = setTimeout(REQUEST_TIMEOUT, block: {
            self.timeoutHandler!()
        })
    }
    @discardableResult
    public func resolveBlock(_ block:@escaping ()->Void) -> Self {
        
        self.resolveHandler = block
        return self
    }
    @discardableResult
    public func rejectBlock(_ block:@escaping ()->Void) -> Self {
        
        self.rejectHandler = block
        
        return self
    }
    @discardableResult
    public func timeoutBlock(_ block:@escaping () ->Void) -> Self {
        self.timeoutHandler = block
        return self
    }
    func setTimeout(_ delay:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: delay, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: false)
    }
}

public protocol SignalingDelegate: class {
    func signalingDidClose()
    func signalingConnecting(attempt:Int)
    func signalingDidOpen()
    func signalingDisconnected()
    func signalingOnRequest(message:Any, accept:@escaping (_ data:Any) -> Void, rejct:@escaping (_ errorCode:Int,_ errorReason:String) -> Void)
}

class Signaling : TansportDelegate {
    private var requestHandlers:[Int:RequestHandler]
    
    public let transport: WebSocketTransport?
    public var closed:Bool
    public var data:[String:Any]
    
    public var delegate:SignalingDelegate?
    
    init(transport:WebSocketTransport) {
        self.transport = transport
        self.closed = false
        self.data = [String:Any]()
        self.requestHandlers = [Int:RequestHandler]()
    }
    public func send(method:String, data:Any,block:@escaping (_ response:Response?)->Void){
        let request = Message.requestFactory(method:method,data:data)
        let sended = self.transport!.send(message: request)
        
        if sended {
            let requestHandler = RequestHandler(request:request)
            requestHandler
            .resolveBlock {
                if self.requestHandlers[request.id] == nil {
                    return
                }
                self.requestHandlers.removeValue(forKey: request.id)
                requestHandler.timer!.invalidate()
                block(nil)
            }
            .rejectBlock {
                if self.requestHandlers[request.id] == nil {
                    return
                }
                self.requestHandlers.removeValue(forKey: request.id)
                requestHandler.timer!.invalidate()
                block(nil)
            }
            .timeoutBlock {
                if self.requestHandlers[request.id] == nil {
                    return
                }
                self.requestHandlers.removeValue(forKey: request.id)
                block(nil)
            }
            .start()
            self.requestHandlers[request.id] = requestHandler
        }
    }
    public func close() {
        
        if self.closed {
            return
        }
        self.closed = true
        self.transport?.close()
        
        // todo ? do we need clear requestHandlers
        
        self.delegate?.signalingDidClose()
    }
    
}

// TansportDelegate
extension Signaling {
    
    func transportDidClose(){
        
        if self.closed {
            return
        }
        self.closed = true
        self.delegate?.signalingDidClose()
    }
    func transportConnecting(attempt:Int) {
        self.delegate?.signalingConnecting(attempt: attempt)
    }
    func transportDidOpen(){
        if self.closed {
            return
        }
        self.delegate?.signalingDidOpen()
    }
    func transportDisconnected(){
        self.delegate?.signalingDisconnected()
    }
    
    func transportDidReceiveMessage(message:Any){
        if let mess = message as? Request {
            self.handleRequest(request: mess)
        } else if let mess = message as? Response {
            self.handleResponse(response: mess)
        }
    }
    func handleRequest(request:Request){
        
        func accept (data:Any) {
            let response = Message.successResponseFactory(request: request, data: data)
            self.transport?.send(message: response)
        }
        
        func reject (errorCode:Int,errorReason:String) {
            
            let response = Message.errorResponseFactory(request: request, errorCode: errorCode, errorReason: errorReason)
            self.transport?.send(message: response)
        }
        
        self.delegate?.signalingOnRequest(message: request, accept: accept, rejct: reject)
    }
    func handleResponse(response:Response){
        let requestHandler = self.requestHandlers[response.id]
        
        if requestHandler == nil {
            print("can not match handler")
            return
        }
        
        if response.ok {
            // todo
            requestHandler?.resolve()
        } else {
            // todo
            requestHandler?.rejct()
        }
    }
}













