//
//  SingleListManager.swift
//  SharedList
//
//  Created by Lukasz on 22/05/2019.
//  Copyright © 2019 Lukasz. All rights reserved.
//

import Firebase

protocol ItemWithObserverDelegate : class
{
    func ItemUpdated()
}

class ItemWithObserver
{
    let item : Item
    
    weak var delegate : ItemWithObserverDelegate?
    
    private let itemsId : String
    private var observer : ChangedObserver?
    private var active : Bool = false
    
    init (item: Item, itemsId: String)
    {
        self.item = item
        self.itemsId = itemsId
    }
    
    func Activate()
    {
        if (active == false)
        {
            let itemDbRef = frb_utils.ItemsDbRef(itemsId).child(Items.Keys.items.rawValue).child(item.id)
            observer = ChangedObserver(dbRef: itemDbRef, dataChangedCallback: Updated(snapshot:))
            observer?.Activate()
            active = true
        }
    }
    
    func Updated(snapshot : DataSnapshot)
    {
        let itemData = [snapshot.key : snapshot.value]
        self.item.Update(data: itemData)
        
        if let del = delegate
        {
            del.ItemUpdated()
        }
    }
}


protocol SingleListManagerDelegate : class {
    
    func DataLoaded()
    func NewItemAdded()
    func ItemRemoved()
}


class SingleListManager {
    
    weak var delegate : SingleListManagerDelegate? = nil
    
    var itemsCount : Int {
        get { return data.count }
    }
    
    let list : List
    
    fileprivate let authManager : AuthManager
    fileprivate let obsererversManager : ObserversHandler
    fileprivate var observerActive : Bool = false
    fileprivate var data = [ItemWithObserver]()
    
    
    init(list: List, authManager: AuthManager)
    {
        self.list = list
        self.authManager = authManager
        
        let itemsDbRef = frb_utils.ItemsDbRef(list.items_id).child(Items.Keys.items.rawValue)
        self.obsererversManager = ObserversHandler(itemsDbRef)
    }
    
    func LoadData()
    {
        let itemsDbRef = frb_utils.ItemsDbRef(list.items_id).child(Items.Keys.items.rawValue)
        itemsDbRef.observeSingleEvent(of: .value)
        { (itemsTableSnapshot) in
            
            if (itemsTableSnapshot.exists() == false)
            {
                if let del = self.delegate
                {
                    del.DataLoaded()
                    self.ActivateObservers()
                }
                return
            }
            
            let data = (itemsTableSnapshot.value! as! [String : Any])
            let itemsIds = data.keys
            var itemsCounter = itemsIds.count
            
            for itemId in itemsIds
            {
                itemsCounter = itemsCounter - 1
                
                let itemData = data[itemId] as! [String : Any]
                let lastItem = itemsCounter == 0
                self.LoadAuthorAndAddItem(id: itemId, data: itemData, lastItem: lastItem)
            }
        }
    }
    
    func GetItem(_ idx : Int) -> Item?
    {
        if (idx < itemsCount)
        {
            return data[idx].item
        }
        return nil
    }
    
    func AddNewItem(title : String)
    {
        let dbRef = Database.database().reference()
        let newItemDbRef = frb_utils.ItemsDbRef(list.items_id).child(Items.Keys.items.rawValue).childByAutoId()
        let authorId = authManager.currentUser!.id
        
        let newItem = Item(itemsId: list.items_id,
                           id: newItemDbRef.key!,
                           title: title,
                           done: false,
                           author: authorId)
        
        let updateData = newItem.Serialize()
        
        dbRef.updateChildValues(updateData)
        { (error, snapshot) in
            
            if (error != nil) {
                print("New item add failed with error: \(error!)")
            }
        }
    }
    
    func ReverseDone(index : Int)
    {
        let item = data[index].item
        let newDone = !item.done
        let doneByValue = newDone ? authManager.currentUser!.id
                                  : "NONE"
        
        let updateData = [item.Path(Item.Keys.done) : newDone,
                          item.Path(Item.Keys.done_by) : doneByValue] as [String : Any]
        
        let dbRef = Database.database().reference()
        dbRef.updateChildValues(updateData)
        { (error, snapshot) in
            
            if (error != nil) {
                print("Cant change done property failed with error: \(error!)")
            }
        }
    }
    
    fileprivate func ActivateObservers()
    {
        if (observerActive == false)
        {
            obsererversManager.AddObserver(eventType: .childAdded, ItemsChildAdded)
            obsererversManager.AddObserver(eventType: .childRemoved, ItemsChildRemoved)
            
            observerActive = true
        }
    }
    
    fileprivate func LoadAuthorAndAddItem(id: String, data: [String : Any], lastItem: Bool)
    {
        let authorId = data[Item.Keys.author.rawValue] as! String
        let authorInListDbRef = frb_utils.UserInListDbRef(listId: list.id, userId: authorId)
        
        authorInListDbRef.observeSingleEvent(of: .value)
        { (authorSnapshot) in
            var newData = data
            newData[Item.Keys.author.rawValue] = authorSnapshot.value as! String
            
            let newItemWithObserver = self.PrepareItemWithObserver(id: id, data: newData)
            
            self.data.append(newItemWithObserver)
            
            if let del = self.delegate
            {
                if (lastItem == true)
                {
                    del.DataLoaded()
                    self.ActivateObservers()
                }
                else
                {
                    del.NewItemAdded()
                }
            }
        }
    }
    
    fileprivate func PrepareItemWithObserver(id: String, data: [String : Any]) -> ItemWithObserver
    {
        let newItem = Item.Deserialize(itemsId: self.list.items_id,
                                       id: id,
                                       data: data)
        
        let observer = ItemWithObserver(item: newItem,
                                        itemsId: self.list.items_id)
        observer.delegate = self
        observer.Activate()
        
        return observer
    }

    fileprivate func ItemsChildAdded(_ itemSnapshot: DataSnapshot)
    {
        let itemId = itemSnapshot.key
        if (FindItemIndex(itemId) != nil)
        {
            return
        }
        
        let itemDict = itemSnapshot.value! as! [String : Any]
        LoadAuthorAndAddItem(id: itemId, data: itemDict, lastItem: false)
    }
    
    fileprivate func ItemsChildRemoved(_ itemSnapshot: DataSnapshot)
    {
        let itemId = itemSnapshot.key
        if let itemIndex = FindItemIndex(itemId)
        {
            data.remove(at: itemIndex)
            if let del = delegate
            {
                del.ItemRemoved()
            }
        }
    }
    
    fileprivate func FindItemIndex(_ id: String) -> Int?
    {
        return data.firstIndex { (itemWithObserver) -> Bool in
            return (itemWithObserver.item.id == id)
        }
    }
}

extension SingleListManager : ItemWithObserverDelegate
{
    func ItemUpdated()
    {
        if let del = delegate
        {
            del.DataLoaded()
        }
    }
}
