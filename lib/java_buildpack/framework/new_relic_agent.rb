# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/framework'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch New Relic support.
    class NewRelicAgent < JavaBuildpack::Component::VersionedDependencyComponent

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        download_jar
        @droplet.copy_resources
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = @application.services.find_service(FILTER)['credentials']
        java_opts   = @droplet.java_opts
        configuration = {}

        apply_configuration(credentials, configuration)
        apply_user_configuration(credentials, configuration)
        write_java_opts(java_opts, configuration)

        java_opts.add_javaagent(@droplet.sandbox + jar_name)
                 .add_system_property('newrelic.home', @droplet.sandbox)
        
        java_opts.add_system_property('newrelic.enable.java.8', 'true') if @droplet.java_home.version[1] == '8'
        java_opts.add_system_property('newrelic.config.proxy_host', '$WEB_PROXY_HOST') if !proxy_host.nil? and !proxy_host.empty?
        java_opts.add_system_property('newrelic.config.proxy_user', '$WEB_PROXY_USER') if !proxy_user.nil? and !proxy_user.empty?
        java_opts.add_system_property('newrelic.config.proxy_password', '$WEB_PROXY_PASS') if !proxy_password.nil? and !proxy_password.empty?
        java_opts.add_system_property('newrelic.config.proxy_port', '$WEB_PROXY_PORT') if !proxy_port.nil?
        java_opts.add_system_property('newrelic.config.app_name', "'#{application_name}'")
        java_opts.add_system_property('newrelic.enable.java.8', 'true') if @droplet.java_home.java_8_or_later?
      end

      protected

      # (see JavaBuildpack::Component::VersionedDependencyComponent#supports?)
      def supports?
        @application.services.one_service? FILTER, [LICENSE_KEY, LICENSE_KEY_USER]
      end


      FILTER = /newrelic/.freeze
      PROXY_FILTER = /proxy/.freeze

      def application_name
        # @application.details['new_relic_application_name']
        ENV['new_relic_application_name']
      end

      LICENSE_KEY = 'licenseKey'.freeze

      LICENSE_KEY_USER = 'license_key'.freeze

      private_constant :PROXY_FILTER, :FILTER, :LICENSE_KEY, :LICENSE_KEY_USER

      def apply_configuration(credentials, configuration)
        configuration['log_file_name'] = 'STDOUT'
        configuration[LICENSE_KEY_USER] = credentials[LICENSE_KEY]
        configuration['app_name'] = @application.details['application_name']
      end

      def apply_user_configuration(credentials, configuration)
        credentials.each do |key, value|
          configuration[key] = value
        end
      end

      def write_java_opts(java_opts, configuration)
        configuration.each do |key, value|
          java_opts.add_system_property("newrelic.config.#{key}", value)
        end
      end

      def proxy_host
        @application.services.find_service(PROXY_FILTER)['credentials']['host']
      end

      def proxy_user
        @application.services.find_service(PROXY_FILTER)['credentials']['username']
      end

      def proxy_password
        @application.services.find_service(PROXY_FILTER)['credentials']['password']
      end

      def proxy_port
        @application.services.find_service(PROXY_FILTER)['credentials']['port']
      end

    end

  end
end