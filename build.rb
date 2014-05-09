require 'yaml'
require 'fileutils'

require 'erb'
require 'ostruct'

require 'pp'

class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        self.merge(second, &merger)
    end
end

class ERBContextWrapper < OpenStruct
    def render(template)
        ERB.new(template).result(binding)
    end

    def get_binding
        binding
    end
end

## 

class Apt
    @@command_prefix='DEBIAN_FRONTEND=noninteractive'

    def self.update
        "RUN #{@@command_prefix} apt-get update"
    end

    def self.install(packages, options: nil, recommends: true, suggests: true)
        (
            ["RUN", @@command_prefix, 'apt-get install -y'] +
            (suggests ? [] : ['--no-install-suggests']) +
            (recommends ? [] : ['--no-install-recommends']) +
            Array(options) +
            Array(packages)
        ).join(" ") 
    end

    def self.reconfigure(package)
        "RUN #{@@command_prefix} dpkg-reconfigure #{package}"
    end
end

class BuildConfig < Hash
    def self.load(path)
        config_path = File.join(path, "config.yml")
        sample_path = File.join(path, "config.yml.sample")

        if ! File.file?(config_path) then
            if File.file?(sample_path) then
                puts "#{config_path} missing, copying from #{sample_path}"
                if ! FileUtils.cp(sample_path, config_path) then
                    raise "Unreadable config. sample '#{sample_path}'"
                end
            else
                return Hash.new
            end
        end

        return self[YAML::load_file(config_path)]
    end

    def cfg_key(key)
        begin
            key.split('.').inject(self) do |cfg, k|
                cfg[k]
            end
        rescue NoMethodError
            nil
        end
    end
end

class Processor
    @@default_subdirs = ['base', 'kalibro']

    def render(template_file, config)
        context = nil

        import = lambda { |f|
            path = File.join(File.dirname(template_file), f)
            context.render(File.read(path))
        }

        context = ERBContextWrapper.new({
            :c       => lambda { |key| config.cfg_key(key) },
            :Apt     => Apt,
            :import  => import
        })

        context.render(File.read(template_file))
    end

    def process_dir(dir, config: Hash.new, skip_dir_config: false)
        if ! skip_dir_config then
            dir_config = config.deep_merge(BuildConfig::load(dir))
        else
            dir_config = config
        end

        Dir.glob(File.join(dir, "Dockerfile.erb")) do |template_file|
            dest_file = template_file.chomp(".erb")

            puts "Processing: #{template_file} => #{dest_file}"

            File.write(dest_file, render(template_file, dir_config))
        end
    end

    def process_dir_subdirs(dir, subdirs)
        config = BuildConfig::load(dir)

        process_dir(dir, config: config, skip_dir_config: true)

        subdirs.each do |subdir|
            puts "Entering #{subdir}/"

            process_dir(File.join(dir, subdir), config: config)
        end
    end

    def self.main(subdirs: nil)
        self.new.process_dir_subdirs(".", (subdirs or @@default_subdirs))
    end
end

Processor::main(subdirs: ARGV)