

using SHIPs, SHIPs.SphericalHarmonics, StaticArrays, LinearAlgebra
using SHIPs: _mrange


function compute_Ckm(ll::SVector{4})
   cg = ClebschGordan(sum(ll))

   len = 0
   for mm in _mrange(ll)
      len += 1
   end
   @show len

   Ckm = zeros(len, len)

   for (im, mm) in enumerate(_mrange(ll)), (ik, kk) in enumerate(_mrange(ll))
      jlo = max(abs(ll[1]-ll[2]), abs(ll[3]-ll[4]))
      jhi = min(ll[1]+ll[2], ll[3]+ll[4])
      for j = jlo:jhi
         if (abs(mm[1]+mm[2]) > j) || (abs(mm[3]+mm[4]) > j) ||
            (abs(kk[1]+kk[2]) > j) || (abs(kk[3]+kk[4]) > j)
            continue
         end
         cg1 = cg(ll[1], mm[1], ll[2], mm[2], j, mm[1]+mm[2])
         cg2 = cg(ll[3], mm[3], ll[4], mm[4], j, mm[3]+mm[4])
         cg3 = cg(ll[1], kk[1], ll[2], kk[2], j, kk[1]+kk[2])
         # @show ll[3], kk[3], ll[4], kk[4], j, kk[3]+kk[4]
         cg4 = cg(ll[3], kk[3], ll[4], kk[4], j, kk[3]+kk[4])
         Ckm[ik,im] += 8 * pi^2 * (-1)^(mm[1]+mm[2]-kk[1]-kk[2]) / (2*j+1) *
                       cg(ll[1], mm[1], ll[2], mm[2], j, mm[1]+mm[2]) *
                       cg(ll[3], mm[3], ll[4], mm[4], j, mm[3]+mm[4]) *
                       cg(ll[1], kk[1], ll[2], kk[2], j, kk[1]+kk[2]) *
                       cg(ll[3], kk[3], ll[4], kk[4], j, kk[3]+kk[4])
      end
   end
   return Ckm
end


# CASE 1
ll1 = SVector(2,1,1,2)
Ckm = compute_Ckm(ll1)
@show rank(Ckm)
svdf = svd(Ckm)
@show svdf.S[1:5]
for i = 1:3
   @info("V[:,$i]")
   @show round.(svdf.Vt[i,:], digits=2)
end

# CASE 2
ll2 = SVector(2,3,4,3)
Ckm = compute_Ckm(ll2)
@show rank(Ckm)
@show svdvals(Ckm)[1:8]

# CASE 3
ll3 = SVector(5,4,4,3)
Ckm = compute_Ckm(ll3)
@show rank(Ckm)
@show svdvals(Ckm)[1:10]


# MAIN EXAMPLE:
ll = SVector(1,1,1,1)
Ckm = compute_Ckm(ll)
Ckm_sym = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 15.7914 0.0 -7.89568 -7.89568 2.63189 5.26379 2.63189 0.0 -7.89568 -7.89568 5.26379 10.5276 5.26379 -7.89568 -7.89568 0.0 2.63189 5.26379 2.63189 -7.89568 -7.89568 0.0 15.7914 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 2.63189 0.0 -7.89568 5.26379 15.7914 -7.89568 2.63189 0.0 5.26379 -7.89568 -7.89568 10.5276 -7.89568 -7.89568 5.26379 0.0 2.63189 -7.89568 15.7914 5.26379 -7.89568 0.0 2.63189 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 2.63189 0.0 5.26379 -7.89568 2.63189 -7.89568 15.7914 0.0 -7.89568 5.26379 -7.89568 10.5276 -7.89568 5.26379 -7.89568 0.0 15.7914 -7.89568 2.63189 -7.89568 5.26379 0.0 2.63189 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 10.5276 0.0 -5.26379 -5.26379 10.5276 -5.26379 10.5276 0.0 -5.26379 -5.26379 -5.26379 15.7914 -5.26379 -5.26379 -5.26379 0.0 10.5276 -5.26379 10.5276 -5.26379 -5.26379 0.0 10.5276 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 2.63189 0.0 5.26379 -7.89568 2.63189 -7.89568 15.7914 0.0 -7.89568 5.26379 -7.89568 10.5276 -7.89568 5.26379 -7.89568 0.0 15.7914 -7.89568 2.63189 -7.89568 5.26379 0.0 2.63189 0.0 0.0; 0.0 0.0 5.26379 0.0 -2.63189 -2.63189 -7.89568 10.5276 -7.89568 0.0 -2.63189 -2.63189 10.5276 -5.26379 10.5276 -2.63189 -2.63189 0.0 -7.89568 10.5276 -7.89568 -2.63189 -2.63189 0.0 5.26379 0.0 0.0; 0.0 0.0 2.63189 0.0 -7.89568 5.26379 15.7914 -7.89568 2.63189 0.0 5.26379 -7.89568 -7.89568 10.5276 -7.89568 -7.89568 5.26379 0.0 2.63189 -7.89568 15.7914 5.26379 -7.89568 0.0 2.63189 0.0 0.0; 0.0 0.0 -7.89568 0.0 -2.63189 10.5276 5.26379 -2.63189 -7.89568 0.0 10.5276 -2.63189 -2.63189 -5.26379 -2.63189 -2.63189 10.5276 0.0 -7.89568 -2.63189 5.26379 10.5276 -2.63189 0.0 -7.89568 0.0 0.0; 0.0 0.0 -7.89568 0.0 10.5276 -2.63189 -7.89568 -2.63189 5.26379 0.0 -2.63189 10.5276 -2.63189 -5.26379 -2.63189 10.5276 -2.63189 0.0 5.26379 -2.63189 -7.89568 -2.63189 10.5276 0.0 -7.89568 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 15.7914 0.0 -7.89568 -7.89568 2.63189 5.26379 2.63189 0.0 -7.89568 -7.89568 5.26379 10.5276 5.26379 -7.89568 -7.89568 0.0 2.63189 5.26379 2.63189 -7.89568 -7.89568 0.0 15.7914 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]

badI = [1,2,4,10, 18, 24, 26, 27]
goodI = setdiff(1:27, badI)
Ckm_sym = Ckm_sym[goodI, goodI]


display(Ckm_sym[:, [1,2,3]])
display(Ckm[:, [1,2,3]])

norm(Ckm_sym - Ckm, Inf)
svdvals(Ckm)
svdvals(Ckm_sym)

ll = SVector(2,1,1,1)
Ckm = compute_Ckm(ll)
rank(Ckm)
c1 = Ckm[:,1]
c2 = Ckm[:,3]
c1 /= norm(c1)
c2 /= norm(c2)
[sort(c1) sort(c2)]

U = svd(Ckm).U[:,1:2]
[ sort(U[:,1]) sort(U[:,2]) ]
U' * U

svd(Ckm)

for l = 1:6
   ll = SVector(l,l,l,l)
   Ckm = compute_Ckm(ll)
   @show l, rank(Ckm)
end
