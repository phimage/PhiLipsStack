Pod::Spec.new do |s|

# ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
s.name         = "PhiLipsStack"
s.version      = "1.0.0"
s.summary      = "A Swift library to init Core Data Stack"
s.description  = <<-DESC
PhiLipsStack is a Swift library useful CoreDataStack object that provides
* managedObjectContext
* persistentStoreCoordinator
* managedObjectModel
And functions on `NSManagedObject` which use by default a context from default stack

DESC
s.homepage     = "https://github.com/phimage/PhiLipsStack"

# ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
s.license      = "MIT"

# ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
s.author             = { "phimage" => "eric.marchand.n7@gmail.com" }

# ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
s.ios.deployment_target = "8.0"
s.osx.deployment_target = "10.9"

# ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
s.source       = { :git => "https://github.com/phimage/PhiLipsStack.git", :tag => '1.0.0' }

# ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

s.source_files = "PhiLipsStack/*.swift"

# ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
s.resource  = "logo-128x128.png"

end