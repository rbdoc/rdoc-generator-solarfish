require 'fileutils'
require 'yaml'
require 'sass'

require_relative 'settings'

class ThemeLoader
  def self.themes_dir
    File.join Settings::data_dir, 'themes'
  end

  def self.themes_list
    pattern = File.join themes_dir, '*.yml'

    Dir[pattern].sort.map do |path|
      File.basename path, '.yml'
    end
  end

  def self.theme_path(name)
    if name.include? '/'
      File.absolute_path name
    else
      File.join themes_dir, "#{name}.yml"
    end
  end

  def initialize(options)
    @options = options
  end

  def load
    theme = {
      head: {
        styles:  [],
        fonts:   [],
        scripts: [],
        html:    []
      },
      body: {}
    }

    @options.sf_themes.each do |theme_path|
      load_theme(theme, theme_path)
    end

    build_theme(theme)

    theme
  end

  private

  def load_theme(theme, theme_path)
    config = YAML.load_file theme_path

    config.each do |section, content|
      check_one_of(
        message:  'Unexpected section in theme config',
        expected: %w(head body),
        actual:   section
      )

      case section
      when 'head'
        content.each do |key, files|
          check_one_of(
            message:  "Unexpected key in 'head'",
            expected: %w(styles fonts scripts html),
            actual:   key
          )
          section = key.to_sym
          files.each do |file_info|
            path = theme_file(theme_path, file_info['file'])
            case section
            when :styles, :scripts, :fonts
              name = File.basename(path)
              file = {
                src_path: path,
                dst_name: name,
                url:      theme_url(name)
              }
            when :html
              file = {
                data: File.read(path)
              }
            end
            file[:family] = file_info['family'] if section == :fonts
            theme[:head][section] << file
          end
        end

      when 'body'
        content.each do |key, path|
          check_one_of(
            message:  "Unexpected key in 'body'",
            expected: %w(header footer),
            actual:   key
          )
          theme[:body][key.to_sym] = File.read(theme_file(theme_path, path))
        end
      end
    end
  rescue => error
    raise "Can't load theme - #{theme_path}\n#{error}"
  end

  def build_theme(theme)
    theme[:head][:styles].each do |file|
      build_css_from_sass(file) if File.extname(file[:src_path]) == '.sass'
    end
  end

  def build_css_from_sass(file)
    options = {
      cache:  false,
      syntax: :sass,
      style:  :default
    }

    input_data = File.read(file[:src_path])
    renderer = Sass::Engine.new(input_data, options)
    output_data = renderer.render

    file.delete(:src_path)
    file[:dst_name] = File.basename(file[:dst_name], '.*') + '.css'
    file[:url] = theme_url(file[:dst_name])
    file[:data] = output_data
  end

  def theme_file(theme_path, file_path)
    File.join(File.dirname(theme_path), file_path)
  end

  def theme_url(name)
    url = @options.sf_prefix || ''
    url += '/' if !url.empty? && !url.end_with?('/')
    url + name
  end

  def check_one_of(message: '', expected: [], actual: '')
    unless expected.include?(actual)
      raise %(#{message}: ) +
            %(got '#{actual}', ) +
            %(expected one of: #{expected.map { |e| "'#{e}'" }.join(', ')})
    end
  end
end
