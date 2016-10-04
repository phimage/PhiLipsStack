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
extension NSManagedObject {
 
    // MARK: class functions

    public class func createFetchRequest<ResultType : NSFetchRequestResult>(_ predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> NSFetchRequest<ResultType> {
        let request = NSFetchRequest<ResultType>(entityName: self.pls_entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }
    
    
    open class var entityName: String { // subclass can define the value of entityName
        var name = NSStringFromClass(self)
        name = name.components(separatedBy: ".").last!
        return name
    }
    
    public class var pls_entityName: String {
        return self.entityName
    }
    
    public class func pls_entity(_ managedObjectContext: NSManagedObjectContext = NSManagedObjectContext.default) -> NSEntityDescription! {
        return NSEntityDescription.entity(forEntityName: self.pls_entityName, in: managedObjectContext)
    }

    //MARK: Entity creation
   
    public class func create(context: NSManagedObjectContext = NSManagedObjectContext.default) -> Self {
        let entityDescription = pls_entity(context)
     
        let obj = self.init(entity: entityDescription!, insertInto: context)
        return obj
    }
    
    public class func create(with attributes: [String : AnyObject], context: NSManagedObjectContext = NSManagedObjectContext.default) -> Self {
        let object = create(context: context)
        if attributes.count > 0 {
            object.setValuesForKeys(attributes)
        }
        return object
    }
    
    public class func findFirstOrCreate<T: NSManagedObject>(context: NSManagedObjectContext = NSManagedObjectContext.default, error: NSErrorPointer? = nil) -> T {
        return self.findFirstOrCreate(with: NSPredicate(value: true)/* XXX extract var ***/, context: context)
    }
    
    public class func findFirstOrCreate<T: NSManagedObject>(with predicate: NSPredicate, context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> T {
        
        let fetchRequest: NSFetchRequest<T> = self.createFetchRequest(predicate)
        fetchRequest.fetchLimit = 1
        fetchRequest.entity = pls_entity(context)
        
        var fetchedObjects: [AnyObject]?
        context.performAndWait({ () -> Void in
            fetchedObjects = self.fetch(fetchRequest, context: context, errorHandler: errorHandler)
        })
        if let array = fetchedObjects, let firstObject = array.first as? T {
            return firstObject
        }
        let object: T = (create(context:context) as? T)!
        return object
    }

    //MARK: context method
    
    public func deleteObject(_ errorHandler: ErrorHandler? = nil) -> Bool {
        var error: NSError?
        do {
            try self.validateForDelete()
            self.managedObjectContext?.delete(self)
            return true
        } catch let error1 as NSError {
            error = error1
        }
        CoreDataStack.handleError(self.managedObjectContext, error: error, errorHandler: errorHandler)
        return false
    }

    public class func deleteAll(context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> Int {
        var result = 0
        if let objects: [NSManagedObject] = self.all(context: context, errorHandler: errorHandler) {
            for o in objects {
                if o.deleteObject(errorHandler) {
                    result += 1
                }
            }
        }
        return result
    }
    
    public class func deleteAll(for predicate: NSPredicate, context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> Int {
        var result = 0
        if let objects: [NSManagedObject] = self.find(for: predicate, context: context, errorHandler: errorHandler) {
            for o in objects {
                if o.deleteObject(errorHandler) {
                    result += 1
                }
            }
        }
        return result
    }

    public func save(errorHandler: ErrorHandler? = nil) -> Bool {
        if let context = self.managedObjectContext , context.hasChanges {
            do {
                try context.save()
                return true
            } catch let error as NSError {
                CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
            }
            return false
        }
        return false
    }

    public func insert(context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) {
        var error: NSError?
        do {
            try self.validateForInsert()
            context.insert(self)
        } catch let error1 as NSError {
            error = error1
        }
        CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
    }

    //MARK: fetch
    
    public class func all<ResultType : NSFetchRequestResult>(context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> [ResultType]? {
        return self.fetch(self.createFetchRequest(), context: context, errorHandler: errorHandler)
    }

    public class func find<ResultType : NSFetchRequestResult>(for predicate: NSPredicate, context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> [ResultType]? {
        let request: NSFetchRequest<ResultType> = self.createFetchRequest(predicate)
        return self.fetch(request, context: context, errorHandler: errorHandler)
    }
    
    public class func fetch<ResultType : NSFetchRequestResult>(_ request: NSFetchRequest<ResultType>, context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> [ResultType]? {
        do {
            return try context.fetch(request)
        } catch let error as NSError {
            CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
        } catch {
            CoreDataStack.handleError(context, error: nil, errorHandler: errorHandler)
        }
        return nil
    }
    
    public class func count<ResultType : NSFetchRequestResult>(for request: NSFetchRequest<ResultType>, context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> Int {
        do {
            let result = try context.count(for: request)
            return result
        } catch(let error) {
            CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
        }
        return 0
    }

    public class func count(_ predicate: NSPredicate? = nil, context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> Int {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = self.createFetchRequest(predicate)
        fetchRequest.includesPropertyValues = false
        fetchRequest.includesSubentities = false
        fetchRequest.propertiesToFetch = []

        return count(for: fetchRequest, context:context, errorHandler: errorHandler)
    }

}

// MARK: NSExpression(forFunction)
public extension NSManagedObject {
    
    public class func function(_ function: String, fieldName: [String], predicate : NSPredicate? = nil, context: NSManagedObjectContext = NSManagedObjectContext.default, errorHandler: ErrorHandler? = nil) -> [Double] {
        
        var expressionsDescription = [NSExpressionDescription]()
        for field in fieldName{
            let expression = NSExpression(forKeyPath: field)
            let expressionDescription = NSExpressionDescription()
            expressionDescription.expression = NSExpression(forFunction: function, arguments: [expression])
            expressionDescription.expressionResultType = NSAttributeType.doubleAttributeType
            expressionDescription.name = field
            expressionsDescription.append(expressionDescription);
        }

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = self.createFetchRequest(predicate)
        fetchRequest.propertiesToFetch = expressionsDescription
        fetchRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        var results = [AnyObject]();
        var resultValue = [Double]();
        context.performAndWait({ () -> Void in
            do {
                results = (try context.fetch(fetchRequest)) as! [NSDictionary];
                var tempResult = [Double]()
                for result in results{
                    for field in fieldName{
                        let value = result.value(forKey: field) as! Double
                        tempResult.append(value)
                    }
                }
                resultValue = tempResult
            } catch let error as NSError {
                CoreDataStack.handleError(context, error: error, errorHandler: errorHandler)
            }
        })
        return resultValue
    }
    
    public class func sum(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("sum:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func sum(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = sum(context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
    public class func max(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("max:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func max(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = max(context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
    public class func min(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("min:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func min(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = min(context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
    public class func avg(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: [String], predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> [Double] {
        return function("average:", fieldName: fieldName, predicate: predicate, context: context, errorHandler: errorHandler)
    }
    
    public class func avg(_ context: NSManagedObjectContext = NSManagedObjectContext.default, fieldName: String, predicate : NSPredicate? = nil, errorHandler: ErrorHandler? = nil) -> Double! {
        let results = avg(context, fieldName: [fieldName], predicate: predicate, errorHandler: errorHandler)
        return results.isEmpty ? 0 : results[0]
    }
    
}
