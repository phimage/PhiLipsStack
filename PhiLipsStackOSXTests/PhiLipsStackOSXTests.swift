//
//  PhiLipsStackOSXTests.swift
//  PhiLipsStackOSXTests
//
//  Created by phimage on 20/05/15.
//  Copyright (c) 2015 phimage. All rights reserved.
//

import Cocoa
import XCTest

#if os(OSX)
    import PhiLipsStackOSX
#endif
#if os(iOS)
    import PhiLipsStack
#endif

class PhiLipsStackTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        CoreDataStack.defaultStack.modelBundle = NSBundle(forClass: self.dynamicType)
        CoreDataStack.defaultStack.modelName = "Test"
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testContext() {
        XCTAssertNotNil(CoreDataStack.defaultStack.managedObjectContext, "Not able to get the context for default(sqlite) stack")
    }
    
    func testExample() {
        XCTAssertNotNil(CoreDataStack.inMemoryStack.managedObjectContext, "Not able to get the context for memory stack")
    }
    
}
