
import Base: -, +, *, filter
import LinearAlgebra: norm

abstract type AbstractProperty end

function coco_init end
function coco_zero end
function coco_filter end
function coco_dot end


@inline +(φ1::T, φ2::T) where {T <: AbstractProperty} = T( φ1.val + φ2.val )
@inline -(φ1::T, φ2::T) where {T <: AbstractProperty} = T( φ1.val - φ2.val )
@inline -(φ::T) where {T <: AbstractProperty} = T( -φ.val)
@inline *(a::Union{Number, AbstractMatrix}, φ::T) where {T <: AbstractProperty} =
      T(a * φ.val)
@inline *(φ::T, a::Union{Number, AbstractMatrix}) where {T <: AbstractProperty} =
      T(φ.val * a)
@inline norm(φ::T) where {T <: AbstractProperty} = norm(φ.val)
@inline Base.length(φ::AbstractProperty) = length(φ.val)
@inline Base.size(φ::AbstractProperty) = size(φ.val)
@inline Base.zero(φ::T) where {T <: AbstractProperty} = T(zero(φ.val))
@inline Base.zero(::Type{T}) where {T <: AbstractProperty} = zero(T())


Base.isapprox(φ1::T, φ2::T) where {T <: AbstractProperty} =
      isapprox(φ1.val, φ2.val)

"""
`struct Invariant{D}` : specifies that the output of an ACE is
an invariant scalar.
"""
struct Invariant{T} <: AbstractProperty
   val::T
end

Invariant{T}() where {T <: Number} = Invariant{T}(zero(T))

Invariant(T::DataType = Float64) = Invariant{T}()

filter(φ::Invariant, b::Array) = ( length(b) <= 1 ? true :
     iseven(sum(bi.l for bi in b)) && iszero(sum(bi.m for bi in b))  )

rot3Dcoeffs(::Invariant, T=Float64) = Rot3DCoeffs(T)

# TODO: this is a naive implementation of differentiation.
#       cf https://github.com/ACEsuit/ACE.jl/issues/27
#       for further discussion
*(φ::Invariant, dAA::SVector) = φ.val * dAA

coco_init(φ::Invariant, l, m, μ, T, A::Rot3DCoeff) =
            l == m == μ == 0 ? zero(T) : T(1)

coco_zero(::Invariant, T) =
            zero(T)

coco_filter(::Invariant, ll, mm, kk) =
            iseven(sum(ll)) && (sum(mm) == sum(kk) == 0)


@doc raw"""
`struct EuclideanVector{D, T}` : specifies that the output $\varphi$ of an
ACE is an equivariant $\varphi \in \mathbb{R}^{3}$, i.e., it transforms under
$O(3)$ as
```math
      \varphi \circ Q = Q \cdot \varphi,
```
where $\cdot$ denotes the standard matrix-vector product.
"""
struct EuclideanVector{T} <: AbstractProperty
   val::SVector{3, T}
end

EuclideanVector{T}() where {T <: Number} = EuclideanVector{T}(zero(SVector{3, T}))

EuclideanVector(T::DataType=Float64) = EuclideanVector{T}()

filter(φ::EuclideanVector, b::Array) = ( length(b) <= 1 ? true :
             isodd( sum(bi.l for bi in b)) &&
            (abs(sum(bi.m for bi in b)) <= 1) )

rot3Dcoeffs(::EuclideanVector,T=Float64) = Rot3DCoeffsEquiv{T,1}(Dict[], ClebschGordan(T))

# differentiation - cf #27
*(φ::EuclideanVector, dAA::SVector) = φ.val * dAA'



struct SphericalVector{L, LEN, T} <: AbstractProperty
   val::SVector{LEN, T}
   _valL::Val{L}
end

# differentiation - cf #27
*(φ::SphericalVector, dAA::SVector) = φ.val * dAA'


getL(φ::SphericalVector{L}) where {L} = L

# L = 0 -> (0,0)
# L = 1 -> (0,0), (1,-1), (1,0), (1,1)  -> 4
# L = 3 ->  ... + 5 -> 9
# 1 + 3 + 5 + ... + 2*L+1
# = L + 2 * (1 + ... + L) = L+1 + 2 * L * (L+1) / 2 = (L+1)^2
function SphericalVector(L::Integer; T = Float64)
   LEN = 2L+1   # length of SH basis up to L
   return SphericalVector( zero(SVector{LEN, T}), Val{L}() )
end

function SphericalVector{L, LEN, T}(x::AbstractArray) where {L, LEN, T}
   @assert length(x) == LEN
   SphericalVector{L, LEN, T}( SVector{LEN, T}(x...), Val(L) )
end

SphericalVector{L, LEN, T}()  where {L, LEN, T} =
      SphericalVector( zero(SVector{LEN, T}), Val{L}() )

filter(φ::SphericalVector, b::Array) = ( length(b) <= 1 ? true :
        ( ( iseven(sum(bi.l for bi in b)) == iseven(getL(φ)) ) &&
         ( abs(sum(bi.m for bi in b)) <= getL(φ) )  ) )

rot3Dcoeffs(::SphericalVector, T::DataType=Float64) = Rot3DCoeffs(T)


struct SphericalMatrix{L1, L2, LEN1, LEN2, T} <: AbstractProperty
   val::SMatrix{LEN1, LEN2, T}
   _valL1::Val{L1}
   _valL2::Val{L2}
end

# differentiation - cf #27
# actually this here appears to be the generic form how to do the
# differentiation for arbtirary order tensors.
*(φ::SphericalMatrix{L1, L2, LEN1, LEN2}, dAA::SVector{N}
      ) where {L1, L2, LEN1, LEN2, N} =
      reshape(φ.val[:] * dAA', Size(LEN1, LEN2, N))

getL(φ::SphericalMatrix{L1,L2}) where {L1,L2} = L1, L2

# L = 0 -> (0,0)
# L = 1 -> (0,0), (1,-1), (1,0), (1,1)  -> 4
# L = 3 ->  ... + 5 -> 9
# 1 + 3 + 5 + ... + 2*L+1
# = L + 2 * (1 + ... + L) = L+1 + 2 * L * (L+1) / 2 = (L+1)^2
function SphericalMatrix(L1::Integer, L2::Integer; T = Float64)
   LEN1 = 2L1+1   # length of SH basis up to L
   LEN2 = 2L2+1
   return SphericalMatrix( zero(SMatrix{LEN1, LEN2, T}), Val{L1}(), Val{L2}() )
end

function SphericalMatrix{L1, L2, LEN1, LEN2, T}(x::AbstractMatrix) where {L1, L2, LEN1, LEN2, T}
   @assert size(x) == (LEN1, LEN2)
   SphericalMatrix{L1, L2, LEN1, LEN2, T}( SMatrix{LEN1, LEN2, T}(x...), Val(L1), Val(L2) )
end

SphericalMatrix{L1, L2, LEN1, LEN2, T}()  where {L1, L2, LEN1, LEN2, T} =
      SphericalMatrix( zero(SMatrix{LEN1, LEN2, T}), Val{L1}(), Val{L2}() )

filter(φ::SphericalMatrix, b::Array) = ( length(b) < 1 ? true :
        ( ( iseven(sum(bi.l for bi in b)) == iseven(sum(getL(φ))) ) &&
         ( abs(sum(bi.m for bi in b)) <= sum(getL(φ)) )  ) )

rot3Dcoeffs(::SphericalMatrix, T::DataType=Float64) = Rot3DCoeffs(T)
