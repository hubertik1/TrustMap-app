#!/usr/bin/env ruby

require 'fileutils'
require 'xcodeproj'
require 'pathname'

ROOT = Pathname.new(File.expand_path('..', __dir__))
PROJECT_PATH = ROOT.join('TrustMap.xcodeproj')
APP_NAME = 'TrustMap'

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
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.hubert.TrustMap'
  config.build_settings['PRODUCT_NAME'] = APP_NAME
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = APP_NAME
  config.build_settings['INFOPLIST_KEY_LSApplicationCategoryType'] = 'public.app-category.food-and-drink'
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = ''
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Resources/TrustMap.entitlements'
  config.build_settings['DEVELOPMENT_ASSET_PATHS'] = '"Resources/Preview Content"'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
  config.build_settings['INFOPLIST_KEY_UIStatusBarHidden'] = 'NO'
end

main_group = project.main_group

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
      when '.xcassets'
        target.resources_build_phase.add_file_reference(file_ref)
      end
    end
  end
end

%w[App Core Shared Features].each do |folder|
  group = main_group.find_subpath(folder, true)
  add_folder_references(group, ROOT.join(folder).to_s, target)
end

resources_group = main_group.find_subpath('Resources', true)
assets_ref = resources_group.new_file('Resources/Assets.xcassets')
target.resources_build_phase.add_file_reference(assets_ref)
resources_group.new_file('Resources/TrustMap.entitlements')

project.save
