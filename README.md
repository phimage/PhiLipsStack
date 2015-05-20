# PhiLipsStack - ϕ:lips:
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat
            )](http://mit-license.org)
[![Platform](http://img.shields.io/badge/platform-iOS/MacOS-lightgrey.svg?style=flat
             )](https://developer.apple.com/resources/)
[![Language](http://img.shields.io/badge/language-swift-orange.svg?style=flat
             )](https://developer.apple.com/swift)
[![Issues](https://img.shields.io/github/issues/phimage/PhiLipsStack.svg?style=flat
           )](https://github.com/phimage/Prephirences/issues)

[<img align="left" src="/logo-128x128.png" hspace="20">](#logo)
PhiLipsStack framework provide a default `NSManagedObjectContext` and functions on `NSManagedObject` which use by default this context

## Stack
A stack is composed of three element, the `managedObjectModel`, `persistentStoreCoordinator` and the `managedObjectContext`

### The model
The stack initialize, according to its type and optionnaly an url, the `NSManagedObjectModel`

By default the application name is used for your model name ie. model file `MyAppName.xcdatamodel`

If your model have another name, you can set your own model name by calling `myStack.modelName = "MyModelName"`
```swift
CoreDataStack.defaultStack.modelName = "MyModelName"
```
:warning This must be done before requesting any of `managedObjectContext`, `persistentStoreCoordinator`, `managedObjectModel`

### The persistance coordinator

TODO automigrate option 
TODO if not able to load data removeStore automatically to recreate one

### The context

The default context is the `managedObjectContext` attribute of default stack `CoreDataStack.defaultStack` and can be acceded that way
```swift
NSManagedObjectContext.defaultContext
```


## Play with managed objects

### Create

Your  `NSManagedObject` must contains @objc(class name) or you must override `entityName` class var

```swift
@objc(Entity)
class Entity: NSManagedObject {
@NSManaged var title: String
@NSManaged var valid: NSNumber
}
```
You should use [mogenerator](https://github.com/rentzsch/mogenerator) to generate your `NSManagedObject`

```swift
var entity: Entity = Entity.create()
```

### Get/Fetch
Get all object of one type
```swift
if let entities = Entity.all() ? [Entity] { .. }

let entityCount = Entity.count()
```
Some filtering using `NSPredicate`
```
if let entities = Entity. find(predicate) ? [Entity] { .. }
let entityCount = Entity.count(predicate)

```

For more advanced fetch with predicates, you should use [QueryKit](https://github.com/QueryKit/QueryKit)

There is mogerator templates for swift [here: machine.swift.motemplate](https://github.com/phimage/mogenerator-template)

### Save
You can save immediatly on entity
```swift
entity.save()
```
but you can save the context when application will terminate or did enter background
```swift
stack.save()
```

### Delete
```swift
entity.delete()

```
You can also delete all objects of one type
```swift
Entity.deleteAll()

```

### Error handling
Most of the functions provided by this framework allow to pass an error handler, a block : (NSError) -> Void
TODO Example
```swift

```

If no error handler is provided, you can access the last error handled by the stack
```swift
if let error = myStack.lastError {..}
```

At application start you can also check stack
```swift
if !myStack.valid() {
   // application shutdown
}

```

 
# Setup #

## Using xcode project ##

1. Drag PhiLipsStack.xcodeproj to your project/workspace or open it to compile it
2. Add the PhiLipsStack framework to your project

## Using [cocoapods](http://cocoapods.org/) ##

Add `pod 'PhiLipsStack', :git => 'https://github.com/phimage/PhiLipsStack.git'` to your `Podfile` and run `pod install`. 

Add `use_frameworks!` to the end of the `Podfile`.

# Licence #
```
The MIT License (MIT)

Copyright (c) 2015 Eric Marchand (phimage)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

# Logo #
Inspired by [apple swift logo](http://en.wikipedia.org/wiki/File:Apple_Swift_Logo.png)
## Why a logo?
I like to see an image for each of my project when I browse them with [SourceTree](http://www.sourcetreeapp.com/)