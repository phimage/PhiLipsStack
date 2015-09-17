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
       let valid = stack.valid { (error) -> () in
             NSLog("Unresolved error \(error), \(error.userInfo)")
        }
        if valid {
            // test code
            let entity: Entity = Entity.create()
            entity.attribute = "test"
            entity.attribute1 = true
            
            /*entity.delete { (error) -> () in
                
            }*/
            
            Entity.find(NSPredicate(value: true)) { (error) -> () in
                NSLog("find error \(error), \(error.userInfo)")
            }
        }
        
        return true
    }

    func applicationDidEnterBackground(application: UIApplication) {
        stack.save(false, errorHandler : { (error) -> () in
             NSLog("save error \(error), \(error.userInfo)")
        })
    }

    func applicationWillTerminate(application: UIApplication) {
        stack.save(true) { (error) -> () in
            NSLog("save error \(error), \(error.userInfo)")
        }
    }

}

