//
//  PhiLipsStack.swift
//  PhiLipsStack
//
//  Created by phimage on 01/04/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import Foundation
import CoreData

public class CoreDataStack {
    
    // MARK: instances
    public static var sqliteStack: CoreDataStack {
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance : CoreDataStack? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = CoreDataStack(storeType: .SQLite, storeURL: CoreDataStack.sqliteStoreURL)
        }
        return Static.instance!
    }
    
    public static var inMemoryStack: CoreDataStack {
        struct Static {
            static var onceToken : dispatch_once_t = 0
            static var instance: CoreDataStack? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = CoreDataStack(storeType: .InMemory, storeURL: nil)
        }
        return Static.instance!
    }
    
    public static var defaultStack: CoreDataStack = CoreDataStack.sqliteStack
    
    // MARK: attributes
    public let storeType: CoreDataStoreType
    public let storeURL: NSURL?
    
    // MARK configurations
    public var modelName: String = CoreDataStack.applicationName {
        didSet {
            assert(!modelLoaded, "Model already loaded in current stack")
        }
    }
    public var modelBundle = NSBundle.mainBundle() // bundle to look for model
    
    public var autoMigrate: Bool = true // create PersistentStore with NSMigratePersistentStoresAutomaticallyOption
    public var removeIncompatibleStore: Bool = true // remove store if failed to NSPersistentStoreCoordinator.addPersistentStoreWithType
    public var verbose: Bool = false // log some information with println

    public var dispatchErrorInQueue: Bool = true // dispatch error handler in queue to avoid wait of block execution

    // where last error could be stored
    public var lastError: NSError?
    
    // MARK: privates
    private var modelLoaded: Bool = false

    // MARK: init
    
    public init(storeType: CoreDataStoreType, storeURL: NSURL?) {
        self.storeType = storeType
        self.storeURL = storeURL
    }
    
    public convenience init(stack: CoreDataStack) { // clone config
        self.init(storeType: stack.storeType, storeURL: stack.storeURL)
    }

    // MARK: Core Data stack
    
    public lazy var managedObjectContext: NSManagedObjectContext! = {
        if let coordinator = self.persistentStoreCoordinator {
            var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
            managedObjectContext.coreDataStack = self
            managedObjectContext.persistentStoreCoordinator = coordinator
            return managedObjectContext
        }
        return nil
        }()
    
    public lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        if let managedObjectModel = self.managedObjectModel {
        
            var coordinator: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            var error: NSError? = nil
            
            var options = CoreDataStack.storeOptions(self.autoMigrate)
            do {
                try coordinator.addPersistentStoreWithType(self.storeType.key, configuration: nil, URL: self.storeURL, options: options)
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
                        try coordinator.addPersistentStoreWithType(self.storeType.key, configuration: nil, URL: self.storeURL, options: options)
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

    public lazy var managedObjectModel: NSManagedObjectModel? = {
        self.modelLoaded = true
        if let modelURL = self.modelBundle.URLForResource("\(self.modelName).momd/\(self.modelName)", withExtension: "mom") {
                return NSManagedObjectModel(contentsOfURL: modelURL)
        }
        return nil
        }()

    // MARK: handle errors
    
    public func valid(errorHandler: ErrorHandler? = nil) -> Bool {
        if self.managedObjectContext == nil {
            let error = lastError ?? createInitError(nil)
            errorHandler?(error)
            return false
        }
        return true
    }
    
    public class func handleError(context: NSManagedObjectContext?, error: NSError?, errorHandler: ErrorHandler?) {
        if let stack = context?.coreDataStack {
            stack.handleError(error, errorHandler: errorHandler)
        }
    }
    
    public func handleError(error: NSError?, errorHandler: ErrorHandler?) {
        if let e = error {
            self.lastError = e
            if let handler = errorHandler where self.dispatchErrorInQueue {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler(e)
                })
            } else {
                errorHandler?(e)
            }
        }
    }

    // MARK: Core Data Saving Support

    public func save(force: Bool = false, errorHandler: ErrorHandler? = nil) -> Bool {
        if let moc = self.managedObjectContext where (moc.hasChanges || force){
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
    public func removeStore(errorHandler: ErrorHandler? = nil) -> Bool {
        if let url = self.storeURL where self.storeType == CoreDataStoreType.SQLite {
            
            let rawURL = url.absoluteString
            if  let shmSidecar = NSURL(string: rawURL.stringByAppendingString("-shm")),
                walSidecar: NSURL = NSURL(string: rawURL.stringByAppendingString("-wal")) {
                    return self.removeItemAtURL(url, errorHandler: errorHandler) &&
                        self.removeItemAtURL(shmSidecar, errorHandler: errorHandler) &&
                        self.removeItemAtURL(walSidecar, errorHandler: errorHandler)
            }
        }
        return true
    }
    
   /* Delete all managed object */
    func deleteAll() {
        if let mom = managedObjectModel, moc = managedObjectContext {
            for entity in mom.entities {
                if let entityType = NSClassFromString(entity.managedObjectClassName) as? NSManagedObject.Type {
                    entityType.deleteAll(moc)
                }
            }
        }
    }
    
    // MARK: Refresh
    
    public func managedObjectForURIRepresentation(uri: NSURL) -> NSManagedObject? {
        if let psc = self.persistentStoreCoordinator,
            objectID = psc.managedObjectIDForURIRepresentation(uri),
            moc = managedObjectContext
        {
            return moc.objectWithID(objectID)
        }
        return nil
    }

    func refreshObjects(objectIDS objectIDS: [NSManagedObjectID], mergeChanges: Bool, errorHandler: ErrorHandler? = nil) {
        if let moc = managedObjectContext {
            for objectID in objectIDS {
                var error: NSError?
                moc.performBlockAndWait({ () -> Void in
                    do {
                        let object = try moc.existingObjectWithID(objectID)
                        if !object.fault && error == nil {
                            moc.refreshObject(object, mergeChanges: mergeChanges)
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
    
    func refreshAllObjects(mergeChanges mergeChanges: Bool, errorHandler: ErrorHandler? = nil) {
        if let moc = managedObjectContext {
            var objectIDS = [NSManagedObjectID]()
            for managedObject in moc.registeredObjects {
                objectIDS.append(managedObject.objectID)
            }
            self.refreshObjects(objectIDS: objectIDS, mergeChanges: mergeChanges, errorHandler: errorHandler)
        }
    }

    // MARK: log
    internal func log(message: String) {
        if verbose {
            print(message) // XXX maybe add handler to receive log message externally
        }
    }
    
    // MARK: private

    private func createInitError(error: NSError?) -> NSError {
        let dict = CoreDataStack.buildUserInfo("Failed to initialize the application's saved data",
            failureReason: "There was an error creating or loading the application's saved data.",
            recoverySuggestion: "Remove application data directory",
            error: error)
        return NSError(domain: CoreDataStack.applicationIdentifier, code: 9999, userInfo: dict)
    }

    private static func storeOptions(automigrate: Bool = false) -> [NSObject: AnyObject]
    {
        var sqliteOptions: [String: String] = [String: String] ()
        sqliteOptions["WAL"] = "journal_mode"
        var options: [NSObject: AnyObject] = [NSObject: AnyObject] ()
        options[NSMigratePersistentStoresAutomaticallyOption] = NSNumber(bool: true)
        options[NSInferMappingModelAutomaticallyOption] = NSNumber(bool: automigrate)
        options[NSSQLitePragmasOption] = sqliteOptions
        return options
    }

    private static var applicationIdentifier: String {
        return NSBundle.mainBundle().bundleIdentifier ?? "PhiLipsStack"
    }

    private static var applicationName : String {
        return NSBundle.mainBundle().infoDictionary!["CFBundleName"] as? String  ?? "PhiLipsStack"
    }
    
    public class var fileManager: NSFileManager {
        return NSFileManager.defaultManager()
    }
    
    public class var storeURL: NSURL {
        #if os(iOS)
            let dir = self.fileManager.URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).last! // XXX not safe
            #else
            let dir = (self.fileManager.URLsForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).last!).URLByAppendingPathComponent(self.applicationName)
            self.ensureDirectoryCreatedAtURL(dir)
        #endif
        return dir
    }
    
    class func storeURLForName(name: String) -> NSURL {
        return self.storeURL.URLByAppendingPathComponent(name)
    }

    private static var sqliteStoreURL: NSURL {
        return storeURLForName(self.applicationName + ".sqlite")
    }

    private class func ensureDirectoryCreatedAtURL(dir: NSURL) {
        let path = dir.absoluteString
        if !self.fileManager.fileExistsAtPath(path) {
            do {
                try self.fileManager.createDirectoryAtURL(dir, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                print("Error when creating directory \(dir): \(error)")
            }
        }
    }
    
    private func removeItemAtURL(url: NSURL, errorHandler: ErrorHandler?) -> Bool {
        var deleteError: NSError?
        let urlString = url.absoluteString
        if !CoreDataStack.fileManager.fileExistsAtPath(urlString) {
            return true // do not fail if not exist
        }
        do {
            try CoreDataStack.fileManager.removeItemAtURL(url)
            return true
        } catch let error as NSError {
            deleteError = error
        }
        self.handleError(deleteError, errorHandler: errorHandler)
        return false
    }
    
    private class func buildUserInfo(description: String = "", failureReason: String = "", recoverySuggestion: String = "", error: NSError? = nil) -> [String : AnyObject] {
        let dict: [String : AnyObject] = [
            NSLocalizedDescriptionKey : description,
            NSLocalizedFailureReasonErrorKey : failureReason,
            NSLocalizedRecoverySuggestionErrorKey : recoverySuggestion,
            NSUnderlyingErrorKey : error ?? ""
        ]
        return dict
    }

}

public enum CoreDataStoreType {
    case SQLite
    case Binary
    case InMemory
    #if os(OSX)
    case XML
    #endif
    
    public var key: String {
        #if os(iOS)
            switch(self){
            case SQLite: return NSSQLiteStoreType
            case Binary: return NSBinaryStoreType
            case InMemory: return NSInMemoryStoreType
            }
        #endif
        #if os(OSX)
            switch(self){
            case SQLite: return NSSQLiteStoreType
            case Binary: return NSBinaryStoreType
            case InMemory: return NSInMemoryStoreType
            case XML: return NSXMLStoreType
            }
        #endif
    }
}

public typealias ErrorHandler = (NSError) -> ()
