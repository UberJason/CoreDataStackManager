//
//  CoreDataStore.swift
//  FreecellKit
//
//  Created by Jason Ji on 2/15/20.
//  Copyright © 2020 Jason Ji. All rights reserved.
//

import CoreData

@propertyWrapper
public struct Delayed<Value> {
    private var _value: Value? = nil
    
    public init() {}
    
    public var wrappedValue: Value {
        get {
            guard let value = _value else {
                fatalError("Property accessed before being initialized.")
            }
            return value
        }
        set {
            _value = newValue
        }
    }
}

public class CoreDataStore {
    public enum StoreLocation {
        case standard, appGroup(String)
    }
    
    public let modelName: String
    public let bundle: Bundle
    public let storeLocation: StoreLocation
    public let modelURL: URL
    @Delayed public private(set) var storeURL: URL
    
    @Delayed var persistentContainer: NSPersistentContainer
    
    public init(modelName: String = "Model", storeType: String = NSSQLiteStoreType, bundle: Bundle = Bundle.main, storeLocation: CoreDataStore.StoreLocation = .standard) {
        self.modelName = modelName
        self.storeLocation = storeLocation
        self.bundle = bundle
        
        guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else { fatalError("Invalid model URL") }
        self.modelURL = modelURL
    
        persistentContainer = initializePersistentContainer()
    }
    
    private func initializePersistentContainer() -> NSPersistentContainer {
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else { fatalError("Invalid model") }
        
        switch storeLocation {
        case .standard:
            storeURL = type(of: self).standardStoreURL(forModelNamed: modelName)
        case .appGroup(let identifier):
            storeURL = type(of: self).appGroupURL(forModelNamed: modelName, securityGroupIdentifier: identifier)
        }
        
        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                assertionFailure("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        return container
    }
    
    public static var applicationDocumentsDirectory = {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    }()
    
    public static func standardStoreURL(forModelNamed name: String) -> URL {
        return Self.applicationDocumentsDirectory.appendingPathComponent("\(name).sqlite")
    }
    
    public static func appGroupURL(forModelNamed name: String, securityGroupIdentifier identifier: String) -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("Could not find the container for security group: \(identifier). Did you add the App Groups capability to your app's provisioning profile?")
        }
        return containerURL.appendingPathComponent("\(name).sqlite")
    }

    // MARK: - Public API -
    var managedObjectContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    open func createTemporaryContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    open func save(andCheckForChanges check: Bool = true) {
        if check && !managedObjectContext.hasChanges {
            return
        }
        do {
            try self.managedObjectContext.save()
        } catch let error as NSError {
            print(error.localizedDescription)
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
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
}
