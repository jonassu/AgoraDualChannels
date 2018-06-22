//
//  LiveRoomViewController.swift
//  AgoraDualChannels
//
//  Created by ZhangJi on 2018/6/15.
//  Copyright © 2018 ZhangJi. All rights reserved.
//

import UIKit
import AgoraRtcEngineKit

class LiveRoomViewController: UIViewController {
    
    @IBOutlet weak var hostContainerView: UIView!
    @IBOutlet weak var subContainView: UIView!
    @IBOutlet weak var broadcastButton: UIButton!
    @IBOutlet weak var audioMuteButton: UIButton!
    @IBOutlet weak var subRoomButton: UIButton!
    @IBOutlet weak var logTableView: UITableView!
    
    var roomName: String!
    var clientRole: AgoraRtcClientRole!
    var videoProfile: AgoraRtcVideoProfile!
    
    var subRoomName: String?
    var subClientRole: AgoraRtcClientRole?
    
    var scrollContainView = UIScrollView()

    //MARK: - engine & session view
    var rtcEngine: AgoraRtcEngineKit!
    fileprivate var isBroadcaster: Bool {
        return clientRole == .clientRole_Broadcaster
    }
    
    fileprivate var isMuted = false {
        didSet {
            rtcEngine?.muteLocalAudioStream(isMuted)
            audioMuteButton?.setImage(UIImage(named: isMuted ? "btn_mute_cancel" : "btn_mute"), for: .normal)
        }
    }
    
    fileprivate var isInSubChannel = false {
        didSet {
            subRoomButton.setImage(UIImage(named: isInSubChannel ? "btn_leaveroom" : "btn_addroom"), for: .normal)
        }
    }
    
    fileprivate var videoSessions = [VideoSession]() {
        didSet {
            updateInterface(withType: .main, withAnimation: true)
        }
    }
    
    fileprivate var videoSubSessions = [VideoSession]() {
        didSet {
            updateInterface(withType: .sub, withAnimation: true)
        }
    }
    
    fileprivate let viewLayouter = VideoViewLayouter()
    
    var logList =  [LogMessage]() {
        didSet {
            guard let tableView = logTableView else {
                return
            }
            
            tableView.beginUpdates()
            if logList.count > 100 {
                logList.removeFirst()
                tableView.deleteRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
            let insertIndexPath = IndexPath(row: logList.count - 1, section: 0)
            tableView.insertRows(at: [insertIndexPath], with: .none)
            tableView.endUpdates()
            
            tableView.scrollToRow(at: insertIndexPath, at: .bottom, animated: false)
        }
    }
    
    var subController: SubRtcEngineController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logTableView.rowHeight = UITableViewAutomaticDimension
        logTableView.estimatedRowHeight = 20
        
        subController = SubRtcEngineController(delegate: self)
        
        loadAgoraKit()
    }
    
    deinit {
        print("deinit")
    }

    //MARK: - user action
    @IBAction func doSwitchCameraPressed(_ sender: UIButton) {
        rtcEngine?.switchCamera()
    }
    
    @IBAction func doMutePressed(_ sender: UIButton) {
        isMuted = !isMuted
    }
    
    @IBAction func doBroadcastPressed(_ sender: UIButton) {
    }
    
    @IBAction func doAddRoomPressed(_ sender: UIButton) {
        if isInSubChannel {
            leaveChannel(withType: .sub)
//            isInSubChannel = false
            return
        }
        let popView = PopView.newPopViewWith(buttonTitle: "Join", placeholder: "Sub Channel Name")
        popView?.frame = CGRect(x: 0, y: ScreenHeight, width: ScreenWidth, height: ScreenHeight)
        popView?.delegate = self
        self.view.addSubview(popView!)
        UIView.animate(withDuration: 0.2) {
            popView?.frame = self.view.frame
        }
    }
    
    @IBAction func doLeavePressed(_ sender: UIButton) {
        leaveChannel(withType: .main)
        self.dismiss(animated: true, completion: nil)
    }
}

private extension LiveRoomViewController {
    func updateInterface(withType type: ChannelType, withAnimation animation: Bool) {
        if animation {
            UIView.animate(withDuration: 0.3) {
                self.updateInterface(withType: type)
                self.view.layoutIfNeeded()
            }
        } else {
            updateInterface(withType: type)
        }
    }
    
    func updateInterface(withType type: ChannelType) {
        switch type {
        case .main:
            scrollContainView.frame = CGRect(x: 0.0, y: 20.0, width: ScreenWidth, height: 128.0)
            scrollContainView.contentSize = CGSize(width: 128 * (videoSessions.count), height: 0)
            var count = 0
            for session in videoSessions {
                session.hostingView.frame = CGRect(x: 129 * count, y: 0, width: Int(scrollContainView.frame.height), height: Int(scrollContainView.frame.height))
                count += 1
                scrollContainView.addSubview(session.hostingView)
            }
            self.hostContainerView.addSubview(scrollContainView)
            scrollContainView.contentOffset = CGPoint(x: 0, y: 0)
        case .sub:
//            var displaySessions = videoSubSessions
            viewLayouter.layout(sessions: videoSubSessions, fullSession: nil, inContainer: subContainView)
//            setStreamType(forSessions: displaySessions, fullSession: fullSession)
        }
//        caculateDisplaySessions()
    }
    
    func setIdleTimerActive(_ active: Bool) {
        UIApplication.shared.isIdleTimerDisabled = !active
    }
    
    func addLocalSession() {
        let localSession = VideoSession.localSession()
        videoSessions.append(localSession)
        rtcEngine.setupLocalVideo(localSession.canvas)
    }
    
    func fetchSession(ofUid uid: UInt, forChannel channel: ChannelType) -> VideoSession? {
        for session in channel == .main ? videoSessions : videoSubSessions {
            if session.uid == uid {
                return session
            }
        }
        return nil
    }
    
    func videoSession(ofUid uid: UInt, forChannel channel: ChannelType) -> VideoSession {
        if let fetchedSession = fetchSession(ofUid: uid, forChannel: channel) {
            return fetchedSession
        } else {
            let newSession = VideoSession(uid: uid)
            channel == .main ? videoSessions.append(newSession) : videoSubSessions.append(newSession)
            return newSession
        }
    }
    
    func leaveChannel(withType type: ChannelType) {
        switch type {
        case .main:
            setIdleTimerActive(true)
            rtcEngine.setupLocalVideo(nil)
            if isBroadcaster {
                rtcEngine.stopPreview()
            }
            if isInSubChannel {
                leaveChannel(withType: .sub)
            }
            rtcEngine.leaveChannel(nil)
            for session in videoSessions {
                session.hostingView.removeFromSuperview()
            }
            videoSessions.removeAll()
        case .sub:
            rtcEngine.leaveSubChannel(nil)
            for session in videoSubSessions {
                session.hostingView.removeFromSuperview()
            }
            videoSubSessions.removeAll()
        }
    }
}

//MARK: -Agora engine
private extension LiveRoomViewController {
    func loadAgoraKit() {
        rtcEngine = AgoraRtcEngineKit.sharedEngine(withAppId: KeyCenter.AppId, delegate: self)
        rtcEngine.setChannelProfile(.channelProfile_LiveBroadcasting)
        rtcEngine.enableDualStreamMode(true)
        rtcEngine.enableVideo()
        rtcEngine.setVideoProfile(videoProfile, swapWidthAndHeight: true)
        rtcEngine.setClientRole(clientRole, withKey: nil)
        
        if isBroadcaster {
            rtcEngine.startPreview()
        }
        
        addLocalSession()
        
        let code = rtcEngine.joinChannel(byKey: nil, channelName: roomName, info: nil, uid: 0, joinSuccess: nil)
        if code == 0 {
            setIdleTimerActive(false)
            rtcEngine.setEnableSpeakerphone(true)
        } else {
            logList.append(LogMessage(type: .error, channel: .main, message: "Join channel failed: \(code)"))
        }
    }
}


// MARK: -Agora Engine Delegate
extension LiveRoomViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        logList.append(LogMessage(type: .info, channel: .main, message: "did join channel \(channel) success with uid: \(uid)"))
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        logList.append(LogMessage(type: .info, channel: .main, message: "did join channel of uid: \(uid)"))
        let remoteSession = videoSession(ofUid: uid, forChannel: .main)
        rtcEngine.setupRemoteVideo(remoteSession.canvas)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraRtcWarningCode) {
//        logList.append(LogMessage(type: .warning, channel: .main, message: "did occour warning: \(warningCode.rawValue)"))
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraRtcErrorCode) {
        logList.append(LogMessage(type: .error, channel: .main, message: "did occour error: \(errorCode.rawValue)"))
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraRtcUserOfflineReason) {
        logList.append(LogMessage(type: .info, channel: .main, message: "did offline of uid: \(uid)"))
        
        var indexToDelete: Int?
        for (index, session) in videoSessions.enumerated() {
            if session.uid == Int64(uid) {
                indexToDelete = index
            }
        }
        
        if let indexToDelete = indexToDelete {
            let deletedSession = videoSessions.remove(at: indexToDelete)
            deletedSession.hostingView.removeFromSuperview()
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraRtcStats) {
        logList.append(LogMessage(type: .info, channel: .main, message: "did leave channel"))
    }
}

// MARK: -Agora Sub Engine Delegate
extension LiveRoomViewController: SubRtcEngineDelegate {
    func subRtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        if channel == self.subRoomName {
            self.isInSubChannel = true
        }
        logList.append(LogMessage(type: .info, channel: .sub, message: "did join channel \(channel) success with uid: \(uid)"))
    }
    
    func subRtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        logList.append(LogMessage(type: .info, channel: .sub, message: "did join channel of uid: \(uid)"))
        let remoteSession = videoSession(ofUid: uid, forChannel: .sub)
        rtcEngine.setupRemoteVideo(remoteSession.canvas)
    }
    
    func subRtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraRtcUserOfflineReason) {
        logList.append(LogMessage(type: .info, channel: .sub, message: "did offline of uid: \(uid)"))
        var indexToDelete: Int?
        for (index, session) in videoSubSessions.enumerated() {
            if session.uid == Int64(uid) {
                indexToDelete = index
            }
        }
        
        if let indexToDelete = indexToDelete {
            let deletedSession = videoSubSessions.remove(at: indexToDelete)
            deletedSession.hostingView.removeFromSuperview()
        }
    }
    
    func subRtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraRtcStats) {
        logList.append(LogMessage(type: .info, channel: .sub, message: "did leave subchannel"))
        if isInSubChannel {
            isInSubChannel = false
        }
    }
    
    func subRtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraRtcErrorCode) {
        logList.append(LogMessage(type: .error, channel: .sub, message: "did occour error: \(errorCode.rawValue)"))
    }
}

extension LiveRoomViewController: PopViewDelegate {
    func popViewButtonDidPressed(_ popView: PopView) {
        guard let subRoomName = popView.inputTextField.text else {
            return
        }
        if subRoomName.isEmpty {
            return
        }
        self.subRoomName = subRoomName
        rtcEngine.joinSubChannel(byKey: nil, channelName: subRoomName, info: nil, uid: 0, delegate: self.subController)
        popView.removeFromSuperview()
    }
}

extension LiveRoomViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "logCell", for: indexPath) as! LogCell
        cell.set(log: logList[indexPath.row].message, withType: logList[indexPath.row].type, forChannel: logList[indexPath.row].channel)
        return cell
    }
}
