module DetectionIoTools

using WAV
using ThreadTools
using Base.Threads
using Serialization
using Statistics


export mapsoundfiles, thing2file, save_interesting, save_interesting_concat

"""
    mapsoundfiles(f::F, files, [windowlength]) where F

map a Function over a list of wav files.

#Arguments:
- `f`: a Function
- `files`: DESCRIPTION
- `windowlength`: Optional. If supplied, `f` will be applied over non-overlapping windows for the sound, and a `Vector{Vector{RT}}` is returned, where `RT` is the return type of `f`.
"""
function mapsoundfiles(f::F,files,windowlength) where F
    GC.gc()
    # extension === nothing || (files = filter(f->splitext(f)[end] == extension, files))
    @time embeddings = tmap1(max(nthreads()-1,1),files) do file
        @info "Reading file $file"
        sound = wavread(file)[1]
        map(f,Iterators.partition(sound, windowlength))
    end
end

function mapsoundfiles(f::F,files) where F
    GC.gc()
    # extension === nothing || (files = filter(f->splitext(f)[end] == extension, files))
    @time embeddings = tmap1(max(nthreads()-1,1),files) do file
        @info "Reading file $file"
        sound = wavread(file)[1]
        f(sound)
    end
end

"""
    thing2file(thing, things [, files])

Finds the file corresponding to the `thing` amongst `things`. `things` can be a vector or a vector of vectors.
"""
function thing2file(thing, things::AbstractVector{<:AbstractVector}, files::AbstractVector = 1:length(things))
    findres = findfirst.(==(thing), things)
    fileno = findfirst(!=(nothing), findres)
    files[fileno]
end

function thing2file(thing, things, files::AbstractVector = 1:length(things))
    fileno = findfirst(==(thing), things)
    fileno === nothing && error("Did not find thing in things")
    files[fileno]
end

function WAV.wavplay(x::AbstractArray,fs)
    path = "/tmp/a.wav"
    wavwrite(x,path,Fs=fs)
    @info "Wrote to file $path"
    Threads.@spawn run(`totem $path`)
end

function WAV.wavplay(path::String)
    Threads.@spawn run(`totem $path`)
end

save_interesting(sounds, inds, args...) = save_interesting(sounds, findall(inds), args...)

"""
    save_interesting(sounds::Vector, inds::Vector{Int}, contextwindow=1)

Saves interesting wav files to disk, together with one concatenated file which contains all the itneresting sounds. The paths will be printed in the terminal.

# Arguments:
- `inds`: A list of indices to interesting sound clips
- `contextwindow`: Saves this many clips before and after
"""
function save_interesting(sounds::AbstractVector{T}, inds::Vector{Int}, contextwindow=1, fs=41000) where T
    tempdir = mktempdir()
    for ind ∈ inds
        extended_inds = max(1, ind-contextwindow):min(length(sounds), ind+contextwindow)
        sound = map(extended_inds) do i
            getsound(sounds[i])
        end
        sound = reduce(vcat, sound)[:]
        filename = T <: AbstractString ? splitpath(files[ind])[end] : string(ind)
        tempfile = joinpath(tempdir, filename*".wav")
        sound .-= mean(Float32.(sound))
        sound .*= 1/maximum(abs.(sound))
        wavwrite(sound, tempfile, Fs=fs)
        println(tempfile)
    end
    save_interesting_concat(sounds, inds, tempdir, fs=fs)
end

getsound(sound) = sound
function getsound(sound::AbstractString)
    ext = splitext(sound)[2]
    if ext == "wav"
        wavread(sound)
    else
        deserialize(sound)
    end
end

function save_interesting_concat(sounds, inds::Vector{Int}, tempdir=mktempdir(); fs=41000)
    sound = map(inds) do i
        sound = getsound(sounds[i])
        sound .-= mean(Float32.(sound))
        sound .*= 1/maximum(abs.(sound))
    end
    sound = reduce(vcat, sound)[:]
    tempfile = joinpath(tempdir, "concatenated.wav")
    wavwrite(sound, tempfile, Fs=fs)
    println(tempfile)
    tempdir
end


end
