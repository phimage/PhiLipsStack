//
//  NSManagedObject+PLS.swift
//  PhiLipsStack
//
//  Created by phimage on 20/03/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import Foundation
import CoreData

/** PLS Extends NSManagedObject

*/
public extension NSManagedObject {
 
    // MARK: class functions

    public class func fetchRequest() -> NSFetchRequest {
        return NSFetchRequest(entityName: self.pls_entityName)
    }
    
    public class var entityName: String { // subclass can define the value of entityName
        return NSStringFromClass(self)
    }
    
    public class var pls_entityName: String {
        return self.entityName
    }
    
    public class func pls_entity(managedObjectContext: NSManagedObjectContext = NSManagedObjectContext.defaultContext) -> NSEntityDescription! {
        return NSEntityDescription.entityForName(self.pls_entityName, inManagedObjectContext: managedObjectContext)
    }

    //MARK: Entity creation
   
    public class func create<T: NSManagedObject>(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext) -> T {
        let entityDescription = pls_entity(managedObjectContext: context)
        var obj = NSManagedObject(entity: entityDescription!, insertIntoManagedObjectContext: context)
        return obj as! T
    }
    
    public class func findFirstOrCreate<T: NSManagedObject>(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, error: NSErrorPointer = nil) -> T {
        return self.findFirstOrCreateWithPredicate(NSPredicate(value: true)/* XXX extract var ***/, context: context)
    }
    
    public class func findFirstOrCreateWithPredicate<T: NSManagedObject>(predicate: NSPredicate, context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) -> T {

        let fetchRequest = self.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = predicate
        fetchRequest.entity = pls_entity(managedObjectContext: context)

        var fetchedObjects: [AnyObject]?
        context.performBlockAndWait({ () -> Void in
            fetchedObjects = self.fetch(fetchRequest, context: context, errorHandler: errorHandler)
        })
        if let array = fetchedObjects, firstObject = array.first as? T {
            return firstObject
        }
        let obj: T = create(context: context)
        return obj
    }
    
    //MARK: context method
    
    public func delete(errorHandler: ErrorHandler? = nil) -> Bool {
        var error: NSError?
        if self.validateForDelete(&error){
            self.managedObjectContext?.deleteObject(self)
            return true
        }
        CoreDataStack.handleError(self.managedObjectContext, error: error, errorHandler: errorHandler)
        return false
    }

    public class func deleteAll(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) {
        if let all = self.all(context: context, errorHandler: errorHandler) {
            for o in all {
                o.delete(errorHandler: errorHandler)
            }
        }
    }

    public func save(errorHandler: ErrorHandler? = nil) -> Bool {
        if let context = self.managedObjectContext where context.hasChanges {
            var error: NSError?
            let result = context.save(&error)
            CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
        }
        return false
    }

    public func insert(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) {
        var error: NSError?
        if self.validateForInsert(&error){
            context.insertObject(self)
        }
        CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
    }

    //MARK: fetch
    
    public class func all(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) -> [NSManagedObject]? {
        return self.fetch(self.fetchRequest(), context: context, errorHandler: errorHandler)
    }

    public class func find(predicate: NSPredicate, context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) -> [NSManagedObject]? {
        var request = self.fetchRequest()
        request.predicate = predicate
        return self.fetch(request, context: context, errorHandler: errorHandler)
    }
    
    public class func fetch(request: NSFetchRequest, context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) -> [NSManagedObject]? {
        var error: NSError?
        let result = context.executeFetchRequest(request, error: &error) as? [NSManagedObject]
        CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
        return result
    }

    public class func count(predicate : NSPredicate? = nil, context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) -> Int {
        var fetchRequest = self.fetchRequest()
        fetchRequest.includesPropertyValues = false
        fetchRequest.includesSubentities = false
        fetchRequest.predicate = predicate
        fetchRequest.propertiesToFetch = []

        return count(fetchRequest, context:context, errorHandler: errorHandler)
    }

    public class func count(request: NSFetchRequest, context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) -> Int {
        var error: NSError?
        let result = context.countForFetchRequest(request, error: &error)
        CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
        return result
    }
}

// MARK: NSExpression(forFunction)
public extension NSManagedObject {
    
    public class func function(function: String, fieldName: [String], predicate : NSPredicate? = nil, context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, errorHandler: ErrorHandler? = nil) -> [Double] {
        
        var expressionsDescription = [NSExpressionDescription]()
        var error : NSError?
        for field in fieldName{
            var expression = NSExpression(forKeyPath: field)
            var expressionDescription = NSExpressionDescription()
            expressionDescription.expression = NSExpression(forFunction: function, arguments: [expression])
            expressionDescription.expressionResultType = NSAttributeType.DoubleAttributeType
            expressionDescription.name = field
            expressionsDescription.append(expressionDescription);
        }

        var fetchRequest = self.fetchRequest()
        fetchRequest.propertiesToFetch = expressionsDescription
        fetchRequest.resultType = NSFetchRequestResultType.DictionaryResultType
        fetchRequest.predicate = predicate
        var results = [AnyObject]();
        var resultValue = [Double]();
        context.performBlockAndWait({ () -> Void in
            results = context.executeFetchRequest(fetchRequest, error: &error)! as! [NSDictionary];
            var tempResult = [Double]()
            for result in results{
                for field in fieldName{
                    var value = result.valueForKey(field) as! Double
                    tempResult.append(value)
                }
            }
            resultValue = tempResult
            CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
        })
        return resultValue
    }
    
    public class func sum(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("sum:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func sum(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = sum(context: context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
    public class func max(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("max:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func max(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = max(context: context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
    public class func min(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("min:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func min(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = min(context: context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
    public class func avg(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("average:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func avg(context: NSManagedObjectContext = NSManagedObjectContext.defaultContext, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = avg(context: context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
}
