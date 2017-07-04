//
//  ChatRoom.swift
//  DogeChat
//
//  Created by yesway on 2017/7/4.
//  Copyright © 2017年 Luke Parham. All rights reserved.
//

import UIKit

protocol ChatRoomDelegate: class {
    func receivedMessage(message: Message)
}

class ChatRoom: NSObject {
    
    var inputStream: InputStream!
    var outputStream: OutputStream!
    
    var userName: String = ""
    
    let maxReadLength = 4096
    
    weak var delegate: ChatRoomDelegate?
    
    func setupNetworkCommunication() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, "localhost" as CFString, 80, &readStream, &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        
        inputStream.delegate = self
        
        inputStream.schedule(in: .current, forMode: .commonModes)
        outputStream.schedule(in: .current, forMode: .commonModes)
        
        inputStream.open()
        outputStream.open()
    }
    
    func joinChat(username: String) {
        let data = "iam:\(username)".data(using: .ascii)!
        
        self.userName = username
        
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
    
    func sendMessage(message: String) {
        let data = "msg:\(message)".data(using: .ascii)!
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
    
    fileprivate func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0 {
                if let _ = stream.streamError {
                    break
                }
            }
            
            if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
                delegate?.receivedMessage(message: message)
            }
        }
    }
    
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                        length: Int) -> Message? {
        //1
        guard let stringArray = String(bytesNoCopy: buffer,
                                       length: length,
                                       encoding: .ascii,
                                       freeWhenDone: true)?.components(separatedBy: ":"),
            let name = stringArray.first,
            let message = stringArray.last else {
                return nil
        }
        //2
        let messageSender:MessageSender = (name == self.userName) ? .ourself : .someoneElse
        //3
        return Message(message: message, messageSender: messageSender, username: name)
    }
    
    func stopChatSession() {
        inputStream.close()
        outputStream.close()
    }
}
extension ChatRoom: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("new message received")
            readAvailableBytes(stream: aStream as! InputStream)
        case Stream.Event.endEncountered:
            print("new message received")
            stopChatSession()
        case Stream.Event.errorOccurred:
            print("error occurred")
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
//        case Stream.Event.openCompleted:
            
        default:
            print("some other event...")
            break
        }
    }
}
