//
//  CoreDataStack.swift
//  CoreDataStackManager
//
//  Created by Jason Ji on 5/9/16.
//  Copyright © 2016 Jason Ji. All rights reserved.
//

import UIKit
import CoreData

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
    
    public init(modelName: String = "Model", storeType: String = NSSQLiteStoreType, bundle: Bundle = Bundle.main) {
        self.modelName = modelName
        self.storeType = storeType
        self.bundle = bundle
        super.init()
        initializeCoreData()
    }
    
    private func initializeCoreData() {
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else { fatalError("Invalid model URL") }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else { fatalError("Invalid model") }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        let storeURL: URL = applicationDocumentsDirectory.appendingPathComponent("\(modelName).sqlite")
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
    
    public func createTemporaryContext() -> NSManagedObjectContext {
        let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        temporaryContext.parent = managedObjectContext
        return temporaryContext
    }
    
    
    public func save() {
        if !privateContext.hasChanges && !self.managedObjectContext.hasChanges {
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
    
    public func saveWithTemporaryContext(_ context: NSManagedObjectContext) {
        // Assumes the passed context has our managedObjectContext as its parent.
        if !context.hasChanges {
            return
        }
        context.performAndWait {
            do {
                try context.save()
                self.save()
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
}
