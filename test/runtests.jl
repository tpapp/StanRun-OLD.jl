import StanRun

using StanDump
using Base.Test

@testset "cmdstan path" begin
    ## test finding executables
    if is_linux()
        @test StanRun.find_executable_dir("sh") == "/bin"
    end
    @test withenv(() -> StanRun.find_executable_dir("stanc"), "PATH" => "") == nothing
    @test withenv(() -> StanRun.find_executable_dir("stanc"), "PATH" => nothing) == nothing
        
    # test finding stanc
    cmdstan_home = "/tmp/test9999"

    # when ENV variable CMDSTAN_HOME is given
    withenv("CMDSTAN_HOME" => cmdstan_home) do
            @test StanRun.find_cmdstan_home() == cmdstan_home
    end

    # when it isn't, create a file that looks like it is executable and try to find it
    dummy_bin = joinpath(cmdstan_home, "bin")
    dummy_stanc = joinpath(dummy_bin, "stanc")
    withenv("CMDSTAN_HOME" => nothing, "PATH" => dummy_bin) do
        mkpath(dummy_bin)
        touch(dummy_stanc)
        chmod(dummy_stanc, 0o777)
        @test StanRun.find_cmdstan_home() == cmdstan_home
        rm(dummy_bin; recursive = true)
    end

    withenv("CMDSTAN_HOME" => nothing, "PATH" => nothing) do
        @test_throws Exception StanRun.find_cmdstan_home()
    end
end

@testset "program paths" begin
    cmdstan_home = "/tmp/test4444" # fictional path, just to test correctness
    withenv("CMDSTAN_HOME" => cmdstan_home) do 
        sp = StanRun.Program("/tmp/test99")
        @test StanRun.getpath(sp, StanRun.SOURCE) == "/tmp/test99.stan"
        @test StanRun.getpath(sp, StanRun.EXECUTABLE) == "/tmp/test99"
        @test StanRun.getpath(sp, StanRun.DIR) == "/tmp"
        @test StanRun.getpath(sp, StanRun.Samples(1)) ==
            "/tmp/test99-samples-1.csv"
        let rx = StanRun.getpath(sp, StanRun.SAMPLEBASERX)
            @test rx == Regex("test99-samples-([[:digit:]]+).csv")
            @test ismatch(rx, "test99-samples-99.csv")
            @test !ismatch(rx, "test99-samples-.csv")
            @test !ismatch(rx, "test99-samples-xx.csv")
            @test match(rx, "test99-samples-99.csv").captures == ["99"]
        end
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

@testset "make nonexistent" begin
    mktempdir() do dir
        sp = StanRun.Program(joinpath(dir, "nonexistent.stan"))
        @test_throws AssertionError StanRun.make(sp, StanRun.DATA)
        @test_throws AssertionError StanRun.make(sp, StanRun.SOURCE)
        @test_throws AssertionError StanRun.make(sp, StanRun.EXECUTABLE)
    end
end

@testset "bernoulli" begin
    sp = StanRun.Program(Pkg.dir("StanRun", "test", "bernoulli", "bernoulli"))
    N = 200
    θ = 0.3
    y = Int.(rand(N) .< θ)
    standump(sp, @vardict N y)
    timestamp = time()
    StanRun.make(sp, StanRun.Samples(1))
    samples_path = Pkg.dir("StanRun", "test", "bernoulli",
                           "bernoulli-samples-1.csv")
    @test isfile(samples_path) && (mtime(samples_path) ≥ timestamp)
    StanRun.sample(sp, 2)
    @test StanRun.sample_ids(sp) == [1, 2]
end
