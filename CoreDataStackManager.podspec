#
# Be sure to run `pod lib lint CoreDataStackManager.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CoreDataStackManager'
  s.version          = '0.7.0'
  s.summary          = 'A simple class that sets up and manages a Core Data stack.'
  s.description      = <<-DESC
A simple class that sets up and manages a Core Data stack. A publicly-exposed main queue NSManagedObjectContext uses a private queue NSManagedContext as its parent, and the private queue context is connected to the persistent store coordinator to save data. Also provides a convenience method for saving temporary contexts connected to our main queue context.
                       DESC

  s.homepage         = 'https://github.com/UberJason/CoreDataStackManager'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Jason Ji' => 'uberjason@gmail.com' }
  s.source           = { :git => 'https://github.com/UberJason/CoreDataStackManager.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/UberJason'

  s.ios.deployment_target = '9.0'
  s.watchos.deployment_target = '4.0'

  s.source_files = 'CoreDataStackManager/Classes/**/*'

end
