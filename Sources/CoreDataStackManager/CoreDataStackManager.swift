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
    
    public static var applicationDocumentsDirectory = {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    }()
    public let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    private let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    
    public let modelName: String
    public let storeType: String
    public let bundle: Bundle
    public let storeLocation: StoreLocation
    public let modelURL: URL
    public private(set) var storeURL: URL?
    public var coordinator: NSPersistentStoreCoordinator?
    
    public init(modelName: String = "Model", storeType: String = NSSQLiteStoreType, bundle: Bundle = Bundle.main, storeLocation: StoreLocation = .standard) {
        self.modelName = modelName
        self.storeType = storeType
        self.bundle = bundle
        self.storeLocation = storeLocation
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else { fatalError("Invalid model URL") }
        self.modelURL = modelURL
        super.init()
        
        initializeCoreData()
    }
    
    private func initializeCoreData() {
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else { fatalError("Invalid model") }
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        switch storeLocation {
        case .standard:
            storeURL = type(of: self).standardStoreURL(forModelNamed: modelName)
        case .appGroup(let identifier):
            storeURL = type(of: self).appGroupURL(forModelNamed: modelName, securityGroupIdentifier: identifier)
            guard storeURL != nil else {
                fatalError("Could not find the container for security group: \(identifier). Did you add the App Groups capability to your app's provisioning profile?")
            }
        }
        
        do {
            let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                           NSInferMappingModelAutomaticallyOption: true]
            try coordinator?.addPersistentStore(ofType: storeType, configurationName: nil, at: storeURL, options: options)
        } catch {
            fatalError("Could not add the persistent store: \(error).")
        }
        
        privateContext.persistentStoreCoordinator = coordinator
        managedObjectContext.parent = privateContext
    }

    public static func standardStoreURL(forModelNamed name: String) -> URL? {
        return CoreDataStackManager.applicationDocumentsDirectory.appendingPathComponent("\(name).sqlite")
    }
    
    public static func appGroupURL(forModelNamed name: String, securityGroupIdentifier identifier: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            print("Could not find the container for security group: \(identifier). Did you add the App Groups capability to your app's provisioning profile?")
            return nil
        }
        return containerURL.appendingPathComponent("\(name).sqlite")
    }
    
    open func createTemporaryContext() -> NSManagedObjectContext {
        let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        temporaryContext.parent = managedObjectContext
        return temporaryContext
    }
    
    
    open func save(andCheckForChanges check: Bool = true, fullySynchronous: Bool = false) {
        
        if check && !managedObjectContext.hasChanges {
            return
        }
        managedObjectContext.performAndWait {
            do {
                try self.managedObjectContext.save()
                let saveBlock = { [weak self] in
                    do {
                        try self?.privateContext.save()
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                }
                if fullySynchronous {
                    privateContext.performAndWait(saveBlock)
                }
                else {
                    privateContext.perform(saveBlock)
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
