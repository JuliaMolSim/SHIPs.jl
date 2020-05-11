
# --------------------------------------------------------------------------
# ACE.jl and SHIPs.jl: Julia implementation of the Atomic Cluster Expansion
# Copyright (c) 2019 Christoph Ortner <christophortner0@gmail.com>
# All rights reserved.
# --------------------------------------------------------------------------


using SHIPs.SphericalHarmonics: SHBasis, index_y
using StaticArrays
using JuLIP: AbstractCalculator, Atoms, JVec
using JuLIP.Potentials: SitePotential, SZList, ZList
using NeighbourLists: neigs

import JuLIP, JuLIP.MLIPs

export PIPotential


"""
`struct PIPotential` : specifies a PIPotential, which is basically defined
through a PIBasis and its coefficients
"""
struct PIPotential{T, NZ, TIN} <: SitePotential
   pibasis::TIN
   coeffs::NTuple{NZ, Vector{T}}
end

cutoff(V::PIPotential) = cutoff(V.pibasis)

==(V1::PIPotential, V2::PIPotential) =
      (V1.pibasis == V2.pibasis) && (V1.coeffs == V2.coeffs)

# TODO: this doesn't feel right ... should be real(T)?
Base.eltype(::PIPotential{T}) where {T} = T

z2i(V::PIPotential, z::AtomicNumber) = z2i(V.pibasis, z)
JuLIP.numz(V::PIPotential) = numz(V.pibasis)

# ------------------------------------------------------------
#   Initialisation code
# ------------------------------------------------------------

combine(basis::PIBasis, coeffs) = PIPotential(basis, coeffs)


function PIPotential(basis::PIBasis, coeffs::Vector{<: Number})
   coeffs_t = ntuple(iz0 -> coeffs[basis.inner[iz0].AAindices], numz(basis))
   return PIPotential(basis, coeffs_t)
end


# ------------------------------------------------------------
#   FIO code
# ------------------------------------------------------------

# Dict(ship::SHIP{T,NZ}) where {T, NZ} = Dict(
#       "__id__" => "SHIPs_SHIP_v2",
#       "J" => Dict(ship.J),
#       "SH_maxL" => ship.SH.maxL,   # TODO: replace this with Dict(SH)
#       "T" => string(eltype(ship.SH)),
#       "zlist" => Dict(ship.zlist),
#       "alists" => [Dict.(ship.alists)...],
#       "aalists" => [Dict.(ship.aalists)...],
#       "coeffs_re" => [ real.(ship.coeffs[i]) for i = 1:NZ  ],
#       "coeffs_im" => [ imag.(ship.coeffs[i]) for i = 1:NZ  ]
#    )
#
# convert(::Val{:SHIPs_SHIP_v2}, D::Dict) = SHIP(D)
#
# # bodyorder - 1 is because BO is the number of neighbours
# # not the actual body-order
# function SHIP(D::Dict)
#    T = Meta.eval(Meta.parse(D["T"]))
#    J = TransformedJacobi(D["J"])
#    SH = SHBasis(D["SH_maxL"], T)
#    zlist = decode_dict(D["zlist"])
#    NZ = length(zlist)
#    alists = ntuple(i -> AList(D["alists"][i]), NZ)
#    aalists = ntuple(i -> AAList(D["aalists"][i], alists[i]), NZ)
#    coeffs = ntuple(i -> T.(D["coeffs_re"][i]) + im * T.(D["coeffs_im"][i]), NZ)
#    return  SHIP(J, SH, zlist, alists, aalists, coeffs)
# end


# ------------------------------------------------------------
#   Evaluation code
# ------------------------------------------------------------



alloc_temp(V::PIPotential{T}, maxN::Integer) where {T} =
   (
      R = zeros(JVecF, maxN),
      Z = zeros(AtomicNumber, maxN),
      tmp_pibasis = alloc_temp(V.pibasis, maxN),
  )



# compute one site energy
function evaluate!(tmp, V::PIPotential,
                   Rs::AbstractVector{JVec{T}},
                   Zs::AbstractVector{<:AtomicNumber},
                   z0::AtomicNumber) where {T}
   iz0 = z2i(V, z0)
   A = evaluate!(tmp.tmp_pibasis.A, tmp.tmp_pibasis.tmp_basis1p,
                 V.pibasis.basis1p, Rs, Zs, z0)
   inner = V.pibasis.inner[iz0]
   c = V.coeffs[iz0]
   Es = zero(T)
   for iAA = 1:length(inner)
      Esi = c[iAA] # one(Complex{T})
      for α = 1:inner.orders[iAA]
         Esi *= A[inner.iAA2iA[iAA, α]]
      end
      Es += real(Esi)
   end
   return Es
end


alloc_temp_d(V::PIPotential{T}, N::Integer) where {T} =
      (
      dAco = zeros(eltype(V.pibasis),
                   maximum(length(V.pibasis.basis1p, iz) for iz=1:numz(V))),
       tmpd_pibasis = alloc_temp_d(V.pibasis, N),
       dV = zeros(JVec{T}, N),
        R = zeros(JVec{T}, N),
        Z = zeros(AtomicNumber, N)
      )

# compute one site energy
function evaluate_d!(dEs, tmpd, V::PIPotential,
                     Rs::AbstractVector{<: JVec{T}},
                     Zs::AbstractVector{AtomicNumber},
                     z0::AtomicNumber
                     ) where {T}
   iz0 = z2i(V, z0)
   basis1p = V.pibasis.basis1p
   tmpd_1p = tmpd.tmpd_pibasis.tmpd_basis1p
   Araw = tmpd.tmpd_pibasis.A

   # stage 1: precompute all the A values
   A = evaluate!(Araw, tmpd_1p, basis1p, Rs, Zs, z0)

   # stage 2: compute the coefficients for the ∇A_{klm} = ∇ϕ_{klm}
   dAco = tmpd.dAco
   c = V.coeffs[iz0]
   inner = V.pibasis.inner[iz0]
   fill!(dAco, 0)
   for iAA = 1:length(inner)
      for α = 1:inner.orders[iAA]
         CxA_α = c[iAA]
         for β = 1:inner.orders[iAA]
            if β != α
               CxA_α *= A[inner.iAA2iA[iAA, β]]
            end
         end
         iAα = inner.iAA2iA[iAA, α]
         dAco[iAα] += CxA_α
      end
   end

   # stage 3: get the gradients
   fill!(dEs, zero(JVec{T}))
   dAraw = tmpd.tmpd_pibasis.dA
   for (iR, (R, Z)) in enumerate(zip(Rs, Zs))
      dA = evaluate_d!(Araw, dAraw, tmpd_1p, basis1p, R, Z, z0)
      iz = z2i(basis1p, Z)
      dAco_z = @view dAco[basis1p.Aindices[iz, iz0]]
      for iA = 1:length(dA)
         dEs[iR] += real(dAco_z[iA] * dA[iA])
      end
   end
   return dEs
end