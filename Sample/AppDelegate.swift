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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // configure if needed
        stack.modelName = "MyModel" // because model name is not application name
        stack.verbose = true // in test/debug mode
        
        // Check stack consistant
        let valid = stack.valid { (error) -> () in
            print(error)
        }
        if valid {
            // test code
            let entity: Entity = Entity.create()
            entity.attribute = "test"
            entity.attribute1 = true
            
            /*entity.delete { (error) -> () in
             
             }*/
            
            let entities: [Entity]? = Entity.find(for: NSPredicate(value: true))  { error in
                print(error)
            }
            print(entities)
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        let _ = stack.save(false) { error in
            print(error)
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        let _ = stack.save(true) { error in
            print(error)
        }
    }

}

