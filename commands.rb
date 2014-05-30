module DockerCommands
	module Apt
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

	module Git
	    def self.import_or_clone(path, repo)
	        "RUN bash -c \"[ -d '#{path}' ] || git clone '#{repo}' '#{path}'\""
	    end
	end
end