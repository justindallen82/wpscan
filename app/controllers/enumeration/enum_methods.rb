module WPScan
  module Controller
    # Enumeration Methods
    class Enumeration < CMSScanner::Controller::Base
      # @param [ String ] type (plugins or themes)
      #
      # @return [ String ] The related enumration message depending on the parsed_options and type supplied
      def enum_message(type)
        return unless %w[plugins themes].include?(type)

        details = if parsed_options[:enumerate][:"vulnerable_#{type}"]
                    'Vulnerable'
                  elsif parsed_options[:enumerate][:"all_#{type}"]
                    'All'
                  else
                    'Most Popular'
                  end

        "Enumerating #{details} #{type.capitalize}"
      end

      # @param [ String ] type (plugins, themes etc)
      #
      # @return [ Hash ]
      def default_opts(type)
        mode = parsed_options[:"#{type}_detection"] || parsed_options[:detection_mode]

        {
          mode: mode,
          exclude_content: parsed_options[:exclude_content_based],
          show_progression: user_interaction?,
          version_detection: {
            mode: parsed_options[:"#{type}_version_detection"] || mode,
            confidence_threshold: parsed_options[:"#{type}_version_all"] ? 0 : 100
          }
        }
      end

      # @param [ Hash ] opts
      #
      # @return [ Boolean ] Wether or not to enumerate the plugins
      def enum_plugins?(opts)
        opts[:plugins] || opts[:all_plugins] || opts[:vulnerable_plugins]
      end

      def enum_plugins
        opts = default_opts('plugins').merge(
          list: plugins_list_from_opts(parsed_options),
          sort: true
        )

        output('@info', msg: enum_message('plugins')) if user_interaction?
        # Enumerate the plugins & find their versions to avoid doing that when #version
        # is called in the view
        plugins = target.plugins(opts)

        output('@info', msg: 'Checking Plugin Versions') if user_interaction? && !plugins.empty?

        plugins.each(&:version)

        plugins.select!(&:vulnerable?) if parsed_options[:enumerate][:vulnerable_plugins]

        output('plugins', plugins: plugins)
      end

      # @param [ Hash ] opts
      #
      # @return [ Array<String> ] The plugins list associated to the cli options
      def plugins_list_from_opts(opts)
        # List file provided by the user via the cli
        return opts[:plugins_list] if opts[:plugins_list]

        if opts[:enumerate][:all_plugins]
          DB::Plugins.all_slugs
        elsif opts[:enumerate][:plugins]
          DB::Plugins.popular_slugs
        else
          DB::Plugins.vulnerable_slugs
        end
      end

      # @param [ Hash ] opts
      #
      # @return [ Boolean ] Wether or not to enumerate the themes
      def enum_themes?(opts)
        opts[:themes] || opts[:all_themes] || opts[:vulnerable_themes]
      end

      def enum_themes
        opts = default_opts('themes').merge(
          list: themes_list_from_opts(parsed_options),
          sort: true
        )

        output('@info', msg: enum_message('themes')) if user_interaction?
        # Enumerate the themes & find their versions to avoid doing that when #version
        # is called in the view
        themes = target.themes(opts)

        output('@info', msg: 'Checking Theme Versions') if user_interaction? && !themes.empty?

        themes.each(&:version)

        themes.select!(&:vulnerable?) if parsed_options[:enumerate][:vulnerable_themes]

        output('themes', themes: themes)
      end

      # @param [ Hash ] opts
      #
      # @return [ Array<String> ] The themes list associated to the cli options
      def themes_list_from_opts(opts)
        # List file provided by the user via the cli
        return opts[:themes_list] if opts[:themes_list]

        if opts[:enumerate][:all_themes]
          DB::Themes.all_slugs
        elsif opts[:enumerate][:themes]
          DB::Themes.popular_slugs
        else
          DB::Themes.vulnerable_slugs
        end
      end

      def enum_timthumbs
        opts = default_opts('timthumbs').merge(list: parsed_options[:timthumbs_list])

        output('@info', msg: 'Enumerating Timthumbs') if user_interaction?
        output('timthumbs', timthumbs: target.timthumbs(opts))
      end

      def enum_config_backups
        opts = default_opts('config_backups').merge(list: parsed_options[:config_backups_list])

        output('@info', msg: 'Enumerating Config Backups') if user_interaction?
        output('config_backups', config_backups: target.config_backups(opts))
      end

      def enum_db_exports
        opts = default_opts('db_exports').merge(list: parsed_options[:db_exports_list])

        output('@info', msg: 'Enumerating DB Exports') if user_interaction?
        output('db_exports', db_exports: target.db_exports(opts))
      end

      def enum_medias
        opts = default_opts('medias').merge(range: parsed_options[:enumerate][:medias])

        if user_interaction?
          output('@info', msg: 'Enumerating Medias (Permalink setting must be set to "Plain" for those to be detected)')
        end

        output('medias', medias: target.medias(opts))
      end

      # @param [ Hash ] opts
      #
      # @return [ Boolean ] Wether or not to enumerate the users
      def enum_users?(opts)
        opts[:users] || (parsed_options[:passwords] && !parsed_options[:username] && !parsed_options[:usernames])
      end

      def enum_users
        opts = default_opts('users').merge(
          range: enum_users_range,
          list: parsed_options[:users_list]
        )

        output('@info', msg: 'Enumerating Users') if user_interaction?
        output('users', users: target.users(opts))
      end

      # @return [ Range ] The user ids range to enumerate
      # If the --enumerate is used, the default value is handled by the Option
      # However, when using --passwords alone, the default has to be set by the code below
      def enum_users_range
        parsed_options[:enumerate][:users] || cli_enum_choices[0].choices[:u].validate(nil)
      end
    end
  end
end
