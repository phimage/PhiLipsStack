//
//  PhiLipsStack.swift
//  PhiLipsStack
//
//  Created by phimage on 01/04/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import Foundation
import CoreData

open class CoreDataStack {
    
    // MARK: instances
    open static var sqliteStack = CoreDataStack(storeType: .sqLite, storeURL: CoreDataStack.sqliteStoreURL)
    open static var inMemoryStack = CoreDataStack(storeType: .inMemory, storeURL: nil)
    
    open static var defaultStack: CoreDataStack = CoreDataStack.sqliteStack
    
    // MARK: attributes
    open let storeType: CoreDataStoreType
    open let storeURL: URL?
    
    // MARK configurations
    open var modelName: String = CoreDataStack.applicationName {
        didSet {
            assert(!modelLoaded, "Model already loaded in current stack")
        }
    }
    open var modelBundle = Bundle.main // bundle to look for model
    
    open var autoMigrate: Bool = true // create PersistentStore with NSMigratePersistentStoresAutomaticallyOption
    open var removeIncompatibleStore: Bool = true // remove store if failed to NSPersistentStoreCoordinator.addPersistentStoreWithType
    open var verbose: Bool = false // log some information with println

    open var dispatchErrorInQueue: Bool = true // dispatch error handler in queue to avoid wait of block execution

    // where last error could be stored
    open var lastError: Error?
    
    // MARK: privates
    fileprivate var modelLoaded: Bool = false

    // MARK: init
    
    public init(storeType: CoreDataStoreType, storeURL: URL?) {
        self.storeType = storeType
        self.storeURL = storeURL
    }
    
    public convenience init(stack: CoreDataStack) { // clone config
        self.init(storeType: stack.storeType, storeURL: stack.storeURL)
    }

    // MARK: Core Data stack
    
    open lazy var managedObjectContext: NSManagedObjectContext! = {
        if let coordinator = self.persistentStoreCoordinator {
            var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
            managedObjectContext.coreDataStack = self
            managedObjectContext.persistentStoreCoordinator = coordinator
            return managedObjectContext
        }
        return nil
        }()
    
    open lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        if let managedObjectModel = self.managedObjectModel {
        
            var coordinator: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            var error: NSError? = nil
            
            var options = CoreDataStack.storeOptions(self.autoMigrate)
            do {
                try coordinator.addPersistentStore(ofType: self.storeType.key, configurationName: nil, at: self.storeURL, options: options)
            } catch var error2 as NSError {
                error = error2
                self.log("Unresolved error \(error), \(error!.userInfo)")
                
                // Report any error we got.
                self.lastError = self.createInitError(error)
                
                if self.removeIncompatibleStore && self.removeStore() {
                    self.log("Incompatible model version has been removed \(self.storeURL!.lastPathComponent)")
                    self.log("Will recreate store")
                    
                    options = CoreDataStack.storeOptions()
                    do {
                        try coordinator.addPersistentStore(ofType: self.storeType.key, configurationName: nil, at: self.storeURL, options: options)
                    } catch var error1 as NSError {
                        error = error1
                        self.lastError = self.createInitError(error)
                        self.log("Failed to recreate store, \(error), \(error!.userInfo)")
                        return nil
                    } catch {
                        fatalError()
                    }
                    self.log("Did recreate store")
                    return coordinator
                }
                
                return nil
            } catch {
                fatalError()
            }
            return coordinator
        }
        return nil
        }()

    open lazy var managedObjectModel: NSManagedObjectModel? = {
        self.modelLoaded = true
        if let modelURL = self.modelBundle.url(forResource: "\(self.modelName).momd/\(self.modelName)", withExtension: "mom") {
                return NSManagedObjectModel(contentsOf: modelURL)
        }
        return nil
        }()

    // MARK: handle errors
    
    open func valid(_ errorHandler: ErrorHandler? = nil) -> Bool {
        if self.managedObjectContext == nil {
            let error = lastError ?? createInitError(nil)
            errorHandler?(error)
            return false
        }
        return true
    }
    
    open class func handleError(_ context: NSManagedObjectContext?, error: Error?, errorHandler: ErrorHandler?) {
        if let stack = context?.coreDataStack {
            stack.handleError(error, errorHandler: errorHandler)
        }
    }
    
    open func handleError(_ error: Error?, errorHandler: ErrorHandler?) {
        if let e = error {
            self.lastError = e
            if let handler = errorHandler , self.dispatchErrorInQueue {
                DispatchQueue.main.async(execute: { () -> Void in
                    handler(e)
                })
            } else {
                errorHandler?(e)
            }
        }
    }

    // MARK: Core Data Saving Support

    open func save(_ force: Bool = false, errorHandler: ErrorHandler? = nil) -> Bool {
        if let moc = self.managedObjectContext , (moc.hasChanges || force){
            var error: NSError?
            let result: Bool
            do {
                try moc.save()
                result = true
            } catch let error1 as NSError {
                error = error1
                result = false
            }
            CoreDataStack.handleError(moc, error: error, errorHandler: errorHandler)
            return result
        }
        return false
    }

    //MARK: try to remove the store
    open func removeStore(_ errorHandler: ErrorHandler? = nil) -> Bool {
        if let url = self.storeURL , self.storeType == CoreDataStoreType.sqLite {
            
            let rawURL = url.absoluteString
            var result = self.removeItem(atURL: url, errorHandler: errorHandler)

            if  let shmSidecar = URL(string: rawURL + "-shm") {
                result = self.removeItem(atURL:shmSidecar, errorHandler: errorHandler) || result
            }
            if let walSidecar = URL(string: rawURL + "-wal") {
                result = self.removeItem(atURL:walSidecar, errorHandler: errorHandler) || result
            }
        }
        return true
    }
    
   /* Delete all managed object */
    func deleteAll() -> Int {
        var result = 0
        if let mom = managedObjectModel, let moc = managedObjectContext {
            for entity in mom.entities {
                if let entityType = NSClassFromString(entity.managedObjectClassName) as? NSManagedObject.Type {
                    result = result + entityType.deleteAll(context: moc)
                }
            }
        }
        return result
    }
    
    // MARK: Refresh
    
    open func managedObjectForURIRepresentation(_ uri: URL) -> NSManagedObject? {
        if let psc = self.persistentStoreCoordinator,
            let objectID = psc.managedObjectID(forURIRepresentation: uri),
            let moc = managedObjectContext
        {
            return moc.object(with: objectID)
        }
        return nil
    }

    func refreshObjects(objectIDS: [NSManagedObjectID], mergeChanges: Bool, errorHandler: ErrorHandler? = nil) {
        if let moc = managedObjectContext {
            for objectID in objectIDS {
                var error: NSError?
                moc.performAndWait({ () -> Void in
                    do {
                        let object = try moc.existingObject(with: objectID)
                        if !object.isFault && error == nil {
                            moc.refresh(object, mergeChanges: mergeChanges)
                        } else {
                            self.handleError(error, errorHandler: errorHandler)
                        }
                    } catch let error1 as NSError {
                        error = error1
                    } catch {
                        fatalError()
                    }
                })
            }
        }
    }
    
    func refreshAllObjects(mergeChanges: Bool, errorHandler: ErrorHandler? = nil) {
        if let moc = managedObjectContext {
            var objectIDS = [NSManagedObjectID]()
            for managedObject in moc.registeredObjects {
                objectIDS.append(managedObject.objectID)
            }
            self.refreshObjects(objectIDS: objectIDS, mergeChanges: mergeChanges, errorHandler: errorHandler)
        }
    }

    // MARK: log
    internal func log(_ message: String) {
        if verbose {
            print(message) // XXX maybe add handler to receive log message externally
        }
    }
    
    // MARK: private

    fileprivate func createInitError(_ error: NSError?) -> NSError {
        let dict = CoreDataStack.buildUserInfo("Failed to initialize the application's saved data",
            failureReason: "There was an error creating or loading the application's saved data.",
            recoverySuggestion: "Remove application data directory",
            error: error)
        return NSError(domain: CoreDataStack.applicationIdentifier, code: 9999, userInfo: dict)
    }

    fileprivate static func storeOptions(_ automigrate: Bool = false) -> [AnyHashable: Any]
    {
        var sqliteOptions: [String: String] = [String: String] ()
        sqliteOptions["WAL"] = "journal_mode"
        var options: [AnyHashable: Any] = [AnyHashable: Any] ()
        options[NSMigratePersistentStoresAutomaticallyOption] = NSNumber(value: true as Bool)
        options[NSInferMappingModelAutomaticallyOption] = NSNumber(value: automigrate as Bool)
        options[NSSQLitePragmasOption] = sqliteOptions
        return options
    }

    fileprivate static var applicationIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "PhiLipsStack"
    }

    fileprivate static var applicationName : String {
        return Bundle.main.infoDictionary!["CFBundleName"] as? String  ?? "PhiLipsStack"
    }
    
    open class var fileManager: FileManager {
        return FileManager.default
    }
    
    open class var storeURL: URL {
        #if os(iOS)
            let dir = self.fileManager.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last! // XXX not safe
            #else
            let parent = self.fileManager.urls(for: FileManager.SearchPathDirectory.applicationSupportDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
            let dir = parent.appendingPathComponent(self.applicationName)
            self.ensureDirectoryCreated(atURL: dir)
        #endif
        return dir
    }
    
    class func storeURL(forName name: String) -> URL {
        return self.storeURL.appendingPathComponent(name)
    }

    fileprivate static var sqliteStoreURL: URL {
        return storeURL(forName: self.applicationName + ".sqlite")
    }

    fileprivate class func ensureDirectoryCreated(atURL dir: URL) {
        let path = dir.absoluteString
        if !self.fileManager.fileExists(atPath: path) {
            do {
                try self.fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                print("Error when creating directory \(dir): \(error)")
            }
        }
    }
    
    fileprivate func removeItem(atURL url: URL, errorHandler: ErrorHandler?) -> Bool {
        var deleteError: NSError?
        let urlString = url.path
        if !CoreDataStack.fileManager.fileExists(atPath: urlString) {
            return true // do not fail if not exist
        }
        do {
            try CoreDataStack.fileManager.removeItem(at: url)
            return true
        } catch let error as NSError {
            deleteError = error
        }
        self.handleError(deleteError, errorHandler: errorHandler)
        return false
    }
    
    fileprivate class func buildUserInfo(_ description: String = "", failureReason: String = "", recoverySuggestion: String = "", error: NSError? = nil) -> [String : AnyObject] {
        let dict: [String : AnyObject] = [
            NSLocalizedDescriptionKey : description as AnyObject,
            NSLocalizedFailureReasonErrorKey : failureReason as AnyObject,
            NSLocalizedRecoverySuggestionErrorKey : recoverySuggestion as AnyObject,
            NSUnderlyingErrorKey : error ?? "" as AnyObject
        ]
        return dict
    }

}

public enum CoreDataStoreType {
    case sqLite
    case binary
    case inMemory
    #if os(OSX)
    case xml
    #endif
    
    public var key: String {
        #if os(iOS)
            switch(self){
            case .sqLite: return NSSQLiteStoreType
            case .binary: return NSBinaryStoreType
            case .inMemory: return NSInMemoryStoreType
            }
        #elseif os(OSX)
            switch(self){
            case .sqLite: return NSSQLiteStoreType
            case .binary: return NSBinaryStoreType
            case .inMemory: return NSInMemoryStoreType
            case .xml: return NSXMLStoreType
            }
        #endif
    }
}

public typealias ErrorHandler = (Error) -> ()
