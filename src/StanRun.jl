module StanRun

using ArgCheck
using StanDump

import StanDump: standump

"""
    find_executable_dir(name)

Searching the directories in `ENV["PATH"]`, return the directory of
the first executable file with name `name`, or `nothing` if not found.

NOTE: Testing for executables is heuristic.
"""
function find_executable_dir(name)
    for dir in split(ENV["PATH"], @static is_windows() ? ";" : ":")
        if isdir(dir) && name ∈ readdir(dir)
            path = joinpath(dir, name)
            if ((uperm(path) | gperm(path) | operm(path)) & 1) ≠ 0
                return dir
            end
        end
    end
    nothing
end

"""
   find_cmdstan_home()

Try to find the home directory of `CmdStan`, either from
`ENV[CMDSTAN_HOME]` or falling back to searching for the `stanc`
executable. Error when not found.
"""
function find_cmdstan_home()
    envkey = "CMDSTAN_HOME"
    if haskey(ENV, envkey)
        ENV[envkey]
    else
        dir = find_executable_dir("stanc")
        if dir == nothing
            error("stanc not found in path, could not determine CMDSTAN_HOME")
        end
        joinpath(dir, "..")
    end
end

"""

"""
struct Program
    cmdstan_home::String
    program_file::String
    function Program(program_file; cmdstan_home = find_cmdstan_home())
        @argcheck isabspath(cmdstan_home)
        @argcheck isabspath(program_file)
        new(cmdstan_home, program_file)
    end
end

# constants for various parts
const STANC = Val{:stanc}
const STANSUMMARY = Val{:stansummary}
const SOURCE = Val{:source}
const DATA = Val{:data}
const EXECUTABLE = Val{:executable}

"""
    Samples (MCMC draws). The chain ID is appended to the end.
"""
struct Samples
    id::Int
end

"""
    getpath(sp, part)

Return the path for the given `part`. Path does not necessarily point
to an existing file.
"""
getpath(sp::Program, ::Type{STANC}) =
    joinpath(sp.cmdstan_home, "bin/stanc")
getpath(sp::Program, ::Type{STANSUMMARY}) =
    joinpath(sp.cmdstan_home, "bin/stansummary")
getpath(sp::Program, ::Type{SOURCE}) = sp.program_file * ".stan"
getpath(sp::Program, ::Type{DATA}) = sp.program_file * ".data.R"
getpath(sp::Program, ::Type{EXECUTABLE}) = sp.program_file
getpath(sp::Program, samples::Samples) =
    sp.program_file * "-samples-" * string(samples.id) * ".csv"

"""
    getparents(part)

Return the part identifier for the other parts that are required to make it.
"""
getparents(::Any) = ()
getparents(::Type{EXECUTABLE}) = (STANC, SOURCE)
getparents(::Samples) = (EXECUTABLE, DATA)

"""
    make(sp, part; force = false)

Make `part` of a Stan program, conditional on parent parts being more
recent. Traverses dependencies recursively, using `mdate`s, or
unconditionally when `force`.

This function implements the traversal algorithm, `_make` does the
actual work.
"""
function make(sp::Program, part; force = false)
    parents = getparents(part)
    parent_timestamps = make.(sp,parents; force = force)
    path = getpath(sp, part)
    if isempty(parent_timestamps)
        @assert isfile(path) 
    else
        if force || !isfile(path) || (mtime(path) < maximum(parent_timestamps))
            _make(sp, part)
        end
    end
    mtime(path)
end

"""
    _make(sp, part)

Make `part` of a Stan program. Assumes that parent parts are available.
"""
function _make(sp::Program, part::Any)
    error("Could not find $(part) at $(getpath(sp, part)).")
end

function _make(sp::Program, ::Type{EXECUTABLE})
    executable_path = getpath(sp, EXECUTABLE)
    run(Cmd(`make $(executable_path)`; dir = sp.cmdstan_home))
end

function _make(sp::Program, samples::Samples)
    executable_path = getpath(sp, EXECUTABLE)
    data_path = getpath(sp, DATA)
    samples_path = getpath(sp, samples)
    run(`$(executable_path) sample data file=$(data_path) output file=$(samples_path)`)
end

function standump(sp::Program, data...)
    open(io -> standump(io, data...), getpath(sp, DATA), "w+")
end
    
end # module
