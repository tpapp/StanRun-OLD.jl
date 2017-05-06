import StanRun

using StanDump
using Base.Test

@testset "cmdstan path" begin
    if is_linux()
        @test StanRun.find_executable_dir("sh") == "/bin"
    end
    
    let dir = "/tmp/test9999"
        orig = ENV["CMDSTAN_HOME"]
        ENV["CMDSTAN_HOME"] = dir
        @test StanRun.find_cmdstan_home() == dir
        ENV["CMDSTAN_HOME"] = orig
    end
end

@testset "program paths" begin
    sp = StanRun.Program("/tmp/test99")
    @test StanRun.getpath(sp, StanRun.SOURCE) == "/tmp/test99.stan"
    @test StanRun.getpath(sp, StanRun.EXECUTABLE) == "/tmp/test99"
    @test StanRun.getpath(sp, StanRun.Samples(1)) == "/tmp/test99-samples-1.csv"
end

@testset "parents" begin
    # parts which have to be available
    @test StanRun.getparents(StanRun.SOURCE) == ()
    @test StanRun.getparents(StanRun.DATA) == ()
    @test StanRun.getparents(StanRun.STANC) == ()
    # parts with dependencies
    @test StanRun.getparents(StanRun.EXECUTABLE) ==
        (StanRun.STANC, StanRun.SOURCE)
    @test StanRun.getparents(StanRun.Samples(1)) ==
        (StanRun.EXECUTABLE, StanRun.DATA)
end
