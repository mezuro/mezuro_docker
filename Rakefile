require 'yaml'
require 'fileutils'
require 'erubis'
require 'pp'

require_relative 'commands'

class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        self.merge(second, &merger)
    end
end

class BuildConfig < Hash
	def self.load_recursive(path, base_config: nil, result: Hash.new)	
		if base_config == nil
			base_config = self.new
		end

		dir_config = base_config.deep_merge(self.load(path))
		result[path] = dir_config.clone

        subdirs = (dir_config['subdirs'] or [])
        dir_config['subdirs'] = nil
        dir_config['files'] = nil

        subdirs.each do |subdir|
        	self.load_recursive(File.join(path, subdir),
        		                base_config: dir_config, result: result)
        end

        return result
    end

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
                return self[Hash.new]
            end
        end

        return self[YAML::load_file(config_path)]
    end

    def cfg_key(key)
        begin
            key.split('.').inject(self) { |cfg, k| cfg[k] }
        rescue NoMethodError
            nil
        end
    end
end

class DockerPreprocessor
    def initialize(base_path)
    	@base_path = base_path
    	@configs = BuildConfig::load_recursive(".")
    end

    def process_config(config)
        Hash[context.collect { |k, v|
            if v.is_a?(Hash)
                v = OpenStruct.new(process_context(v))
            end

            [k, v]
        }]
    end

    class Context < OpenStruct
        include DockerCommands
    end

    def render(template_file, config)
        context_binding = nil

        render_sub = lambda { |f|
            erb = Erubis::Eruby.new(File.read(f))
            erb.result(context_binding)
        }

        import = lambda { |f|
            path = File.join(File.dirname(template_file), f)
            [
                "##### start: #{path} #####",
                render_sub.call(path),
                "##### end: #{path} #####"
            ].join("\n")
        }

        context = Context.new(process_config(config).merge({
            :import => import
        }))
        context_binding = context.instance_eval { binding }

        PP.pp(context_binding.eval("Apt"))

        render_sub.call(template_file)
    end

    def file_list(path=nil)
    	if path == nil
    		path = @base_path
    	end

    	config = @configs[path] || BuildConfig.new
    	files = (config['files'] || []).collect do |file|
    		source, dest = file.split(':')
    		dest = dest || source.chomp(".erb")

    		[source, dest].collect { |f| File.join(path, f) }
    	end

    	(config['subdirs'] || []).each do |subdir|
    		files += file_list(File.join(path, subdir))
    	end

    	return files
    end

    def process_file(source_file, dest_file)
    	dir = File.dirname(source_file)
    	config = @configs[dir] || Hash.new

    	File.write(dest_file, render(source_file, config))
    end
end

namespace :docker do
	desc 'Docker tasks'

	docker = DockerPreprocessor.new(".")
	
	task :preprocess do
		desc 'Generate Dockerfiles'
	
		docker.file_list.each do |file_spec|
			source, dest = file_spec

			puts source + " => " + dest
			docker.process_file(source, dest)
		end
    end

    task :clean do
        desc 'Clean generated artifacts'
        docker.file_list.each do |file_spec|
            source, dest = file_spec
            
            puts "Cleaning " + dest
            FileUtils.rm_f(dest)
        end
    end
end


