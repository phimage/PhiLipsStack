//
//  Entity.swift
//  PhiLipsStack
//
//  Created by phimage on 20/05/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import Foundation
import CoreData

@objc(Entity)
class Entity: NSManagedObject {

    @NSManaged
    var attribute: String
    @NSManaged
    var attribute1: NSNumber
    
}
