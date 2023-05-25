//
//  PinMessageBarView.swift
//  Sphinx
//
//  Created by Tomas Timinskas on 24/05/2023.
//  Copyright © 2023 Tomas Timinskas. All rights reserved.
//

import Cocoa

protocol PinnedMessageViewDelegate: AnyObject {
    func didTapUnpinButtonFor(messageId: Int)
    func didTapPinBarViewFor(messageId: Int)
}

class PinMessageBarView: NSView, LoadableNib {
    
    weak var delegate: PinnedMessageViewDelegate?
    
    @IBOutlet var contentView: NSView!
    @IBOutlet weak var messageLabel: NSTextField!
    
    var messageId: Int? = nil
    var completion: (() -> ())? = nil
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadViewFromNib()
        
        self.isHidden = true
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        loadViewFromNib()
        
        self.isHidden = true
    }
    
    func configureWith(
        chatId: Int,
        and delegate: PinnedMessageViewDelegate,
        completion: (() ->())? = nil
    ) {
        self.completion = completion
        
        if let chat = Chat.getChatWith(id: chatId) {
            if let pinnedMessageUUID = chat.pinnedMessageUUID, !pinnedMessageUUID.isEmpty {
                if let message = TransactionMessage.getMessageWith(
                    uuid: pinnedMessageUUID
                ) {
                    setMessageAndShowView(message: message, delegate: delegate)
                } else {
                    fetchMessage(pinnedMessageUUID: pinnedMessageUUID, delegate: delegate)
                }
            } else {
                hideView()
            }
        }
    }
    
    func fetchMessage(
        pinnedMessageUUID: String,
        delegate: PinnedMessageViewDelegate
    ) {
        API.sharedInstance.getMessageBy(
            messageUUID: pinnedMessageUUID,
            callback: { messageJSON in
                if let message = TransactionMessage.insertMessage(m: messageJSON).0 {
                    self.setMessageAndShowView(message: message, delegate: delegate)
                } else {
                    self.hideView()
                }
            } , errorCallback: {
                self.hideView()
            }
        )
    }
    
    func setMessageAndShowView(
        message: TransactionMessage,
        delegate: PinnedMessageViewDelegate
    ) {
        self.delegate = delegate
        self.messageId = message.id
        
        messageLabel.stringValue = message.getMessageContent()
        
        self.isHidden = false
        
        completion?()
    }
    
    func hideView() {
        self.messageId = nil
        self.isHidden = true
    }
    
    @IBAction func pinBarButtonClicked(_ sender: Any) {
        if let messageId = messageId {
            delegate?.didTapPinBarViewFor(messageId: messageId)
        }
    }
}