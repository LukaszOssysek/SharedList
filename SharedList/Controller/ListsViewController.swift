//
//  ListsViewController.swift
//  SharedList
//
//  Created by Lukasz on 03/03/2019.
//  Copyright © 2019 Lukasz. All rights reserved.
//

import UIKit
import SVProgressHUD

class ListsViewController: UIViewController {

    @IBOutlet var listTitleTextField: UITextField!
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var addListButton: UIButton!
    @IBOutlet var proposalsButton: UIButton!
    
    var selectedListIndex : Int?
    
    fileprivate var listManager : ListManager?
    var frbManager : FirebaseManager? {
        didSet {
            listManager = frbManager?.listManager
            listManager?.delegate = self
            
            frbManager?.proposalManager.LoadData()
            frbManager?.proposalManager.ActivateObservers()
        }
    }

    fileprivate let loadingGuard = TimeoutGuard()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "listCell")
        
        LoadData()
        PresentDataLoading()
    }

    @IBAction func AddListPressed(_ sender: Any) {
        
        if (listTitleTextField.text?.count == 0) {
            print("cannot add list with empty name")
        }
        else {
            let listTitle = listTitleTextField.text!
            listManager!.AddNewList(title: listTitle)
        }
    }
    
    @IBAction func ProposalsPressed(_ sender: UIButton) {
        performSegue(withIdentifier: "goToProposals", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if (segue.identifier == "goToSingleList")
        {
            guard let listIndex = selectedListIndex else { fatalError("No list was selected") }
            
            selectedListIndex = nil
            
            let singleListVC = segue.destination as! SingleListViewController
            singleListVC.list = listManager!.lists[listIndex]
            singleListVC.frbManager = frbManager
        }
        
        if (segue.identifier == "goToProposals")
        {
            let proposalVC = segue.destination as! ProposalsViewController
            proposalVC.frbManager = frbManager
        }
    }
    
    fileprivate func LoadData() {
        
        listManager?.LoadData()
        loadingGuard.delegate = self
        loadingGuard.Activate()
    }
    
    fileprivate func PresentDataLoading() {
        DisableUI()
        SVProgressHUD.show(withStatus: "Loading data...")
    }
    
    fileprivate func DismisDataLoading(success: Bool) {
        if (SVProgressHUD.isVisible()) {
            
            if (success) {
                SVProgressHUD.showSuccess(withStatus: "Awsome!")
            }
            else {
                SVProgressHUD.showError(withStatus: "Failed.")
            }
            
            SVProgressHUD.dismiss(withDelay: 0.6) {
                self.EnableUI()
            }
        }
    }
    
    fileprivate func DisableUI() {
        listTitleTextField.isEnabled = false
        tableView.allowsSelection = false
        tableView.isScrollEnabled = false
        addListButton.isEnabled = false
        proposalsButton.isEnabled = false
    }
    
    fileprivate func EnableUI() {
        listTitleTextField.isEnabled = true
        tableView.allowsSelection = true
        tableView.isScrollEnabled = true
        addListButton.isEnabled = true
        proposalsButton.isEnabled = true
    }
}


extension ListsViewController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if listManager!.lists.count != 0 {
            return listManager!.lists.count
        }
        else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath)
        
        if listManager!.lists.count != 0 {
            cell.textLabel?.text = listManager!.lists[indexPath.row].title
        }
        else {
            cell.textLabel?.text = "Add new list"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
//        do {
//            try Auth.auth().signOut()
//
//            navigationController?.popToRootViewController(animated: true)
//        }
//        catch {
//            print("singing out failed with errror: \(error)")
//        }
//
//        return
        
//        firebaseManager.RemoveList(index: indexPath.row)
        
        selectedListIndex = indexPath.row
        performSegue(withIdentifier: "goToSingleList", sender: self)
    }
}

extension ListsViewController : ListManagerDelegate {
    
    func NewListAdded() {
        
        tableView.reloadData()
        
        if (loadingGuard.isActive) {
            loadingGuard.Refresh()
        }
    }
    
    func ListRemoved() {
        
        tableView.reloadData()
    }
    
    func DataLoaded() {
        
        tableView.reloadData()
        listManager?.ActivateObservers()
        
        loadingGuard.Deactivate()
        DismisDataLoading(success: true)
    }
}

extension ListsViewController : TimeoutGuardDelegate {
    
    func TimeoutGuardFired() {
        DismisDataLoading(success: false)
    }
}
