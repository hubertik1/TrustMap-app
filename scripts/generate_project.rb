#!/usr/bin/env ruby

require 'fileutils'
require 'xcodeproj'
require 'pathname'

ROOT = Pathname.new(File.expand_path('..', __dir__))
PROJECT_PATH = ROOT.join('TrustMap.xcodeproj')
APP_NAME = 'TrustMap'
CONFIGURATIONS = [
  {
    existing_name: 'Debug',
    name: 'Local',
    type: :debug
  },
  {
    existing_name: 'Release',
    name: 'Prod',
    type: :release
  }
].freeze

FileUtils.rm_rf(PROJECT_PATH) if PROJECT_PATH.exist?

project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2630'
project.root_object.attributes['LastUpgradeCheck'] = '2630'

target = project.new_target(:application, APP_NAME, :ios, '18.0')
project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][target.uuid] = {
  'ProvisioningStyle' => 'Automatic',
  'SystemCapabilities' => {
    'com.apple.SignInWithApple' => {
      'enabled' => 1
    }
  }
}

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
end

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.hubertik.TrustMap'
  config.build_settings['PRODUCT_NAME'] = APP_NAME
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Resources/TrustMap.entitlements'
  config.build_settings['DEVELOPMENT_ASSET_PATHS'] = '"Resources/Preview Content"'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
end

main_group = project.main_group
config_group = main_group.find_subpath('Config', true)

config_file_refs = {
  'Base' => config_group.new_file('Config/Base.xcconfig'),
  'Local' => config_group.new_file('Config/Local.xcconfig'),
  'LocalExample' => config_group.new_file('Config/Local.override.xcconfig.example'),
  'Prod' => config_group.new_file('Config/Prod.xcconfig')
}

def configure_build_configurations(owner, config_file_refs)
  CONFIGURATIONS.each do |entry|
    configuration = owner.build_configurations.find { |config| config.name == entry[:existing_name] || config.name == entry[:name] }
    configuration ||= owner.add_build_configuration(entry[:name], entry[:type])
    configuration.name = entry[:name]
    configuration.base_configuration_reference = config_file_refs.fetch(entry[:name])
  end

  owner.build_configurations
       .reject { |config| CONFIGURATIONS.any? { |entry| entry[:name] == config.name } }
       .each do |config|
    owner.build_configuration_list.build_configurations.delete(config)
  end
end

def add_folder_references(group, path, target)
  Dir.children(path).sort.each do |entry|
    next if entry.start_with?('.')

    full_path = File.join(path, entry)

    if File.directory?(full_path)
      child_group = group.find_subpath(entry, true)
      add_folder_references(child_group, full_path, target)
    else
      file_ref = group.new_file(full_path.sub("#{ROOT.to_s}/", ''))
      case File.extname(full_path)
      when '.swift'
        target.source_build_phase.add_file_reference(file_ref)
      when '.xcassets', '.storyboard'
        target.resources_build_phase.add_file_reference(file_ref)
      end
    end
  end
end

%w[App Core Shared Features].each do |folder|
  group = main_group.find_subpath(folder, true)
  add_folder_references(group, ROOT.join(folder).to_s, target)
end

%w[Resources].each do |folder|
  group = main_group.find_subpath(folder, true)
  add_folder_references(group, ROOT.join(folder).to_s, target)
end

configure_build_configurations(project, config_file_refs)
configure_build_configurations(target, config_file_refs)
project.root_object.build_configuration_list.default_configuration_name = 'Prod'

CONFIGURATIONS.each do |entry|
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(target, nil, launch_target: true)
  scheme.test_action.build_configuration = entry[:name]
  scheme.launch_action.build_configuration = entry[:name]
  scheme.profile_action.build_configuration = entry[:name]
  scheme.analyze_action.build_configuration = entry[:name]
  scheme.archive_action.build_configuration = entry[:name]
  scheme.save_as(PROJECT_PATH, entry[:name], true)
end

project.save
