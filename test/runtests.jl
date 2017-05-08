import StanRun

using StanDump
using Base.Test

@testset "cmdstan path" begin
    if is_linux()
        @test StanRun.find_executable_dir("sh") == "/bin"
    end
    @test withenv(() -> StanRun.find_executable_dir("stanc"), "PATH" => "") == nothing
        
    let dir = "/tmp/test9999"
        withenv("CMDSTAN_HOME" => dir) do
            @test StanRun.find_cmdstan_home() == dir
        end
    end
end

@testset "program paths" begin
    cmdstan_home = "/tmp/test4444" # fictional path, just to test correctness
    withenv("CMDSTAN_HOME" => cmdstan_home) do 
        sp = StanRun.Program("/tmp/test99")
        @test StanRun.getpath(sp, StanRun.SOURCE) == "/tmp/test99.stan"
        @test StanRun.getpath(sp, StanRun.EXECUTABLE) == "/tmp/test99"
        @test StanRun.getpath(sp, StanRun.Samples(1)) ==
            "/tmp/test99-samples-1.csv"
        @test StanRun.getpath(sp, StanRun.STANC) ==
            joinpath(cmdstan_home, "bin/stanc")
        @test StanRun.getpath(sp, StanRun.STANSUMMARY) ==
            joinpath(cmdstan_home, "bin/stansummary")
    end
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
