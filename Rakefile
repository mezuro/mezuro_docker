require "rake/clean"
require_relative "build"

task :default => [:generate, :build]

CLEAN.include("build/")

p = Processor.new

desc "Build Docker image"
task :build => :generate do
	p.build
end

desc "Build Docker configuration files"
task :generate => ["build/"]

file "build/" => ["build.rb", "base", "kalibro", "mezuro"] do
	directory "build/"
	p.generate
end
