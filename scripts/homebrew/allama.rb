# Homebrew Formula for allama
# Aerospace-Level Security Implementation

class Allama < Formula
  desc "Model management CLI for allama (llama.cpp fork)"
  homepage "https://github.com/ggml-org/llama-cpp-turboquant"
  url "https://github.com/ggml-org/llama-cpp-turboquant.git",
      revision: "HEAD"
  version "1.0.0"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "git" => :build
  depends_on "pkg-config" => :build
  depends_on "sqlite3"

  def install
    # Build with server and allama enabled
    system "cmake", "-S", ".", "-B", "build",
           "-DLLAMA_BUILD_SERVER=ON",
           "-DLLAMA_BUILD_ALLAMA=ON",
           "-DLLAMA_CURL=ON",
           *std_cmake_args

    system "cmake", "--build", "build", "--target", "allama", "--parallel"

    # Install binaries
    bin.install "build/bin/allama"
    bin.install_symlink "build/bin/llama-server" => "allama-server" if File.exist?("build/bin/llama-server")

    # Install man pages if they exist
    man1.install Dir["docs/man/*.1"] if Dir.exist?("docs/man")
  end

  test do
    # Test basic functionality
    system bin/"allama", "--version"
    system bin/"allama", "--help"
    
    # Test model registry initialization
    (testpath/".allama").mkpath
    system bin/"allama", "list"
  end

  def caveats
    <<~EOS
      allama has been installed successfully!

      To get started:
        1. List available models:
           allama list

        2. Pull a model:
           allama pull llama3:latest

        3. Run the server:
           allama-server --model ~/.allama/models/llama3:latest

      Model Registry:
        Default registry path: ~/.allama/registry.db
        Default models path: ~/.allama/models/

      For more information:
        allama --help
        https://github.com/ggml-org/llama-cpp-turboquant
    EOS
  end
end
