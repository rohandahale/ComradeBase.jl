export visibilities, visibilities!,
      logclosure_amplitude, logclosure_amplitudemap,
      amplitude, amplitudemap,
      closure_phase, closure_phasemap,
      bispectrum, bispectrummap


"""
    visibilitymap(m, p)

Computes the visibilities of the model `m` using the coordinates `p`. The coordinates `p`
are expected to have the properties `U`, `V`, and sometimes `T` and `F`.
"""
@inline function visibilitymap(m::M, p) where {M<:AbstractModel}
    return create_map(_visibilitymap(visanalytic(M), m, p), p)
end
@inline _visibilitymap(::IsAnalytic,  m::AbstractModel, p)  = visibilitymap_analytic(m, p)
@inline _visibilitymap(::NotAnalytic, m::AbstractModel, p)  = visibilitymap_numeric(m, p)



"""
    visibilitymap!(vis, m, p)

Computes the visibilities `vis` in place of the model `m` using the coordinates `p`. The coordinates `p`
are expected to have the properties `U`, `V`, and sometimes `T` and `F`.
"""
@inline function visibilitymap!(vis, m::M) where {M<:AbstractModel}
    return _visibilitymap!(visanalytic(M), vis, m)
end
@inline _visibilitymap!(::IsAnalytic , vis, m::AbstractModel)  = visibilitymap_analytic!(vis, m)
@inline _visibilitymap!(::NotAnalytic, vis, m::AbstractModel)  = visibilitymap_numeric!(vis, m)

function visibilitymap_analytic(m::AbstractModel, p::AbstractGrid)
    g = domaingrid(p)
    return  visibility_point.(Ref(m), g)
end

function visibilitymap_analytic!(vis, m::AbstractModel)
    d = axisdims(vis)
    g = domaingrid(d)
    vis .= visibility_point.(Ref(m), g)
    return nothing
end

function visibilitymap_analytic(m::AbstractModel, p::AbstractGrid{D, <:ThreadsEx}) where {D}
    vis = allocate_map(p)
    visibilitymap_analytic!(vis, m)
    return vis
end

function visibilitymap_analytic!(vis::UnstructuredMap{T, <:AbstractVector, <:UnstructuredGrid{D, <:ThreadsEx{S}}}, m::AbstractModel) where {T,D,S}
    d = axisdims(vis)
    g = domaingrid(d)
    _threads_visibilitymap!(vis, m, g, Val(S))
    return nothing
end

function visibilitymap_analytic!(
    vis::IntensityMap{T,N,D,<:AbstractArray{T,N},<:ComradeBase.AbstractRectiGrid{D, <:ThreadsEx{S}}},
    m::AbstractModel) where {T,N,D,S}
    d = axisdims(vis)
    g = domaingrid(d)
    _threads_visibilitymap!(parent(vis), m, g, Val(S))
    return nothing
end

for s in schedulers
    @eval begin
        function _threads_visibilitymap!(vis, s::AbstractModel, g, ::Val{$s})
            Threads.@threads $s for I in CartesianIndices(g)
                vis[I] = visibility_point(s, g[I])
            end
        end
        return nothing
    end
end




"""
    visibility(mimg, p)

Computes the complex visibility of model `m` at coordinates `p`. `p` corresponds to
the coordinates of the model. These need to have the properties `U`, `V` and sometimes
`Ti` for time and `Fr` for frequency.

# Notes
If you want to compute the visibilities at a large number of positions
consider using the [`visibilities`](@ref visibilities).
"""
@inline function visibility(mimg::M, p) where {M}
    #first we split based on whether the model is primitive
    _visibility(isprimitive(M), mimg, p)
end


"""
    amplitude(model, p)

Computes the visibility amplitude of model `m` at the coordinate `p`.
The coordinate `p`
is expected to have the properties `U`, `V`, and sometimes `Ti` and `Fr`.

If you want to compute the amplitudemap at a large number of positions
consider using the `amplitudemap` function.
"""
@inline function amplitude(model, p)
    return abs(visibility(model, p))
end

"""
    bispectrum(model, p1, p2, p3)

Computes the complex bispectrum of model `m` at the uv-triangle
p1 -> p2 -> p3

If you want to compute the bispectrum over a number of triangles
consider using the `bispectrummap` function.
"""
@inline function bispectrum(model, p1, p2, p3)
    return visibility(model, p1)*visibility(model, p2)*visibility(model, p3)
end

"""
    closure_phase(model, p1, p2, p3, p4)

Computes the closure phase of model `m` at the uv-triangle
u1,v1 -> u2,v2 -> u3,v3

If you want to compute closure phases over a number of triangles
consider using the `closure_phasemap` function.
"""
@inline function closure_phase(model, p1, p2, p3)
    return angle(bispectrum(model, p1, p2, p3))
end

"""
    logclosure_amplitude(model, p1, p2, p3, p4)

Computes the log-closure amplitude of model `m` at the uv-quadrangle
u1,v1 -> u2,v2 -> u3,v3 -> u4,v4 using the formula

```math
C = \\log\\left|\\frac{V(u1,v1)V(u2,v2)}{V(u3,v3)V(u4,v4)}\\right|
```

If you want to compute log closure amplitudemap over a number of triangles
consider using the `logclosure_amplitudemap` function.
"""
@inline function logclosure_amplitude(model, p1, p2, p3, p4)
    a1 = amplitude(model, p1)
    a2 = amplitude(model, p2)
    a3 = amplitude(model, p3)
    a4 = amplitude(model, p4)

    return log(a1*a2/(a3*a4))
end


#=
    Welcome to the trait jungle. Below is
    how we specify how to evaluate the model
=#
@inline function _visibility(::NotPrimitive, m, p)
    return visibility_point(m, p)
end

@inline function _visibility(::IsPrimitive, m::M, p) where {M}
    _visibility_primitive(visanalytic(M), m, p)
end


@inline function _visibility_primitive(::IsAnalytic, mimg, p)
    return visibility_point(mimg, p)
end




"""
    amplitudemap(m::AbstractModel, p)

Computes the visibility amplitudemap of the model `m` at the coordinates `p`.
The coordinates `p` are expected to have the properties `U`, `V`,
and sometimes `Ti` and `Fr`.
"""
function amplitudemap(m, p)
    create_map(_amplitudemap(m, p), p)
end


function _amplitudemap(m::S, p) where {S}
    _amplitudemap(visanalytic(S), m, p)
end

function _amplitudemap(::IsAnalytic, m, p::AbstractGrid)
    g = domaingrid(p)
    abs.(visibility_point.(Ref(m), g))
end

function _amplitudemap(::NotAnalytic, m, p::AbstractGrid)
    g = domaingrid(p)
    abs.(visibilitymap_numeric(m, g))
end


"""
    bispectrummap(m, p1, p2, p3)

Computes the closure phases of the model `m` at the
triangles p1, p2, p3, where `pi` are coordinates.
"""
function bispectrummap(m,
                    p1::T,
                    p2::T,
                    p3::T,
                    ) where {T<:AbstractGrid}

    _bispectrummap(m, p1, p2, p3)
end

# internal method used for trait dispatch
function _bispectrummap(m::M,
                    p1,
                    p2,
                    p3
                    ) where {M}
    _bispectrummap(visanalytic(M), m, p1, p2, p3)
end

# internal method used for trait dispatch for analytic visibilities
function _bispectrummap(::IsAnalytic, m,
                    p1::T,
                    p2::T,
                    p3::T,
                   ) where {T<:AbstractGrid}
    g1 = domaingrid(p1)
    g2 = domaingrid(p2)
    g3 = domaingrid(p3)
    return bispectrum.(Ref(m), g1, g2, g3)
end

# internal method used for trait dispatch for non-analytic visibilities
function _bispectrummap(::NotAnalytic, m,
                    p1::T,p2::T,p3::T
                   ) where {T<:AbstractGrid}
    vis1 = visibilitymap(m, p1)
    vis2 = visibilitymap(m, p2)
    vis3 = visibilitymap(m, p3)
    return @. vis1*vis2*vis3
end

"""
    closure_phasemap(m,
                   p1::AbstractArray
                   p2::AbstractArray
                   p3::AbstractArray
                   )

Computes the closure phases of the model `m` at the
triangles p1, p2, p3, where `pi` are coordinates.
"""
@inline function closure_phasemap(m::AbstractModel,
                        p1::T,p2::T,p3::T
                        ) where {T<:UnstructuredGrid}
    create_map(_closure_phasemap(m, p1, p2, p3), UnstructuredGrid((;p1=domaingrid(p1), p2=domaingrid(p2), p3=domaingrid(p3))))
end

# internal method used for trait dispatch
@inline function _closure_phasemap(m::M, p1, p2, p3) where {M<:AbstractModel}
    _closure_phasemap(visanalytic(M), m, p1, p2, p3)
end

# internal method used for trait dispatch for analytic visibilities
@inline function _closure_phasemap(::IsAnalytic, m,
                        p1::UnstructuredGrid,
                        p2::UnstructuredGrid,
                        p3::UnstructuredGrid
                       )
    g1 = domaingrid(p1)
    g2 = domaingrid(p2)
    g3 = domaingrid(p3)
    return closure_phase.(Ref(m), g1, g2, g3)
end

# internal method used for trait dispatch for non-analytic visibilities
function _closure_phasemap(::NotAnalytic, m, p1,p2, p3)
    return angle.(bispectrummap(m, p1, p2, p3))
end

"""
    logclosure_amplitudemap(m::AbstractModel,
                          p1,
                          p2,
                          p3,
                          p4
                         )

Computes the log closure amplitudemap of the model `m` at the
quadrangles p1, p2, p3, p4.
"""
function logclosure_amplitudemap(m::AbstractModel,
                               p1::T,
                               p2::T,
                               p3::T,
                               p4::T
                              ) where {T<:AbstractGrid}
    glc = UnstructuredGrid((;p1 = domaingrid(p1), p2 = domaingrid(p2), p3 = domaingrid(p3), p4 = domaingrid(p4)))
    create_map(_logclosure_amplitudemap(m, p1, p2, p3, p4), glc)
end


# internal method used for trait dispatch
@inline function _logclosure_amplitudemap(m::M,
                        p1,
                        p2,
                        p3,
                        p4
                       ) where {M<:AbstractModel}
    _logclosure_amplitudemap(visanalytic(M), m, p1, p2, p3, p4)
end

# internal method used for trait dispatch for analytic visibilities
@inline function _logclosure_amplitudemap(::IsAnalytic, m, p1, p2, p3, p4)
    g1 = domaingrid(p1)
    g2 = domaingrid(p2)
    g3 = domaingrid(p3)
    g4 = domaingrid(p4)
    return logclosure_amplitude.(Ref(m), g1, g2, g3, g4)
end

# internal method used for trait dispatch for non-analytic visibilities
@inline function _logclosure_amplitudemap(::NotAnalytic, m, p1, p2, p3, p4)
    amp1 = _amplitudemap(m, p1)
    amp2 = _amplitudemap(m, p2)
    amp3 = _amplitudemap(m, p3)
    amp4 = _amplitudemap(m, p4)
    return @. log(amp1*amp2*inv(amp3*amp4))
end
