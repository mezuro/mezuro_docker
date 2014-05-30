require 'yaml'
require 'fileutils'
require 'ostruct'
require 'erb'

require 'pp'

require_relative 'docker_commands'

class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

module BuildConfig
  class << self
    CONFIG_FILENAME = "config.yml"
    SAMPLE_FILENAME = "config.yml.sample"

    def config_path(path)
      File.join(path, CONFIG_FILENAME)
    end

    def sample_path(path)
      File.join(path, SAMPLE_FILENAME)
    end

    def load(path)
      cfg_path = config_path(path)
      if File.exists?(cfg_path)
        YAML.load(File.read(cfg_path))
      else
        Hash.new
      end
    end

    def traverse(path, base_config: nil, pre_action: nil, &action)
      if pre_action != nil
        pre_action.call(path)
      end

      base_config ||= Hash.new
      config = base_config.deep_merge(self.load(path))

      action.call(path, config)

      subdirs = config['subdirs'] || []

      subdirs.each do |subdir|
        self.traverse(File.join(path, subdir), config, pre_action, action)
      end
    end

    def copy_sample(path)
      puts "initializing '#{path}"

      config_path = File.join(path, CONFIG_FILENAME)
      sample_path = File.join(path, SAMPLE_FILENAME)

      if File.exists?(sample_path) && ! File.exists?(config_path)
        puts "cp '#{sample_path}' '#{config_path}'"
        FileUtils.cp(sample_path, config_path)
      end
    end

    def init_files(path)
      self.traverse(path, pre_action: method(:copy_sample)) do |subpath, config|
        # pass
      end
    end
  end
end

class TemplateSupport
  attr_reader :path, :config, :context_binding

  def initialize(path, config=nil)
    @path = path
    @config = config || BuildConfig::load(path)

    context = Context.new(@config, context_locals)
    @context_binding = context.get_binding
  end

  def process_file(source_file, dest_file)
    puts "'#{source_file}' => '#{dest_file}'"
    File.write(dest_file, template_render(source_file))
  end

  def process_all_files
    files = @config['files'] || []
    files.each do |file|
      source, dest = file.split(':').collect { |f| File.join(@path, f) }
      dest ||= source.chomp('.erb')

      process_file(source, dest)
    end
  end

  def process_dir(sub_path)
    path = File.join(@path, sub_path)
    config = @config.clone
    config.delete('subdirs')
    config.delete('files')
    
    self.class.new(path, config.deep_merge(BuildConfig::load(path)))
  end

  def process_all_subdirs
    subdirs = @config['subdirs'] || []
    subdirs.each do |subdir|
      recurse(subdir)
    end
  end

  def template_render(file)
    ERB.new(File.read(file)).result(@context_binding)
  end

  class Context < OpenStruct
    include DockerCommands

    def initialize(config, locals=Hash.new)
      super(locals)

      prepare_config_struct(config).each do |k, v|
        instance_variable_set("@#{k}", v)
      end

    end

    def get_binding
      b = binding()
    end
  
    def prepare_config_struct(config)
      Hash[
        config.collect { |k, v|
          if v.is_a?(Hash)
            v = OpenStruct.new(prepare_config_struct(v))
          end

          [k, v]
        }
      ]
    end

    private :prepare_config_struct
  end

  def context_locals
    {
      :import => lambda { |f| template_include(f) }
    }
  end

  def template_include(file)
    puts "  => #{file}"

    path = File.join(@path, file)
    [
      "##### start: #{path} #####",
      template_render(path),
      "##### end: #{path} #####"
    ].join("\n")
  end

  private :context_locals, :template_include
end

def reload
  load 'test.rb'
end