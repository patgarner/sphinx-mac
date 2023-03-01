//
//  ChatListViewModel.swift
//  com.stakwork.sphinx.desktop
//
//  Created by Tomas Timinskas on 14/05/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON

final class ChatListViewModel: NSObject {
    
    private var contactsService: ContactsService!
    
    public static let kMessagesPerPage: Int = 200
    
    init(contactsService: ContactsService) {
        self.contactsService = contactsService
    }
    
    public static func isRestoreRunning() -> Bool {
        let restoreRunning = API.sharedInstance.lastSeenMessagesDate == nil && UserDefaults.Keys.messagesFetchPage.get(defaultValue: -1) > 0
        
        if !restoreRunning {
            UserDefaults.Keys.messagesFetchPage.removeValue()
        }
        
        return restoreRunning
    }
    
    func loadFriends(completion: @escaping () -> ()) {
        if let contactsService = contactsService {
            API.sharedInstance.getLatestContacts(date: Date(), callback: {(contacts, chats, subscriptions, invites) -> () in
                contactsService.insertObjects(contacts: contacts, chats: chats, subscriptions: subscriptions, invites: invites)
                self.forceKeychainSync()
                completion()
            })
        } else {
            completion()
        }
    }
    
    func getChatListObjectsCount() -> Int {
        if let contactsService = contactsService {
            return contactsService.chatListObjects.count
        }
        return 0
    }
    
    func updateContactsAndChats() {
        guard let contactsService = contactsService else {
            return
        }
        contactsService.updateContacts()
        contactsService.updateChats()
    }
    
    func forceKeychainSync() {
        UserData.sharedInstance.forcePINSyncOnKeychain()
        UserData.sharedInstance.saveNewNodeOnKeychain()
        EncryptionManager.sharedInstance.saveKeysOnKeychain()
    }
    
    func isRestoring() -> Bool {
        return API.sharedInstance.lastSeenMessagesDate == nil
    }
    
    var syncMessagesTask: DispatchWorkItem? = nil
    var syncMessagesDate = Date()
    var newMessagesChatIds = [Int]()
    
    func syncMessages(
        chatId: Int? = nil,
        progressCallback: @escaping (Double, Bool) -> (),
        completion: @escaping (Int, Int) -> ()
    ) {
        
        UserDefaults.Keys.messagesFetchPage.set(
            UserDefaults.Keys.messagesFetchPage.get(defaultValue: 1)
        )
        
        self.newMessagesChatIds = []
        self.syncMessagesDate = Date()
    
        self.getMessagesPaginated(
            prevPageNewMessages: 0,
            chatId: chatId,
            date: self.syncMessagesDate,
            progressCallback: progressCallback,
            completion: { chatNewMessagesCount, newMessagesCount in
                
                UserDefaults.Keys.messagesFetchPage.removeValue()
                
                Chat.updateLastMessageForChats(
                    self.newMessagesChatIds
                )
                
                completion(chatNewMessagesCount, newMessagesCount)
            }
        )
    }
    
    func calculateBadges() {
        contactsService.calculateBadges()
    }
    
    func finishRestoring() {
        SignupHelper.completeSignup()
        UserDefaults.Keys.messagesFetchPage.removeValue()
        API.sharedInstance.lastSeenMessagesDate = syncMessagesDate
    }
    
    func getMessagesPaginated(
        prevPageNewMessages: Int,
        chatId: Int? = nil,
        date: Date,
        progressCallback: @escaping (Double, Bool) -> (),
        completion: @escaping (Int, Int) -> ()
    ) {
        
        let page = UserDefaults.Keys.messagesFetchPage.get(defaultValue: 1)

        API.sharedInstance.getMessagesPaginated(
            page: page,
            date: date,
            callback: {(newMessagesTotal, newMessages) -> () in
                
                let restoring = self.isRestoring()
                
                if newMessages.count > 0 {
                    
                    progressCallback(
                        self.getRestoreProgress(
                            currentPage: page,
                            newMessagesTotal: newMessagesTotal,
                            itemsPerPage: ChatListViewModel.kMessagesPerPage
                        ), restoring
                    )
                    
                    self.addMessages(
                        messages: newMessages,
                        chatId: chatId,
                        completion: { (newChatMessagesCount, newMessagesCount) in
                            
                            if newMessages.count < ChatListViewModel.kMessagesPerPage {
                                
                                CoreDataManager.sharedManager.saveContext()
                                
                                if restoring {
                                    SphinxSocketManager.sharedInstance.connectWebsocket()
                                    SignupHelper.completeSignup()
                                }
                                
                                completion(newChatMessagesCount, newMessagesCount)
                                
                            } else {
                                
                                CoreDataManager.sharedManager.saveContext()
                                UserDefaults.Keys.messagesFetchPage.set(page + 1)
                                
                                self.getMessagesPaginated(
                                    prevPageNewMessages: newMessagesCount + prevPageNewMessages,
                                    chatId: chatId,
                                    date: date,
                                    progressCallback: progressCallback,
                                    completion: completion
                                )
                            }
                        })
                } else {
                    completion(0, 0)
                }
            }, errorCallback: {
                completion(0, 0)
            })
    }
    
    func getRestoreProgress(
        currentPage: Int,
        newMessagesTotal: Int,
        itemsPerPage: Int
    ) -> Double {
        
        if (newMessagesTotal <= 0) {
            return -1
        }
        
        let pages = (newMessagesTotal <= itemsPerPage) ? 1 : (Double(newMessagesTotal) / Double(itemsPerPage))
        let progress = Double(currentPage) * 100 / pages

        return progress
    }
    
    func addMessages(messages: [JSON], chatId: Int? = nil, completion: @escaping (Int, Int) -> ()) {
        var newChatMessagesCount = 0
        
        for messageDictionary in messages {
            let (message, isNew) = TransactionMessage.insertMessage(m: messageDictionary)
            if let message = message {
                message.setPaymentInvoiceAsPaid()
                
                if isAddedRow(message: message, isNew: isNew, viewChatId: chatId) {
                    newChatMessagesCount = newChatMessagesCount + 1
                }
                
                if let chat = message.chat, !newMessagesChatIds.contains(chat.id) {
                    newMessagesChatIds.append(chat.id)
                }
            }

        }
        completion(newChatMessagesCount, messages.count)
    }
    
    func isAddedRow(message: TransactionMessage, isNew: Bool, viewChatId: Int?) -> Bool {
        if TransactionMessage.typesToExcludeFromChat.contains(message.type) {
            return false
        }
        
        if let messageChatId = message.chat?.id, let viewChatId = viewChatId {
            if (isNew || !message.seen) {
                return messageChatId == viewChatId
            }
        }
        return false
    }
    
    func payInvite(invite: UserInvite, completion: @escaping (UserContact?) -> ()) {
        guard let inviteString = invite.inviteString else {
            completion(nil)
            return
        }
        
        let bubbleHelper = NewMessageBubbleHelper()
        bubbleHelper.showLoadingWheel()
        
        API.sharedInstance.payInvite(inviteString: inviteString, callback: { inviteJson in
            bubbleHelper.hideLoadingWheel()
            
            if let invite = UserInvite.insertInvite(invite: inviteJson) {
                if let contact = invite.contact {
                    invite.setPaymentProcessed()
                    completion(contact)
                    return
                }
            }
            completion(nil)
        }, errorCallback: {
            bubbleHelper.hideLoadingWheel()
            completion(nil)
        })
    }
}
