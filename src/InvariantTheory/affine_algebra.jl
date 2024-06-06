################################################################################
#
#  Presentation as affine algebra
#
################################################################################

@doc raw"""
    affine_algebra(IR::FinGroupInvarRing;
      algo_gens::Symbol = :default, algo_rels::Symbol = :groebner_basis)

Given an invariant ring `IR` with underlying graded polynomial ring, say `R`,
return a graded affine algebra, say `A`, together with a graded algebra
homomorphism `A` $\to$ `R` which maps `A` isomorphically onto `IR`.

!!! note
    If a system of fundamental invariants for `IR` is already cached, the function
    makes use of that system. Otherwise, such a system is computed and cached first.
    The algebra `A` is graded according to the degrees of the fundamental invariants,
    the modulus of `A` is generated by the algebra relations on these invariants, and
    the algebra homomorphism `A` $\to$ `R` is defined by sending the `i`-th
    generator of `A` to the `i`-th fundamental invariant.

# Optional arguments
Using the arguments `:king` or `:primary_and_secondary` for `algo_gens` selects
the algorithm for the computation of the fundamental invariants (see
[`fundamental_invariants`](@ref) for details).
The argument `:groebner_basis` or `:linear_algebra` for `algo_rels` controls
which algorithm for the computation of the relations between the fundamental
invariants is used. With `:groebner_basis`, the relations are computed via the
standard computation of a kernel of a morphism between multivariate polynomial
rings. The option `:linear_algebra` uses an algorithm by Kemper and Steel
[KS99](@cite), Section 17.5.5, to compute the relations without the use of Groebner
bases. Note that this option is only available, if the fundamental invariants
are computed via primary and secondary invariants (i.e.
`algo_gens = :primary_and_secondary`).

!!! note
    If a presentation of `IR` is already computed (and hence cached), this cached
    presentation will be returned and the values of `algo_gens` and `algo_rels`
    will be ignored.
    Further, if fundamental invariants are already computed and cached, the value
    of `algo_gens` might be ignored, as the cached system is used.

# Examples
```jldoctest
julia> K, a = cyclotomic_field(3, "a")
(Cyclotomic field of order 3, a)

julia> M1 = matrix(K, [0 0 1; 1 0 0; 0 1 0])
[0   0   1]
[1   0   0]
[0   1   0]

julia> M2 = matrix(K, [1 0 0; 0 a 0; 0 0 -a-1])
[1   0        0]
[0   a        0]
[0   0   -a - 1]

julia> G = matrix_group(M1, M2)
Matrix group of degree 3
  over cyclotomic field of order 3

julia> IR = invariant_ring(G)
Invariant ring
  of matrix group of degree 3 over K

julia> affine_algebra(IR)
(Quotient of multivariate polynomial ring by ideal (9*y1^6 + y1^3*y2^3 - 6*y1^3*y2*y3 + 3*y1^3*y4 - y2*y3*y4 + y3^3 + y4^2), Hom: quotient of multivariate polynomial ring -> graded multivariate polynomial ring)
```
"""
function affine_algebra(
  IR::FinGroupInvarRing; algo_gens::Symbol=:default, algo_rels::Symbol=:groebner_basis
)
  if !isdefined(IR, :presentation)
    if algo_gens == :king && algo_rels == :linear_algebra
      error(
        "Combination of arguments :$(algo_gens) for algo_gens and :$(algo_rels) for algo_rels not possible"
      )
    end

    if algo_rels == :groebner_basis
      _, IR.presentation = relations_via_groebner_basis(IR, algo_gens)
    elseif algo_rels == :linear_algebra
      _, IR.presentation = relations_via_linear_algebra(IR)
    else
      error("Unsupported argument :$(algo_rels) for algo_rels")
    end
  end
  return domain(IR.presentation), IR.presentation
end

################################################################################
#
#  Relations
#
################################################################################

function relations_via_groebner_basis(
  RG::FinGroupInvarRing, algo_fundamental::Symbol=:default
)
  R = polynomial_ring(RG)
  fund_invars = fundamental_invariants(RG, algo_fundamental)

  S = RG.fundamental.S
  StoR = hom(S, R, fund_invars)
  I = kernel(StoR)
  Q, StoQ = quo(S, I)
  QtoR = hom(Q, R, fund_invars)
  return Q, QtoR
end

function relations_via_linear_algebra(RG::FinGroupInvarRing)
  fund_invars = fundamental_invariants(RG, :primary_and_secondary)
  @assert RG.fundamental.via_primary_and_secondary "Cached fundamental invariants do not come from primary and secondary invariants"

  Q, QtoR = relations_primary_and_irreducible_secondary(RG)

  T = base_ring(Q)
  S = RG.fundamental.S

  TtoS = hom(T, S, [RG.fundamental.toS[QtoR(gen(Q, i))] for i in 1:ngens(T)])

  I = TtoS(modulus(Q))

  QS, StoQS = quo(S, I)
  QStoR = hom(QS, polynomial_ring(RG), fund_invars)
  return QS, QStoR
end

# Relations between primary and irreducible secondary invariants, see
# [KS99, Section 17.5.5] or [DK15, Section 3.8.3].
function relations_primary_and_irreducible_secondary(RG::FinGroupInvarRing)
  Rgraded = polynomial_ring(RG)
  R = forget_grading(Rgraded)
  K = coefficient_ring(R)

  p_invars = [f.f for f in primary_invariants(RG)]
  s_invars = [f.f for f in secondary_invariants(RG)]
  is_invars = [f.f for f in irreducible_secondary_invariants(RG)]
  s_invars_cache = RG.secondary

  np = length(p_invars)

  w = append!([total_degree(f) for f in p_invars], [total_degree(f) for f in is_invars])
  S, t = graded_polynomial_ring(K, "t" => 1:(np + length(is_invars)), w)

  if isempty(is_invars)
    I = ideal(S, elem_type(S)[])
    Q, StoQ = quo(S, I)
    QtoR = hom(Q, Rgraded, primary_invariants(RG))
    return Q, QtoR
  end

  RtoS = Vector{elem_type(S)}(undef, np + length(s_invars))
  for i in 1:np
    RtoS[i] = t[i]
  end
  for i in 1:length(s_invars)
    exps = append!(zeros(Int, np), s_invars_cache.sec_in_irred[i])
    g = set_exponent_vector!(one(S), 1, exps)
    RtoS[np + i] = g
  end

  # Build all products g*h of secondary invariants g and irreducible secondary
  # invariants h

  # Assumes that s_invars and is_invars are sorted by degree
  maxd = total_degree(s_invars[end]) + total_degree(is_invars[end])
  products_sorted = Vector{Vector{Tuple{elem_type(R),elem_type(S)}}}(undef, maxd)
  for d in 1:maxd
    products_sorted[d] = Vector{Tuple{elem_type(R),elem_type(S)}}()
  end
  for i in 1:length(s_invars)
    for j in 1:length(s_invars)
      if !s_invars_cache.is_irreducible[j]
        continue
      end
      if s_invars_cache.is_irreducible[i] && i > j
        continue
      end
      m = RtoS[np + i] * RtoS[np + j]
      if m in RtoS
        continue
      end
      f = s_invars[i] * s_invars[j]
      push!(products_sorted[total_degree(f)], (f, m))
    end
  end

  # Find relations of the form g*h - f_{g, h} where g*h is one of the products
  # above and f_{g, h} is in the module generated by the secondary invariants
  # over the algebra generated by the primary invariants

  rels = elem_type(S)[]
  C = PowerProductCache(R, p_invars)
  for d in 1:maxd
    if isempty(products_sorted[d])
      continue
    end

    gensd, expsd = generators_for_given_degree!(C, s_invars, d, true)

    monomial_to_column = enumerate_monomials(gensd)

    M = polys_to_smat(gensd, monomial_to_column; copy=false)

    N = polys_to_smat([t[1] for t in products_sorted[d]], monomial_to_column; copy=false)
    N.c = M.c

    # Write the products (in N) in the basis of K[V]^G_d given by the secondary
    # invariants (in M)
    x = solve(M, N; side=:left)

    # Translate the relations to the free algebra S
    for i in 1:nrows(x)
      s = -products_sorted[d][i][2]
      for j in 1:length(x.rows[i])
        m = S(x.rows[i].values[j])
        e = expsd[gensd[x.rows[i].pos[j]]]
        for k in 1:(np + length(s_invars))
          if iszero(e[k])
            continue
          end
          m *= RtoS[k]^e[k]
        end
        s += m
      end
      push!(rels, s)
    end
  end

  # In the modular case, RG might not be Cohen--Macaulay, so not free as a
  # module over the subalgebra generated by the primary invariants.
  if is_modular(RG)
    M, MtoR, AtoR = module_syzygies(RG)
    gens_np = gens(S)[1:np]
    for x in relations(M)
      f = S()
      for (i, c) in coordinates(x)
        cS = c(gens_np...)
        f += cS * RtoS[np + i]
      end
      push!(rels, f)
    end
  end

  I = ideal(S, rels)
  Q, StoQ = quo(S, I)
  QtoR = hom(
    Q,
    Rgraded,
    append!(primary_invariants(RG), irreducible_secondary_invariants(RG));
    check=false,
  )

  return Q, QtoR
end

################################################################################
#
#  Module syzygies
#
################################################################################

@doc raw"""
    module_syzygies(RG::FinGroupInvarRing)

Given an invariant ring `RG` over a ring `R`, compute a presentation of `RG` as
a module over the subalgebra generated by a system of primary invariants.
Return a module `M` over a ring `S`, a map `M \to R` which is onto `RG` by
mapping the generators of `M` to a system of secondary invariants, and a map
`S \to R` which is onto the subalgebra generated by the primary invariants.
"""
function module_syzygies(RG::FinGroupInvarRing)
  # Follow the strategy described in DK15, p. 110. That is:
  # Let S be the subalgebra generated by the primary invariants. We choose free
  # generators of R as an S-module, so we set up an isomorphism R \cong S^r for
  # some r. We then represent the secondary invariants as elements of S^r and
  # compute the relations of the respective submodule by the standard Gröbner
  # basis techniques for syzygies.

  # NOTE: It is not tested whether RG is known to be Cohen--Macaulay (for
  # example because we are in the non-modular case).

  Rgraded = polynomial_ring(RG)
  R = forget_grading(Rgraded)
  K = coefficient_ring(R)
  I = ideal_of_primary_invariants(RG)
  p_invars = map(forget_grading, primary_invariants(RG))
  s_invars = map(forget_grading, secondary_invariants(RG))

  # Compute free generators of R as a module over the primary invariants
  # This is the same as generators of the vector space R/I by Nakayama.
  r_gens = map(x -> forget_grading(Rgraded(x)), _kbase(quo(Rgraded, I)[1]))

  S, t = graded_polynomial_ring(
    K, length(p_invars), "t", [total_degree(f) for f in p_invars]
  )
  F = free_module(S, length(r_gens)) # isomorphic to R as an S-module

  # Represent the secondary invariants as elements of F
  s_invars_in_F = elem_type(F)[]
  C = PowerProductCache(R, p_invars)
  dmax = total_degree(s_invars[end])
  k = 1
  for d in 0:dmax
    # We assume that the secondary invariants are sorted by degree
    s_invars_d = elem_type(R)[]
    while k <= length(s_invars) && total_degree(s_invars[k]) == d
      push!(s_invars_d, s_invars[k])
      k += 1
    end

    isempty(s_invars_d) && continue

    # Build a K-vector space basis of the degree d component of F
    gens_d, exps_d = generators_for_given_degree!(C, r_gens, d)

    monomial_to_column = enumerate_monomials(gens_d)
    M = polys_to_smat(gens_d, monomial_to_column)
    N = polys_to_smat(s_invars_d, monomial_to_column)
    sol = solve(M, N; side=:left)

    for i in 1:length(s_invars_d)
      a = F()
      for (j, c) in sol[i]
        # Translate gens_d[j] to an element of F via exps_d[gens_d[j]]
        # The first "half" of indices corresponds to the primary invariants
        f = S([c], [exps_d[gens_d[j]][1:length(p_invars)]])
        # The second "half" of indices corresponds to r_gens
        g = F()
        for l in 1:rank(F)
          is_zero(exps_d[gens_d[j]][l + length(p_invars)]) && continue
          g += F[l]
        end
        a += f * g
      end
      push!(s_invars_in_F, a)
    end
  end

  # Set up the submodule of F generated by the secondary invariants and compute
  # a presentation for it
  N, _ = sub(F, s_invars_in_F)
  M = free_module(S, length(s_invars))
  phi = hom(M, N, gens(N))
  L, _ = kernel(phi)
  Q, MtoQ = quo(M, L)

  StoR = hom(S, Rgraded, primary_invariants(RG))

  # A bit cheated; this is not just the map from Q to R, but also from M to R,
  # to allow us to map the relations of Q back to R.
  function QtoR(x::Union{FreeModElem,SubquoModuleElem})
    @assert parent(x) === M || parent(x) === Q
    f = zero(Rgraded)
    for (i, c) in coordinates(x)
      f += StoR(c) * Rgraded(s_invars[i])
    end
    return f
  end

  return Q, QtoR, StoR
end
