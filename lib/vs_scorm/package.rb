require 'zip'
require 'fileutils'
require 'open-uri'
require 'vs_scorm/manifest'

module VsScorm
  class InvalidPackage < RuntimeError; end
  class InvalidManifest < InvalidPackage; end
  
  class Package
    attr_accessor :name       # Name of the package.
    attr_accessor :manifest   # An instance of +Scorm::Manifest+.
    attr_accessor :path       # Path to the extracted course.
    attr_accessor :repository # The directory to which the packages is extracted.
    attr_accessor :options    # The options hash supplied when opening the package.
    attr_accessor :package    # The file name of the package file.
    
    DEFAULT_LOAD_OPTIONS = { 
      :strict => true,
      :cleanup => true,
      :name => nil,
      :repository => nil
    }
    
    def self.set_default_load_options(options = {})
      DEFAULT_LOAD_OPTIONS.merge!(options)
    end
    
    def self.open(filename, options = {}, &block)
      Package.new(filename, options, &block)
    end
    
    # This method will load a SCORM package and extract its content to the 
    # directory specified by the +:repository+ option. The manifest file will be
    # parsed and made available through the +manifest+ instance variable. This
    # method should be called with an associated block as it yields the opened
    # package and then auto-magically closes it when the block has finished. It
    # will also do any necessary cleanup if an exception occur anywhere in the
    # block. The available options are:
    #
    #   :+strict+:     If +false+ the manifest will be parsed in a nicer way. Default: +true+.
    #   :+cleanup+:    If +false+ no cleanup will take place if an error occur. Default: +true+.
    #   :+name+:       The name to use when extracting the package to the 
    #                  repository. Default: will use the filename of the package 
    #                  (minus the .zip extension).
    #   :+repository+: Path to the course repository. Default: the same directory as the package.
    #
    def initialize(filename, options = {}, &block)
      @options = DEFAULT_LOAD_OPTIONS.merge(options)
      @package = filename
      
      # Check if package is a file.
      if File.file?(@package)
        i = nil
        begin
          # Decide on a name for the package.
          @name = [(@options[:name] || File.basename(@package, File.extname(@package))), i].flatten.join
      
          # Set the path for the extracted package.
          @repository = @options[:repository] || File.dirname(@package)
          @path = File.expand_path(File.join(@repository, @name))
        
          # First try is nil, subsequent tries sets and increments the value with 
          # one starting at zero.
          i = (i || 0) + 1

        # Make sure the generated path is unique.
        end while File.exists?(@path)
      else
        raise InvalidPackage, "The package must be a zip file!"
      end
      
      # Extract the package
      extract!
                                                        
      # Detect and read imsmanifest.xml
      if File.exists?(File.join(@path, 'imsmanifest.xml'))
        @manifest = Manifest.new(self, File.read(File.join(@path, 'imsmanifest.xml')))
      else
        raise InvalidPackage, "#{File.basename(@package)}: no imsmanifest.xml, maybe not SCORM compatible?"
      end
      
      # Yield to the caller.
      yield(self)
      
      # Make sure the package is closed when the caller has finished reading it.
      self.close
      self.cleanup if @options[:cleanup]

    # If an exception occur the package is auto-magically closed and any 
    # residual data deleted in a clean way.
    rescue Exception => e
      self.close
      self.cleanup if @options[:cleanup]
      raise e
    end
    
    # Closes the package.
    def close
      @zipfile.close if @zipfile
    end
    
    # Cleans up by deleting all extracted files. Called when an error occurs.
    def cleanup
      FileUtils.rmtree(@path) if @path && File.exists?(@path)
    end
    
    # Extracts the content of the package to the course repository.
    def extract!
      # Create the path to the course
      FileUtils.mkdir_p(@path)
      
      Zip::File::foreach(@package) do |entry|
        entry_path = File.join(@path, entry.name)
        entry_dir = File.dirname(entry_path)
        FileUtils.mkdir_p(entry_dir) unless File.exists?(entry_dir)
        entry.extract(entry_path)
      end
    end
    
    # Returns an array with the paths to all the files in the package.
    def files
      if File.directory?(@package)
        Dir.glob(File.join(File.join(File.expand_path(@package), '**'), '*')).reject {|f|
          File.directory?(f) }.map {|f| f.sub(/^#{File.expand_path(@package)}\/?/, '') }
      else
        entries = []
        Zip::File::foreach(@package) do |entry|
          entries << entry.name unless entry.name[-1..-1] == '/'
        end
        entries
      end
    end
  end
end
