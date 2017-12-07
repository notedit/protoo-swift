//
//  Retry.swift
//  protoo
//
//  Created by xiang on 06/12/2017.
//  Copyright © 2017 dotEngine. All rights reserved.
//

import Foundation

open class Retry {
    
    public enum Strategy {
        case immediate
        case delay(seconds: Double)
        case custom(closure: (_ currentIteration: Int, _ lastDelay: TimeInterval?)-> TimeInterval?)
    }
    
    private var closure: ((_ currentAttempt:Int) throws -> Void)?
  
    private let strategy: Strategy
   
    private var operatingQueue: DispatchQueue?
    
    private var errorHandler: ((Error) -> Void)?
    
    private var lastError: Error?
    private var lastDelay: TimeInterval? = nil
    private var deferHandler: (() -> Void)?
    
    public let maxCount: Int
    public var currentRepeat = 0
    public var done: Bool = false
    
    public init(max: Int, strategy: Strategy) {
        self.operatingQueue = DispatchQueue(label: "RetryQueue")
        self.maxCount = max
        self.strategy = strategy
    }
    
    deinit {
        print("deinit retry")
        self.operatingQueue = nil
    }
    
    private func threadSafe(handler: @escaping ()-> Void) {
        if let queue = operatingQueue {
            queue.async(execute: handler)
        }
    }
    
    
    private var delayDuration: TimeInterval? {
        switch strategy {
        case .immediate: return 0
        case .delay(let delay): return delay
        case .custom(let closure):
            if let delay = closure(currentRepeat, lastDelay) {
                lastDelay = delay
                return delay
            }
            return nil
        }
    }
    
    private func _retry() {
        currentRepeat += 1
        guard self.currentRepeat < self.maxCount else {
            return
        }
        running()
    }
    
    public func retry() {
        
        print("retry")
        
        guard let delay = delayDuration else {
            return
        }
        
        if let queue = operatingQueue {
            queue.asyncAfter(deadline: .now() + delay, execute: _retry)
        }
    }
    
    public func stop() {
        print("stop")
        self.done = true
    }
    
    public func attempt(closure: @escaping (_ currentAttempt:Int) throws -> Void){
        self.closure = closure
        self.running()
    }
    
    fileprivate func running(){
        
        if self.done {
            return
        }
        
        do {
            try closure!(currentRepeat)
        }
        catch {
            print(error.localizedDescription)
            
        }
        
    }
}


