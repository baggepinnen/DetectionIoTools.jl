using DetectionIoTools
using Test

@testset "DetectionIoTools.jl" begin
    @testset "Save interesting" begin
        @info "Testing Save interesting"
        allsounds = [randn(100) for _ in 1:10]

        sounddir = save_interesting(allsounds, [1,3])
        @test readdir(sounddir) |> length == 3

    end
end
