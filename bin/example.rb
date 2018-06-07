#!/usr/bin/env ruby

require 'bundler/setup'
require 'vs_scorm'
require 'pry'
require 'fileutils'

p "Start importing"

VsScorm::Package.open(ARGV[0]) do |pkg|
  title = (pkg.manifest.metadata.general.title.is_a? String) ? pkg.manifest.metadata.general.title : pkg.manifest.metadata.general.title.string
  p "Package name: #{title}"
  p "\# SCO's: #{pkg.manifest.resources.count { |x| x.scorm_type == "sco"}}"
  p "\# Assets: #{pkg.manifest.resources.count { |x| x.scorm_type == "asset"}}"

  p "Copying all resources to folder"
  dest_path = 'resources'
  FileUtils.mkdir_p(dest_path) 
  pkg.manifest.resources.each do |res|
    res.files.each do |f|
      src = File.join(pkg.path, f)
      dest = File.join(dest_path, f)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(src, dest)
    end
  end

end
