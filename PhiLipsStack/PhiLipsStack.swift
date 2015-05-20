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
            
            var options = CoreDataStack.storeOptions(automigrate: self.autoMigrate)
            if coordinator.addPersistentStoreWithType(self.storeType.key, configuration: nil, URL: self.storeURL, options: options, error: &error) == nil {
                self.log("Unresolved error \(error), \(error!.userInfo)")
                
                // Report any error we got.
                self.lastError = self.createInitError(error)
                
                if self.removeIncompatibleStore && self.removeStore() {
                    self.log("Incompatible model version has been removed \(self.storeURL!.lastPathComponent)")
                    self.log("Will recreate store")
                    
                    options = CoreDataStack.storeOptions()
                    if coordinator.addPersistentStoreWithType(self.storeType.key, configuration: nil, URL: self.storeURL, options: options, error: &error) == nil {
                        self.lastError = self.createInitError(error)
                        self.log("Failed to recreate store, \(error), \(error!.userInfo)")
                        return nil
                    }
                    self.log("Did recreate store")
                    return coordinator
                }
                
                return nil
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
            let result = moc.save(&error)
            CoreDataStack.handleError(moc, error: error, errorHandler: errorHandler)
            return result
        }
        return false
    }

    public func managedObjectForURIRepresentation(uri: NSURL) -> NSManagedObject? {
        if let psc = self.persistentStoreCoordinator,
            objectID = psc.managedObjectIDForURIRepresentation(uri),
            moc = managedObjectContext
        {
            return moc.objectWithID(objectID)
        }
        return nil
    }

    //MARK: try to remove the store

    public func removeStore(errorHandler: ErrorHandler? = nil) -> Bool {
        if let url = self.storeURL where self.storeType == CoreDataStoreType.SQLite {

            if  let rawURL = url.absoluteString,
                shmSidecar = NSURL(string: rawURL.stringByAppendingString("-shm")),
                walSidecar: NSURL = NSURL(string: rawURL.stringByAppendingString("-wal")) {
                    return self.removeItemAtURL(url, errorHandler: errorHandler) &&
                        self.removeItemAtURL(shmSidecar, errorHandler: errorHandler) &&
                        self.removeItemAtURL(walSidecar, errorHandler: errorHandler)
            }
        }
        return true
    }

    // MARK: log
    internal func log(message: String) {
        if verbose {
            println(message) // XXX maybe add handler to receive log message externally
        }
    }
    
    // MARK: private

    private func createInitError(error: NSError?) -> NSError {
        let dict = CoreDataStack.buildUserInfo(description: "Failed to initialize the application's saved data",
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
            let dir = self.fileManager.URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).last as! NSURL // XXX not safe
            #else
            let dir = (self.fileManager.URLsForDirectory(NSSearchPathDirectory.ApplicationSupportDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).last as! NSURL).URLByAppendingPathComponent(self.applicationName)
            self.ensureDirectoryCreatedAtURL(dir)
        #endif
        return dir
    }

    private static var sqliteStoreURL: NSURL {
        let dbName = self.applicationName + ".sqlite"
        return self.storeURL.URLByAppendingPathComponent(dbName)
        
    }

    private class func ensureDirectoryCreatedAtURL(dir: NSURL) {
        if let path = dir.absoluteString where !self.fileManager.fileExistsAtPath(path) {
           self.fileManager.createDirectoryAtURL(dir, withIntermediateDirectories: true, attributes: nil, error: nil)
        }
    }
    
    private func removeItemAtURL(url: NSURL, errorHandler: ErrorHandler?) -> Bool {
        var deleteError: NSError?
        if let urlString = url.absoluteString where !CoreDataStack.fileManager.fileExistsAtPath(urlString) {
            return true // do not fail if not exist
        }
        if CoreDataStack.fileManager.removeItemAtURL(url, error: &deleteError) {
            return true
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
