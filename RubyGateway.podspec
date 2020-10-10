Pod::Spec.new do |s|
  s.name         = "RubyGateway"
  s.version      = "3.2.1"
  s.authors      = { "John Fairhurst" => "johnfairh@gmail.com" }
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.homepage     = "https://github.com/johnfairh/RubyGateway"
  s.source       = { :git => "https://github.com/johnfairh/RubyGateway.git",
                     :tag => "v#{s.version.to_s}",
                     :submodules => true }
  s.summary      = "Embed Ruby in Swift: load Gems, run scripts, invoke APIs seamlessly in both directions."
  s.description = <<-EDESC
                    A Swift framework built on the Ruby C API that lets Swift
                    programs painlessly and safely run and interact with Ruby
                    programs.  Easily pass Swift datatypes into Ruby and turn
                    Ruby objects back into Swift types.

                    The framework lets you call any Ruby method from Swift,
                    including passing Swift closures as blocks. It lets you
                    define Ruby classes and methods that are implemented in
                    Swift.
                  EDESC
  s.documentation_url = "https://johnfairh.github.io/RubyGateway/"
  s.source_files  = 'Sources/RubyGateway/*swift', 'Sources/RubyGatewayHelpers/**/*.{h,m}'
  s.platform = :osx, '10.14'
  s.swift_version = "5"
  s.frameworks  = "Foundation"
  s.preserve_path = 'CRuby/*', 'RubyGatewayHelpers/*'
  s.pod_target_xcconfig = { 'SWIFT_INCLUDE_PATHS' => '"${PODS_ROOT}/RubyGateway/CRuby" "${PODS_ROOT}/RubyGateway/RubyGatewayHelpers"',
                            'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/RubyGateway/CRuby"' }
  s.prepare_command = <<-ECMD
                        mkdir RubyGatewayHelpers
                        echo 'module RubyGatewayHelpers [system] {}' > RubyGatewayHelpers/module.modulemap
                      ECMD
end
