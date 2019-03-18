//
//  ListManager.swift
//  SharedList
//
//  Created by Lukasz on 18/03/2019.
//  Copyright © 2019 Lukasz. All rights reserved.
//

import Foundation
import Firebase

protocol ListManagerDelegate : class {
    
    func NewListAdded()
    func ListRemoved()
}

class ListManager {
    
    weak var delegate : ListManagerDelegate? = nil
    
    var lists = [List]()
    
    var listObservers = [DataEventType: DatabaseHandle?]()
    
    func ActivateListObservers()
    {
        if (listObservers[.childAdded] != nil) {
            
            let userId = Auth.auth().currentUser!.uid
            let userListsDbRef = Database.database().reference().child("users/\(userId)/lists")
            
            listObservers[.childAdded] = userListsDbRef.observe(.childAdded)
            { (listKeySnapshot) in
                
                let listDbRef = Database.database().reference().child("lists/\(listKeySnapshot.key)")
                listDbRef.observeSingleEvent(of: .value, with: { (listSnapshot) in
                    
                    let newList = List.Deserialize(data: listSnapshot.value as! [String: String])
                    self.lists.append(newList)
                    
                    if let del = self.delegate {
                        del.NewListAdded()
                    }
                })
            }
        }
        
        if (listObservers[.childRemoved] != nil) {
            
            let userId = Auth.auth().currentUser!.uid
            let listsKeyDbRef = Database.database().reference().child("users/\(userId)/lists")
            listObservers[.childRemoved] = listsKeyDbRef.observe(.childRemoved)
            { (listKeySnapshot) in
                
                for (index, list) in self.lists.enumerated() {
                    
                    if (list.id! == listKeySnapshot.key) {
                        
                        self.lists.remove(at: index)
                        
                        if let del = self.delegate {
                            del.ListRemoved()
                        }
                        return
                    }
                }
            }
        }
    }
    
    func AddNewList(title: String) {
        
        let dbRef = Database.database().reference()
        
        let newListRef = dbRef.child("lists").childByAutoId()
        let newListKey = newListRef.key!
        
        let newItemsRef = dbRef.child("items").childByAutoId()
        let newItemsKey = newItemsRef.key!
        
        let userId = Auth.auth().currentUser!.uid
        
        let serializedList = List.Serialize(title: title, owner_id: userId, items_id: newItemsKey)
        
        let updateData = ["users/\(userId)/lists/\(newListKey)" : true,
                          "lists/\(newListKey)" : serializedList,
                          "items/\(newItemsKey)/list_id" : newListKey] as [String : Any]
        
        dbRef.updateChildValues(updateData)
        { (error, snapshot) in
            
            if (error != nil) {
                print("New list add failed with error: \(error!)")
            }
        }
    }
    
    func RemoveList(index: Int) {
        
        if (lists.count > index)
        {
            let dbRef = Database.database().reference()
            
            let listId = lists[index].id!
            let itemsId = lists[index].items_id
            let userId = Auth.auth().currentUser!.uid
            
            let updateData = ["users/\(userId)/lists/\(listId)" : NSNull(),
                              "lists/\(listId)" : NSNull(),
                              "items/\(itemsId)" : NSNull()] as [String : Any]
            
            dbRef.updateChildValues(updateData)
        }
    }
}