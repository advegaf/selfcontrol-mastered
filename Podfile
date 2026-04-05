source 'https://github.com/CocoaPods/Specs.git'

minVersion = '26.0'

platform :osx, minVersion

# cocoapods-prune-localizations doesn't appear to auto-detect pods properly, so using a manual list
supported_locales = ['Base', 'da', 'de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'nl', 'pt-BR', 'sv', 'tr', 'zh-Hans']
plugin 'cocoapods-prune-localizations', { :localizations => supported_locales }

target "SelfControl" do
    use_frameworks! :linkage => :static
    pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8.0'
    pod 'LetsMove', '~> 1.24'
    
    # Add test target
    target 'SelfControlTests' do
        inherit! :complete
    end
end

target "SelfControl Killer" do
    use_frameworks! :linkage => :static
end

target "SCKillerHelper" do
end
target "selfcontrol-cli" do
end
target "org.eyebeam.selfcontrold" do
end

post_install do |pi|
   pi.pods_project.targets.each do |t|
       t.build_configurations.each do |bc|
           if Gem::Version.new(bc.build_settings['MACOSX_DEPLOYMENT_TARGET']) < Gem::Version.new(minVersion)
               bc.build_settings['MACOSX_DEPLOYMENT_TARGET'] = minVersion
           end
       end
   end

   # Fix "Multiple commands produce Sentry.bundle" by removing output file
   # declarations from CLI targets' resource copy phases
   cli_targets = ['SCKillerHelper', 'selfcontrol-cli', 'org.eyebeam.selfcontrold']
   main_project = pi.aggregate_targets.first.user_project
   main_project.targets.each do |t|
     next unless cli_targets.include?(t.name)
     t.build_phases.each do |phase|
       next unless phase.respond_to?(:name) && phase.name == '[CP] Copy Pods Resources'
       phase.output_paths&.reject! { |p| p.include?('Sentry.bundle') }
       phase.input_paths&.reject! { |p| p.include?('Sentry.bundle') }
     end
   end
   main_project.save

   # Fix "Multiple commands produce Sentry.bundle" for CLI tool targets
   # These targets don't need the resource bundle
   cli_targets = ['SCKillerHelper', 'selfcontrol-cli', 'org.eyebeam.selfcontrold']
   pi.aggregate_targets.each do |at|
     next unless cli_targets.include?(at.user_project.targets.find { |t| t.name == at.target_definition.name }&.name || at.target_definition.name)
     at.user_targets.each do |ut|
       ut.shell_script_build_phases.each do |phase|
         if phase.name == '[CP] Copy Pods Resources'
           phase.shell_script = phase.shell_script.gsub(/.*Sentry\.bundle.*\n/, '')
         end
       end
     end
   end
end
