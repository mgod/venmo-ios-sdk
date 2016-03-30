Pod::Spec.new do |s|
  s.name          = 'Venmo-iOS-SDK'
  s.version       = '1.3.0'
  s.summary       = 'Official Venmo iOS SDK'
  s.description   = <<-DESC
                     Send payments & charges to any email, phone number or Venmo username from within your iOS app.
                     DESC
  s.screenshot    = 'http://i.imgur.com/tN7mYVy.gif'
  s.homepage      = 'https://github.com/venmo/venmo-ios-sdk'
  s.license       = { :type => 'MIT', :file => 'LICENSE' }
  s.author        = { "Venmo" => "developers@venmo.com" }
  s.social_media_url = 'https://twitter.com/venmo'
  s.platform      = :ios, '7.1'
  s.requires_arc  = true
  s.source        =  { :git => "https://github.com/venmo/venmo-ios-sdk.git", :tag => "v#{s.version}" }
  s.source_files  = 'venmo-sdk/**/*.{h,m}'
  s.dependency 'VENCore', '~> 3.1.3'
  s.dependency 'SSKeychain', '~> 1.2.3'
  s.dependency 'CMDQueryStringSerialization', '~> 0.4'
end
