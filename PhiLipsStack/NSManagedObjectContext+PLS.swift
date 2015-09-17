//
//  NSManagedObjectContext+PLS.swift
//  PhiLipsStack
//
//  Created by phimage on 19/05/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import Foundation
import CoreData

/** PLS Extends NSManagedObjectContext

*/
public extension NSManagedObjectContext {

    public static var defaultContext: NSManagedObjectContext {
        return CoreDataStack.defaultStack.managedObjectContext
    }

    private struct Key {
        static let coreDataStack = UnsafePointer<Void>(bitPattern: Selector("coreDataStack").hashValue)
    }

    internal (set) var coreDataStack: CoreDataStack? {
        get {
            if let obj = objc_getAssociatedObject(self, Key.coreDataStack) as? CoreDataStack {
                return obj
            }
            return nil
        }
        set {
            objc_setAssociatedObject(self, Key.coreDataStack, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

}