//
//  SubChannelController.swift
//  AgoraDualChannels
//
//  Created by ZhangJi on 2018/6/21.
//  Copyright © 2018 ZhangJi. All rights reserved.
//

import UIKit
import AgoraRtcEngineKit

@objc protocol SubRtcEngineDelegate: NSObjectProtocol {
    @objc optional func subRtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int)
    @objc optional func subRtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int)
    @objc optional func subRtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraRtcStats)
    @objc optional func subRtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraRtcUserOfflineReason)
    @objc optional func subRtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraRtcWarningCode)
    @objc optional func subRtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraRtcErrorCode)
}

class SubRtcEngineController: NSObject {
    
    weak var delegate: SubRtcEngineDelegate?
    
    convenience init(delegate: SubRtcEngineDelegate) {
        self.init()
        self.delegate = delegate
    }
    
    override init() {
        super.init()
    }
}

extension SubRtcEngineController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        delegate?.subRtcEngine?(engine, didJoinChannel: channel, withUid: uid, elapsed: elapsed)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        delegate?.subRtcEngine?(engine, didJoinedOfUid: uid, elapsed: elapsed)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraRtcUserOfflineReason) {
        delegate?.subRtcEngine?(engine, didOfflineOfUid: uid, reason: reason)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraRtcStats) {
        delegate?.subRtcEngine?(engine, didLeaveChannelWith: stats)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraRtcWarningCode) {
        delegate?.subRtcEngine?(engine, didOccurWarning: warningCode)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraRtcErrorCode) {
        delegate?.subRtcEngine?(engine, didOccurError: errorCode)
    }
}
