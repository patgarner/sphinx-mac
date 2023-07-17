//
//  NewChatViewController+TribeExtension.swift
//  Sphinx
//
//  Created by Tomas Timinskas on 14/07/2023.
//  Copyright © 2023 Tomas Timinskas. All rights reserved.
//

import Foundation

extension NewChatViewController {
    
    func fetchTribeData() {
//        configureMentions()
        configurePinnedMessageView()
        
        if chat?.isPublicGroup() == false {
            return
        }

        chat?.updateTribeInfo() {
            self.chatTopView.updateViewOnTribeFetch()
            self.addPodcastVC(deepLinkData: self.deepLinkData) 
            self.configurePinnedMessageView()
        }
    }
    
    ///Pinned Message
    func configurePinnedMessageView() {
        if let chatId = chat?.id {
            chatTopView.configurePinnedMessageViewWith(
                chatId: chatId,
                andDelegate: self
            ) {
//                self.shouldAdjustTableViewTopInset()
            }
        }
    }
}

extension NewChatViewController : PinnedMessageViewDelegate {
    func didTapUnpinButtonFor(messageId: Int) {
        
    }
    
    func didTapPinBarViewFor(messageId: Int) {
        
    }
}