//
//  WebSocketTransport.swift
//  protoo
//
//  Created by xiang on 05/12/2017.
//  Copyright © 2017 dotEngine. All rights reserved.
//

import Foundation
import Starscream

public protocol TansportDelegate: class {
    func transportDidClose()
    func transportConnecting(attempt:Int)
    func transportDidOpen()
    func transportDisconnected()
    func transportDidReceiveMessage(message:Any)
}


class WebSocketTransport {
    private let url:String
    private let options: [String:Any]?
    private var websocket: WebSocket?
    
    public var closed:Bool = false
    public weak var delegate: TansportDelegate?
    
    init(url:String,options:[String:Any]?) {
        self.url = url
        self.options = options
        self.websocket = nil
        self.closed = false
       
        self.setupWebSocket()
    }
    deinit {
        
    }
    public func close(){
        
        if self.closed {
            return
        }
        
        self.closed = true
        
        self.delegate?.transportDidClose()
        
        self.websocket?.onConnect = nil
        self.websocket?.onDisconnect = nil
        self.websocket?.onText = nil
        self.websocket?.disconnect()
        
    }
    public func send(message:Any) -> Bool {
        if self.closed {
            return false
        }
        if self.websocket != nil && self.websocket!.isConnected {
            self.websocket?.write(string: "")
        }
        return false
    }
    private func setupWebSocket(){
        
        var wasConnected = false
        
        let operation:Retry = Retry(max: 10, strategy: Retry.Strategy.delay(seconds: 5.0))
        
        operation.attempt { currentAttempt in
            
            if self.closed {
                return
            }
            
            var request = URLRequest(url:URL(string:self.url)!)
            request.timeoutInterval = 5
            self.websocket = WebSocket(request:request)
            
            self.websocket?.onConnect = {
                
                if self.closed {
                    return
                }
                wasConnected = true
                self.delegate?.transportDidOpen()
            }
            
            self.delegate?.transportConnecting(attempt: currentAttempt)
            
            self.websocket?.onDisconnect = { (error: Error?) in
                
                if self.closed {
                    return
                }
                
                if (error as! NSError).code != 4000 {
                    if !wasConnected {
                        operation.retry()
                        return
                    } else {
                        operation.stop()
                        self.delegate?.transportDisconnected()
                        self.setupWebSocket()
                        return
                    }
                }
                
                self.closed = true
                self.delegate?.transportDidClose()
            }
            
            self.websocket?.onText = { (text:String) in
                
                if self.closed {
                    return
                }
                
                let message = Message.parse(raw: text)
                
                if message == nil {
                    return
                }
                
                self.delegate?.transportDidReceiveMessage(message: message!)
            }
            
            self.websocket?.onData = { (data:Data) in
                print("onData")
            }
            
        
            self.websocket?.connect()
        }
        
        
    }
}












