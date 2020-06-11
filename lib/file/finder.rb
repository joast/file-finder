require 'date'
require 'sys/admin'

begin
  require 'win32/file'
rescue LoadError
  # Do nothing, not required, just nicer.
end

class File::Finder
  # The version of the file-finder library
  VERSION = '0.5.0'.freeze

  # :stopdoc:
  VALID_OPTIONS = %w[
    atime
    ctime
    fnm_flags
    follow
    ftype
    full_path
    group
    inum
    links
    maxdepth
    mindepth
    mount
    mtime
    name
    path
    pattern
    perm
    prune
    prune_path
    rtn_stat_info
    rtn_symlinks
    size
    user
  ]
  # :startdoc:

  # The starting path(s) for the search. The default is the current directory.
  # This can be a single path or an array of paths.
  #
  attr_accessor :path

  # The list of options passed to the constructor and/or used by the
  # File::Finder#find method.
  #
  attr_accessor :options

  # Limits searches by file access time, where the value you supply is the
  # number of days back from the time that the File::Finder#find method was
  # called.
  #
  attr_accessor :atime

  # Limits searches by file change time, where the value you supply is the
  # number of days back from the time that the File::Finder#find method was
  # called.
  #
  attr_accessor :ctime

  # Limits searches to files that belong to a specific group, where the
  # group can be either a group name or ID.
  #
  attr_accessor :group

  # An array of two element arrays for storing FileTest methods and their
  # boolean value.
  #
  attr_accessor :filetest

  # Flags to pass to File.fnmatch.
  #
  attr_accessor :fnm_flags

  # Controls the behavior of how symlinks are followed. If set to true (the
  # default), then follows the file pointed to. If false, it considers the
  # symlink itself.
  #
  attr_accessor :follow

  # Limits searches to specific types of files. The possible values here are
  # those returned by the File.ftype method.
  #
  attr_accessor :ftype

  # If :path isn't set and :full_path is true, then default to using the full
  # path of the current directory instead of '.'.
  #
  attr_accessor :full_path

  # Limits search to a file with a specific inode number.
  #
  attr_accessor :inum

  # Limits search to files with the specified number of links.
  #
  attr_accessor :links

  # Limits search to a maximum depth into the tree relative to the starting
  # search directory.
  #
  attr_accessor :maxdepth

  # Limits searches to a minimum depth into the tree relative to the starting
  # search directory.
  #
  attr_accessor :mindepth

  # Limits searches to the same filesystem as the specified directory. For
  # Windows users, this refers to the volume.
  #
  attr_reader :mount

  # Limits searches by file modification time, where the value you supply is
  # the number of days back from the time that the File::Finder#find method was
  # called.
  #
  attr_accessor :mtime

  # The name pattern used to limit file searches. The patterns that are legal
  # for File.fnmatch are legal here. The default is '*', i.e. everything except
  # things whose name begins with a '.'.
  #
  attr_accessor :name

  # Limits searches to files which have permissions that match the octal
  # value that you provide. For purposes of this comparison, only the user,
  # group, and world settings are used.
  #
  # You may optionally use symbolic permissions, e.g. "g+rw", "u=rwx", etc.
  #
  # MS Windows only recognizes two modes, 0644 and 0444.
  #
  attr_accessor :perm

  # Skips files or directories that match the string provided as an argument.
  #
  attr_accessor :prune

  # Skips files or directories whose path matches the string provided as an
  # argument. This uses the whole path to the object being examined instead
  # of just the name of the object like :prune. For example: if :path is
  # 'testing' and the current object being examined has a name of 't0001',
  # then :prune would be matched against 't0001' and :prune_path would be
  # matched against 'testing/t0001'.
  #
  attr_accessor :prune_path

  # Return File::Stat in addition to the path if the find method is called
  # without a block.
  #
  attr_accessor :rtn_stat_info

  # Returns symlink info in addition to symlink target info if :follow is true.
  # The default is nil/false. This option only matters if :rtn_stat_info is
  # true and the find() method is called without a block or the find() method
  # is called with a block that receives two parameters.
  #
  attr_accessor :rtn_symlinks

  # If the value passed is an integer, this option limits searches to files
  # that match the size, in bytes, exactly. If a string is passed, you can
  # use the standard comparable operators to match files, e.g. ">= 200" would
  # limit searches to files greater than or equal to 200 bytes.
  #
  attr_accessor :size

  # Limits searches to files that belong to a specific user, where the user
  # can be either a user name or an ID.
  #
  attr_accessor :user

  # The file that matched previously in the current search.
  #
  attr_reader :previous

  alias pattern name
  alias pattern= name=

  # Creates and returns a new File::Finder object. The options set for this
  # object serve as the rules for determining what files the File::Finder#find
  # method will search for.
  #
  # In addition to the standard list of valid options, you may also use
  # FileTest methods as options, setting their value to true or false.
  #
  # Example:
  #
  #    rule = File::Finder.new(
  #       :name      => "*.rb",
  #       :follow    => false,
  #       :path      => ['/usr/local/lib', '/opt/local/lib'],
  #       :readable? => true
  #    )
  #
  def initialize(options = {})
    @options       = options

    @atime         = nil
    @ctime         = nil
    @fnm_flags     = 0
    @follow        = true
    @ftype         = nil
    @full_path     = nil
    @group         = nil
    @inum          = nil
    @links         = nil
    @mount         = nil
    @mtime         = nil
    @perm          = nil
    @prune         = nil
    @prune_path    = nil
    @rtn_stat_info = nil
    @rtn_symlinks  = nil
    @size          = nil
    @user          = nil

    @previous      = nil
    @maxdepth      = nil
    @mindepth      = nil
    @filetest      = []

    validate_and_set_options(options) unless options.empty?

    @filesystem = File.stat(@mount).dev if @mount

    @path ||= (@full_path ? Dir.pwd : '.')
    @name ||= '*'

    if @group.is_a?(String)
      begin
        if File::ALT_SEPARATOR
          @gid = Sys::Admin.get_group(@group, :LocalAccount => true).gid
        else
          @gid = Sys::Admin.get_group(@group).gid
        end
      rescue Sys::Admin::Error
        raise ArgumentError, "unknown group: '#{@group}'"
      end
    elsif @group.is_a?(Integer)
      @gid = @group
    elsif @group.nil?
      @gid = nil
    else
      raise ArgumentError, "invalid group: '#{@group}'"
    end

    if @user.is_a?(String)
      begin
        if File::ALT_SEPARATOR
          @uid = Sys::Admin.get_user(@user, :LocalAccount => true).sid
        else
          @uid = Sys::Admin.get_user(@user).uid
        end
      rescue Sys::Admin::Error
        raise ArgumentError, "unknown user: '#{@user}'"
      end
    elsif @user.is_a?(Integer)
      @uid = @user
    elsif @user.nil?
      @uid = nil
    else
      raise ArgumentError, "invalid user: '#{@user}'"
    end

    if @perm
      if @perm.is_a?(Integer)
        @num_perm = @perm
      elsif @perm.is_a?(String)
        @num_perm = sym2oct(@perm)
      else
        raise ArgumentError, "invalid type for option 'perm': #{@perm.class}"
      end

      # TODO: is this correct for Windows?
      @num_perm &= 0644 if File::ALT_SEPARATOR
    else
      @num_perm = nil
    end
  end

  # Executes the find based on the rules you set for the File::Finder object.
  # In block form, yields each file in turn that matches the specified rules.
  # In non-block form it will return an array of matches instead.
  #
  # If :rtn_stat_info is true, then each element of the result will be an array
  # with two elements. The first will be a path and the second will be a
  # File::Stat object for the path.
  #
  # Example:
  #
  #   rule = File::Finder.new(
  #      :name    => "*.rb",
  #      :follow  => false,
  #      :path    => ['/usr/local/lib', '/opt/local/lib']
  #   )
  #
  #   rule.find{ |f| puts f }
  #
  #   rule.find do |f, s|
  #     printf("%10d %s\n", s.size, f)
  #   end
  #
  def find(&block) # :yield: [ path [, stat_info ] ]
    if block_given?
      if block.arity < 0 || block.arity > 2
        raise ArgumentError, "expecting 0-2 parameters have #{block.arity}",
        caller
      end

      num_parms = block.arity
    else
      num_parms = 0
      results = []
    end

    paths = @path.is_a?(String) ? [@path] : @path # Ruby 1.9.x compatibility

    prune_regex = @prune ? Regexp.new(@prune) : nil
    prune_path_regex = @prune_path ? Regexp.new(@prune_path) : nil

    date1 = Date.today

    paths.each do |path|
      begin
        Dir.foreach(path) do |file|
          next if file == '.' || file == '..'

          if prune_regex
            next if prune_regex.match(file)
          end

          file_without_path = file.dup
          file = File.join(path, file)

          if prune_path_regex
            next if prune_path_regex.match(file)
          end

          lstat_info = nil

          if @follow
            if @rtn_symlinks
              # Skip files we cannot access, stale links, etc.
              begin
                lstat_info = File.lstat(file)
              rescue Errno::ENOENT, Errno::EACCES
                next
              end

              if lstat_info.symlink?
                begin
                  stat_info = File.stat(file)
                rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
                  stat_info = lstat_info
                  lstat_info = nil
                end
              else
                stat_info = lstat_info
                lstat_info = nil
              end
            else
              stat_method = :stat

              # Skip files we cannot access, stale links, etc.
              begin
                stat_info = File.send(stat_method, file)
              rescue Errno::ENOENT, Errno::EACCES
                next
              rescue Errno::ELOOP
                if stat_method == :stat
                  stat_method = :lstat # Handle recursive symlinks
                  retry
                end
              end
            end
          else
            begin
              stat_info = File.send(:lstat, file)
            rescue Errno::ENOENT, Errno::EACCES
              next
            end
          end

          # always use forward slashes to make things easier for script writers
          if File::ALT_SEPARATOR
            file.tr!(File::ALT_SEPARATOR, File::SEPARATOR)
          end

          if @mount
            next unless stat_info.dev == @filesystem
          end

          if @links
            next unless stat_info.nlink == @links
          end

          if @maxdepth || @mindepth
            file_depth = file.count(File::SEPARATOR) + 1
            current_base_path = [@path].flatten.find{ |tpath| file.include?(tpath) }
            path_depth = current_base_path.count(File::SEPARATOR) + 1

            depth = file_depth - path_depth

            if @maxdepth && (depth > @maxdepth)
              if stat_info.directory?
                unless paths.include?(file) && depth > @maxdepth
                  paths << file
                end
              end

              next
            end

            if @mindepth && (depth < @mindepth)
              if stat_info.directory?
                unless paths.include?(file) && depth < @mindepth
                  paths << file
                end
              end

              next
            end
          end

          # Add directories back onto the list of paths to search unless
          # they've already been added
          #
          if stat_info.directory?
            paths << file unless paths.include?(file)
          end

          next if !File.fnmatch?(@name, file_without_path, @fnm_flags)

          unless @filetest.empty?
            file_test = true

            @filetest.each do |array|
              meth = array[0]
              bool = array[1]

              unless File.send(meth, file) == bool
                file_test = false
                break
              end
            end

            next unless file_test
          end

          if @atime
            date2 = Date.parse(stat_info.atime.to_s)
            next unless (date1 - date2).numerator == @atime
          end

          if @ctime
            date2 = Date.parse(stat_info.ctime.to_s)
            next unless (date1 - date2).numerator == @ctime
          end

          if @mtime
            date2 = Date.parse(stat_info.mtime.to_s)
            next unless (date1 - date2).numerator == @mtime
          end

          if @ftype
            next unless stat_info.ftype == @ftype
          end

          if @uid
            next unless stat_info.uid == @uid
          end

          if @gid
            next unless stat_info.gid == @gid
          end

          if @inum
            next unless stat_info.ino == @inum
          end

          # Note that only 0644 and 0444 are supported on MS Windows.
          if @num_perm
            next unless (stat_info.mode & @num_perm) == @num_perm
          end

          # Allow plain numbers, or strings for comparison operators.
          if @size
            if @size.is_a?(String)
              regex = /^([><=]+)\s*?(\d+)$/
              match = regex.match(@size)

              if match.nil? || match.captures.include?(nil)
                raise ArgumentError, "invalid size string: '#{@size}'"
              end

              operator = match.captures.first.strip
              number   = match.captures.last.strip.to_i

              next unless stat_info.size.send(operator, number)
            else
              next unless stat_info.size == @size
            end
          end

          if block_given?
            case num_parms

            when 0
              yield

            when 1
              yield file.dup

            when 2
              yield file.dup, lstat_info if lstat_info
              yield file.dup, stat_info

            else
              # shouldn't happen, but prepare for the worst (i.e. programmer
              # error)
              raise ScriptError,
                    "don't know how to handle #{block.arity} parameters",
                    caller
            end
          elsif @rtn_stat_info
            results << [ file, lstat_info ] if lstat_info
            results << [ file, stat_info ]
          else
            results << file
          end

          @previous = file unless @previous == file
        end
      rescue Errno::EACCES
        next # Skip inaccessible directories
      end
    end

    block_given? ? nil : results
  end

  # Limits searches to the same file system as the specified +mount_point+.
  #
  def mount=(mount_point)
    @mount = mount_point
    @filesystem = File.stat(mount_point).dev
  end

  private

  # This validates that the keys are valid. If they are, it sets the value
  # of that key's corresponding method to the given value. If a key ends
  # with a '?', it's validated as a File method.
  #
  def validate_and_set_options(options)
    options.each do |key, value|
      key = key.to_s.downcase

      if key[-1].chr == '?'
        sym = key.to_sym

        unless File.respond_to?(sym)
          raise ArgumentError, "invalid option '#{key}'"
        end

        @filetest << [sym, value]
      else
        unless VALID_OPTIONS.include?(key)
          raise ArgumentError, "invalid option '#{key}'"
        end

        send("#{key}=", value)
      end
    end
  end

  # Converts a symoblic permissions mode into its octal equivalent.
  #--
  # Taken almost entirely from ruby-talk: 96956 (Hal Fulton).
  #
  def sym2oct(str)
    left  = {'u' => 0700, 'g' => 0070, 'o' => 0007, 'a' => 0777}
    right = {'r' => 0444, 'w' => 0222, 'x' => 0111}
    regex = /([ugoa]+)([+-=])([rwx]+)/

    cmds = str.split(',')

    perm = 0

    cmds.each do |cmd|
      match = cmd.match(regex)

      if match.nil?
        raise ArgumentError, "Invalid symbolic permissions: '#{str}'"
      end

      who, what, how = match.to_a[1..-1]

      who  = who.split(//).inject(0){ |num,b| num |= left[b]; num }
      how  = how.split(//).inject(0){ |num,b| num |= right[b]; num }
      mask = who & how

      case what
        when '+'
          perm = perm | mask
        when '-'
          perm = perm & ~mask
        when '='
          perm = mask
      end
    end

    perm
  end
end
