require 'fastlane/action'
require_relative '../helper/android_emulator_helper'

module Fastlane
  module Actions
    module SharedValues
      ANDROID_SDK_DIR = :ANDROID_SDK_DIR
    end

    class AndroidEmulatorAction < Action
      def self.run(params)
        sdk_dir = params[:sdk_dir]
        adb = "#{sdk_dir}/platform-tools/adb"

        UI.message("Stopping emulator")
        system("#{adb} emu kill > /dev/null 2>&1 &")
        sleep(2)

        UI.message("Creating new emulator")
        FastlaneCore::CommandExecutor.execute(
          command: "#{sdk_dir}/tools/bin/avdmanager create avd -n '#{params[:name]}' -f -k '#{params[:package]}' -d '#{params[:device]}'",
          print_all: true,
          print_command: false
        )

        if params[:avd_configuration]
          UI.message("Override configuration")
          config_file = "#{Dir.home}/.android/avd/#{params[:name]}.avd/config.ini"
          config = {}
          File.readlines(config_file).each do |entry|
            key_and_value = entry.strip.split("=")
            config[key_and_value.first] = key_and_value.last
          end

          config.merge!(params[:avd_configuration])
          File.open(config_file, 'w') do |file|
            config.each_pair do |k,v|
              file.write("#{k}=#{v}\n")
            end
            file.flush
            file.close
          end
        end

        # Verify HAXM installed on mac
        if FastlaneCore::Helper.mac?
          kextstat = Actions.sh("kextstat", log: false)

          UI.user_error! "Please install the HAXM-Extension" unless kextstat.include?("intel")
        end

        UI.message("Starting emulator")
        system("LC_NUMERIC=C; #{sdk_dir}/emulator/emulator @#{params[:name]} > /dev/null 2>&1 &")
        sh("#{adb} -e wait-for-device")
        until Actions.sh("#{adb} -e shell getprop dev.bootcomplete", log: false).strip == "1" do
          sleep(5)
        end

        if params[:location]
          UI.message("Set location")
          sh("LC_NUMERIC=C; #{adb} emu geo fix #{params[:location]}")
        end

        if params[:demo_mode]
          UI.message("Set in demo mode")
          sh("#{adb} -e shell settings put global sysui_demo_allowed 1")
          sh("#{adb} -e shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0700")
        end
      end

      def self.description
        "Creates and starts an Android Emulator (AVD)"
      end

      def self.details
        "Great for Screengrab"
      end

      def self.example_code
        [
          'android_emulator(
            device: "Nexus 5",
            location: "9.1808 48.7771",
            package: "system-images;android-24;google_apis;x86_64",
            demo_mode: true,
            sdk_dir: "PATH_TO_SDK",
            avd_configuration: {
              "hw.gpu.mode" => "auto",
              "hw.gpu.enabled" => "yes",
              "skin.dynamic" => "yes",
              "skin.name" => "nexus_9",
              "skin.path" => "/Users/#{`whoami`.strip}/Library/Android/sdk/skins/nexus_9"
            }
          )'
        ]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :sdk_dir,
                                       env_name: "ANDROID_SDK_DIR",
                                       description: "Path to the Android SDK DIR",
                                       default_value: Actions.lane_context[SharedValues::ANDROID_SDK_DIR],
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("No ANDROID_SDK_DIR given, pass using `sdk_dir: 'sdk_dir'`") unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :package,
                                      env_name: "AVD_PACKAGE",
                                      description: "The selected system image of the emulator",
                                      optional: false),
          FastlaneCore::ConfigItem.new(key: :name,
                                       env_name: "AVD_NAME",
                                       description: "Name of the AVD",
                                       default_value: "fastlane",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :device,
                                       env_name: "AVD_DEVICE",
                                       description: "Device",
                                       default_value: "Nexus 5",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :location,
                                       env_name: "AVD_LOCATION",
                                       description: "Set location of the the emulator '<longitude> <latitude>'",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :demo_mode,
                                       env_name: "AVD_DEMO_MODE",
                                       description: "Set the emulator in demo mode",
                                       is_string: false,
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :avd_configuration,
                                       env_name: "AVD_CONFIGURATION",
                                       description: "AVD Configuration",
                                       is_string: false,
                                       optional: true)
        ]
      end

      def self.authors
        ["Michael Ruhl"]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
