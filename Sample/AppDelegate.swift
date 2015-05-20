//
//  AppDelegate.swift
//  Sample
//
//  Created by phimage on 20/05/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import UIKit
import CoreData
import PhiLipsStack

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    var stack: CoreDataStack {
        return CoreDataStack.defaultStack
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // configure if needed
        stack.modelName = "MyModel" // because model name is not application name
        stack.verbose = true // in test/debug mode

        // Check stack consistant
        if !stack.valid() {
            if let error = stack.lastError {
                NSLog("Unresolved error \(error), \(error.userInfo)")
            }
            abort()
        }
        
        // test code
        var entity: Entity = Entity.create()
        entity.attribute = "test"
        entity.attribute1 = true
        
        return true
    }

    func applicationDidEnterBackground(application: UIApplication) {
        stack.save(force: false, errorHandler : { (error: NSError) -> () in
             NSLog("Unresolved error \(error), \(error.userInfo)")
        })
    }

    func applicationWillTerminate(application: UIApplication) {
        stack.save(force: true) { (error: NSError) -> () in
            NSLog("Unresolved error \(error), \(error.userInfo)")
        }
    }

}

