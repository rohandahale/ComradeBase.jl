using ComradeBase, StaticArrays, JET
using StructArrays
using Pyehtim
using Test

@testset "ComradeBase.jl" begin
    include(joinpath(@__DIR__, "images.jl"))
    include(joinpath(@__DIR__, "io.jl"))
end
