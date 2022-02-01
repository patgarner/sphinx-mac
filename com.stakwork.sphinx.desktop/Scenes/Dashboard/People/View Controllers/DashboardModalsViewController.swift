//
//  DashboardModalsViewController.swift
//  Sphinx
//
//  Created by Tomas Timinskas on 05/01/2022.
//  Copyright © 2022 Tomas Timinskas. All rights reserved.
//

import Cocoa

protocol PeopleModalsViewControllerDelegate: AnyObject {
    func shouldHideContainer()
}

protocol RestoreModalViewControllerDelegate: AnyObject {
    func didFinishRestoreManually()
    func didFinishRestoring()
}

class DashboardModalsViewController: NSViewController {

    @IBOutlet weak var authExternalView: AuthExternalView!
    @IBOutlet weak var personModalView: PersonModalView!
    @IBOutlet weak var savePeopleProfileView: SavePeopleProfileView!
    @IBOutlet weak var restoreProgressView: RestoreProgressView!
    
    var query: String? = nil
    
    weak var peopleModalsDelegate: PeopleModalsViewControllerDelegate? = nil
    weak var restoreModalsDelegate: RestoreModalViewControllerDelegate? = nil
    
    static func instantiate() -> DashboardModalsViewController {
        let viewController = StoryboardScene.Dashboard.dashboardModalsViewController.instantiate()
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    private func hideAllModals() {
        authExternalView.isHidden = true
        personModalView.isHidden = true
        savePeopleProfileView.isHidden = true
        
        restoreProgressView.isHidden = true
    }
    
    func showProgressViewWith(
        progress: Int,
        delegate: RestoreModalViewControllerDelegate?
    ) {
        restoreModalsDelegate = delegate
        
        if (progress == 100) {
            delegate?.didFinishRestoring()
            return
        }
        
        restoreProgressView.setProgress(
            progress: progress,
            delegate: delegate
        )
        
        if (!restoreProgressView.isHidden) {
            return
        }
        
        showProgressModalAnimated()
    }
    
    func showProgressModalAnimated() {
        hideAllModals()
        
        self.view.alphaValue = 0.0
        
        restoreProgressView.isHidden = false
        
        AnimationHelper.animateViewWith(duration: 0.3, animationsBlock: {
            self.view.alphaValue = 1.0
        })
    }
    
    func showWithQuery(
        _ query: String,
        and delegate: PeopleModalsViewControllerDelegate
    ) {
        self.peopleModalsDelegate = delegate
        self.query = query
        
        showPeopleModalAnimatedWith(query)
    }
    
    func showPeopleModalAnimatedWith(
        _ query: String
    ) {
        hideAllModals()
        
        self.view.alphaValue = 0.0
        
        if let modal = getModal() {
            modal.isHidden = false
            modal.modalWillShowWith(query: query, delegate: self)
            
            AnimationHelper.animateViewWith(duration: 0.3, animationsBlock: {
                self.view.alphaValue = 1.0
            }, completion: {
                modal.modalDidShow()
            })
        } else {
            shouldDismissModals()
        }
    }
    
    func getModal() -> ModalViewInterface? {
        if let query = query, let action = query.getLinkAction() {
            switch(action) {
            case "auth":
                return authExternalView
            case "person":
                return personModalView
            case "save":
                return savePeopleProfileView
            default:
                break
            }
        }
        return nil
    }
}

extension DashboardModalsViewController : ModalViewDelegate {
    func shouldDismissModals() {
        AnimationHelper.animateViewWith(duration: 0.3, animationsBlock: {
            self.view.alphaValue = 0.0
        }, completion: {
            self.authExternalView.isHidden = true
            self.personModalView.isHidden = true
            self.savePeopleProfileView.isHidden = true
            self.restoreProgressView.isHidden = true
            
            self.peopleModalsDelegate?.shouldHideContainer()
        })
    }
}