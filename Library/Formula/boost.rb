require 'formula'

class BoostLog < Formula
  url 'http://sourceforge.net/projects/boost-log/files/boost-log-1.1.zip'
  homepage 'http://http://boost-log.sourceforge.net/'
  md5 'd42fc71d0ead0d413b997c0e678722ca'

  head 'https://boost-log.svn.sourceforge.net/svnroot/boost-log', :using => :svn
end

def needs_universal_python?
  build.universal? and not build.include? "without-python"
end

class UniversalPython < Requirement
  def message; <<-EOS.undent
    A universal build was requested, but Python is not a universal build

    Boost compiles against the Python it finds in the path; if this Python
    is not a universal build then linking will likely fail.
    EOS
  end
  def satisfied?
    archs_for_command("python").universal?
  end
end

class Boost < Formula
  homepage 'http://www.boost.org'
  url 'http://downloads.sourceforge.net/project/boost/boost/1.51.0/boost_1_51_0.tar.bz2'
  sha1 '52ef06895b97cc9981b8abf1997c375ca79f30c5'

  head 'http://svn.boost.org/svn/boost/trunk'

  option :universal
  option :cxx11
  option 'with-mpi', 'Enable MPI support'
  option 'without-python', 'Build without Python'
  option 'with-icu', 'Build regexp engine with icu support'
  option 'with-log', 'Build with provisionally accepted logging library'

  depends_on UniversalPython.new if needs_universal_python?
  depends_on "icu4c" if build.include? "with-icu"

  fails_with :llvm do
    build 2335
    cause "Dropped arguments to functions when linking with boost"
  end

  def install

    if build.include? "with-log"
      d = Dir.getwd
      BoostLog.new.brew do
	inreplace 'libs/log/src/text_file_backend.cpp', 'get_generic_category', 'generic_category'
        mv "boost/log", "#{d}/boost/"
        mv "libs/log", "#{d}/libs/"
      end
    end

    # Adjust the name the libs are installed under to include the path to the
    # Homebrew lib directory so executables will work when installed to a
    # non-/usr/local location.
    #
    # otool -L `which mkvmerge`
    # /usr/local/bin/mkvmerge:
    #   libboost_regex-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   libboost_filesystem-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   libboost_system-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #
    # becomes:
    #
    # /usr/local/bin/mkvmerge:
    #   /usr/local/lib/libboost_regex-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   /usr/local/lib/libboost_filesystem-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    #   /usr/local/libboost_system-mt.dylib (compatibility version 0.0.0, current version 0.0.0)
    inreplace 'tools/build/v2/tools/darwin.jam', '-install_name "', "-install_name \"#{HOMEBREW_PREFIX}/lib/"

    # Force boost to compile using the appropriate GCC version
    open("user-config.jam", "a") do |file|
      file.write "using darwin : : #{ENV.cxx} ;\n"
      file.write "using mpi ;\n" if build.include? 'with-mpi'
    end

    # we specify libdir too because the script is apparently broken
    bargs = ["--prefix=#{prefix}", "--libdir=#{lib}"]

    if build.include? "with-icu"
      icu4c_prefix = Formula.factory('icu4c').prefix
      bargs << "--with-icu=#{icu4c_prefix}"
    end

    ENV.cxx11 if build.cxx11?

    args = ["--prefix=#{prefix}",
            "--libdir=#{lib}",
            "-j#{ENV.make_jobs}",
            "--layout=tagged",
            "--user-config=user-config.jam",
            "threading=multi",
	    "toolset=clang",
            "install"]

    args << "cxxflags=#{ENV.cxxflags}" << "linkflags=#{ENV.ldflags}" if build.cxx11?
    args << "address-model=32_64" << "architecture=x86" << "pch=off" if build.universal?
    args << "--without-python" if build.include? "without-python"

    system "./bootstrap.sh", *bargs
    system "./bjam", *args
  end
end
