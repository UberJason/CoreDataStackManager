//
//  CoreDataStack.swift
//  CoreDataStackManager
//
//  Created by Jason Ji on 5/9/16.
//  Copyright © 2016 Jason Ji. All rights reserved.
//

import UIKit
import CoreData

public enum StoreLocation {
    case standard, appGroup(String)
}

open class CoreDataStackManager: NSObject {
    public static let sharedInstance = CoreDataStackManager()
    
    private var applicationDocumentsDirectory = {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    }()
    public let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    private let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    private let modelName: String
    private let storeType: String
    private let bundle: Bundle
    private let storeLocation: StoreLocation
    
    public init(modelName: String = "Model", storeType: String = NSSQLiteStoreType, bundle: Bundle = Bundle.main, storeLocation: StoreLocation = .standard) {
        self.modelName = modelName
        self.storeType = storeType
        self.bundle = bundle
        self.storeLocation = storeLocation
        super.init()
        initializeCoreData()
    }
    
    private func initializeCoreData() {
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else { fatalError("Invalid model URL") }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else { fatalError("Invalid model") }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        let storeURL: URL
        
        switch storeLocation {
        case .standard:
            storeURL = applicationDocumentsDirectory.appendingPathComponent("\(modelName).sqlite")
        case .appGroup(let identifier):
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
                fatalError("Could not find the container for security group: \(identifier). Did you add the App Groups capability to your app's provisioning profile?")
            }
            storeURL = containerURL.appendingPathComponent("\(modelName).sqlite")
        }
        
        do {
            let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                           NSInferMappingModelAutomaticallyOption: true]
            try coordinator.addPersistentStore(ofType: storeType, configurationName: nil, at: storeURL, options: options)
        }catch {
            fatalError("Could not add the persistent store: \(error).")
        }
        
        privateContext.persistentStoreCoordinator = coordinator
        managedObjectContext.parent = privateContext
    }
    
    open func createTemporaryContext() -> NSManagedObjectContext {
        let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        temporaryContext.parent = managedObjectContext
        return temporaryContext
    }
    
    
    open func save(andCheckForChanges check: Bool = true) {
        
        if check && !managedObjectContext.hasChanges {
            return
        }
        managedObjectContext.performAndWait {
            do {
                try self.managedObjectContext.save()
                self.privateContext.perform {
                    do {
                        try self.privateContext.save()
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
    
    open func saveWithTemporaryContext(_ context: NSManagedObjectContext) {
        // Assumes the passed context has our managedObjectContext as its parent.
        if !context.hasChanges {
            return
        }
        context.performAndWait {
            do {
                try context.save()
                self.save(andCheckForChanges: false)
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
}
