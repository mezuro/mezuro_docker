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

class CommandBase
    attr_reader :processor, :config, :current_template

    def initialize(processor, config, current_template=nil)
        @processor = processor
        @config = config
        @current_template = current_template
    end
end

class Apt < CommandBase
    @@command_prefix='DEBIAN_FRONTEND=noninteractive'

    def update
        "RUN bash -c 'set -o pipefail; #{@@command_prefix} apt-get update | tee /dev/stdout | (! grep -q ^Err)'"
    end

    def install(packages, options: nil, recommends: true, suggests: true)
        (
            ["RUN", @@command_prefix, 'apt-get install -y'] +
            (suggests ? [] : ['--no-install-suggests']) +
            (recommends ? [] : ['--no-install-recommends']) +
            Array(options) +
            Array(packages)
        ).join(" ") 
    end

    def reconfigure(package)
        "RUN #{@@command_prefix} dpkg-reconfigure #{package}"
    end
end

class Git < CommandBase
    def import_or_clone(path, repo, revision=nil)
        result = "RUN bash -c \"[ -d '#{path}' ] || git clone '#{repo}' '#{path}'\""
        if revision != nil
            result += "\n"
            result += "RUN bash -c \"cd '#{path}' && git fetch && git checkout '#{revision}'\""
        end

        result
    end
end

class DockerUtil < CommandBase
    def ports
        (config.cfg_key('ports') || []).map { |port|
            "EXPOSE #{port}"
        }.join("\n")
    end

    def copy_tmpl(fname, dest)
        processor.write_template(File.join(File.dirname(current_template), fname),
                                 config)
        fname = fname.chomp('.erb')
        "COPY #{fname} #{dest}"
    end

end

class MiscUtil < CommandBase
    def yaml_string(s)
        s.to_yaml.sub(/^---\s+/, '').sub(/\.{3}\s+$/, '').chomp
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
    @@ignore_patterns = ['*.erb', 'config.yml'] 
    @@process_patterns = ['Dockerfile.erb']

    attr_reader :base_dir, :build_dir, :config

    def initialize(base_dir, build_dir)
        @base_dir = base_dir
        @build_dir = build_dir

        @config = BuildConfig::load(@base_dir)
    end

    def subdirs
        @config['subdirs'] || []
    end

    def render_template(fname, config)
        config = config.clone

        context = nil

        import = lambda { |f|
            import_fname = File.join(File.dirname(fname), f)
            puts "** import #{import_fname}"
 
            path = File.join(@base_dir, import_fname)
            (
                "##### start: #{path} #####\n" +
                context.render(File.read(path)) + "\n" +
                "##### end: #{path} #####\n"
            )
        }

        context = ERBContextWrapper.new({
            :c        => lambda { |key| config.cfg_key(key) },
            :apt      => Apt.new(self, config, fname),
            :git      => Git.new(self, config, fname),
            :misc     => MiscUtil.new(self, config, fname),
            :docker   => DockerUtil.new(self, config, fname),
            :import   => import
        })

        context.render(File.read(File.join(@base_dir, fname)))
    end

    def write_template(fname, config)
        result_fname = fname.chomp('.erb')
        puts "* process #{fname} => #{result_fname}"

        File.write(File.join(@build_dir, result_fname),
                   render_template(fname, config))
    end

    def ignored?(f)
        @@ignore_patterns.any? do |pattern|
            File.fnmatch?(pattern, f)
        end
    end

    def should_process?(f)
        @@process_patterns.any? do |pattern|
            File.fnmatch?(pattern, f)
        end
    end

    def do_process_dir(dir, config=nil)
        config ||= @config

        input_dir = File.join(@base_dir, dir)
        stage_dir = File.join(@build_dir, dir)
        puts "Staging #{input_dir} into #{stage_dir}"

        FileUtils.rm_r(stage_dir, force: true, secure: true)
        FileUtils.mkdir_p(stage_dir)

        dir_config = config.deep_merge(BuildConfig::load(input_dir))

        Dir.foreach(input_dir) do |f|
            next if f == '.' or f == '..'

            fname = File.join(dir, f)

            if ! should_process?(f)
                next if ignored?(f)

                puts "* cp #{fname}"
                FileUtils.cp_r(File.join(@base_dir, fname),
                               File.join(@build_dir, fname))
            else
                write_template(fname, dir_config)
            end
        end
    end

    def self.docker_command
        username = Etc.getlogin
        has_docker_group = Etc.getgrnam('docker').mem.include?(username)

        if has_docker_group
            'docker'
        else
            'sudo docker'
        end
    end

    def do_build_dir(dir)
        build_opts = config.cfg_key('build.options')

        dir_path = File.join(@build_dir, dir)
        if not File.file?(File.join(dir_path, 'Dockerfile'))
            puts "Error: No Dockerfile in '#{dir_path}'"
            return false
        end

        tag = config.cfg_key('docker.repository') + '/' + dir
        command = "#{self.class.docker_command} build --tag='#{tag}' #{build_opts} '#{dir_path}'"

        puts command
        system(command)
    end

    def check_subdirs(base_dir)
        subdirs = @config['subdirs'] || []

        if subdirs.empty?
            puts "Error: No subdirs in config.yml, nothing to do."
            return false
        end

        subdirs.each do |dir|
            subdir_path = File.join(base_dir, dir)
            if ! File.directory?(subdir_path)
                puts "Error: '#{subdir_path}' is not a directory or is not accesible."
                return false
            end
        end

        true
    end

    def self.generate(base_dir='.', build_dir='./build')
        FileUtils.mkdir_p(build_dir)

        p = self.new(base_dir, build_dir)
        p.check_subdirs(base_dir) || exit(1)

        p.subdirs.each do |dir|
            p.do_process_dir(dir)
        end
    end


    def self.build(base_dir='.', build_dir='./build')
        if ! File.directory?(build_dir)
            puts "Error: build directory does not exist. Did you run generate first?"
            exit 1
        end

        p = self.new(base_dir, build_dir)
        p.check_subdirs(build_dir) || exit(1)

        p.subdirs.each do |dir|
            if ! p.do_build_dir(dir)
                puts "Error: failed to build #{dir}"
                exit 1
            end
        end
    end
end

task = ARGV[0]

if task == 'generate'
    Processor.generate(*ARGV[1..-1])
elsif task == 'build'
    Processor.build(*ARGV[1..-1])
end
