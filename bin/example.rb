#!/usr/bin/env ruby

require 'bundler/setup'
require 'vs_scorm'
require 'pry'
require 'fileutils'

p "Start importing"

VsScorm::Package.open(ARGV[0]) do |pkg|
  title = pkg.manifest.metadata.general.title
  p "Package name: #{title}"
  p "\# SCO's: #{pkg.manifest.resources.count { |x| x.scorm_type == "sco"}}"
  p "\# Assets: #{pkg.manifest.resources.count { |x| x.scorm_type == "asset"}}"

  p "Copying all resources to folder"
  dest_path = 'resources'
  FileUtils.mkdir_p(dest_path) 
  pkg.manifest.resources.each do |res|
    src = File.join(pkg.path, res.files[0])
    dest = File.join(dest_path, res.files[0])
    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp(src, dest)
  end

end
