################################################################################
# Common union types

const RingMatElemUnion = Union{RingElem, MatElem, FreeAssociativeAlgebraElem,
                               SMat, TropicalSemiringElem}
const RingMatSpaceUnion = Union{Ring, MatSpace, SMatSpace,
                                FreeAssociativeAlgebra, TropicalSemiring}
const ModRingUnion = Union{zzModRing, ZZModRing}

const PolyRingUnionType = Union{UniversalPolyRing,
                            MPolyRing,
                            PolyRing,
                            AbstractAlgebra.Generic.LaurentMPolyWrapRing}


################################################################################
# type_params functions

type_params(x::T) where T <: RingMatElemUnion = parent(x)
type_params(R::T) where T <: RingMatSpaceUnion = base_ring(R)
type_params(::ZZRing) = nothing
type_params(::T) where T <: ModRingUnion = nothing
type_params(x::T) where T <: Ideal = base_ring(x)

################################################################################
# ring of integers (singleton type)
@register_serialization_type ZZRing

################################################################################
#  Mod Rings
@register_serialization_type Nemo.zzModRing
@register_serialization_type Nemo.ZZModRing

function save_object(s::SerializerState, R::T) where T <: ModRingUnion
  save_object(s, modulus(R))
end

function load_object(s::DeserializerState, ::Type{zzModRing})
  modulus = load_object(s, UInt64)
  return zzModRing(modulus)
end

function load_object(s::DeserializerState, ::Type{ZZModRing})
  modulus = load_object(s, ZZRingElem)
  return ZZModRing(modulus)
end

#elements
@register_serialization_type zzModRingElem uses_params
@register_serialization_type ZZModRingElem uses_params
const ModRingElemUnion = Union{zzModRingElem, ZZModRingElem}

function save_object(s::SerializerState, x::ModRingElemUnion)
  save_data_basic(s, string(x))
end

function load_object(s::DeserializerState, ::Type{<:ModRingElemUnion},
                     parent_ring::T) where T <: ModRingUnion
  return parent_ring(load_object(s, ZZRingElem, ZZRing()))
end

################################################################################
#  Polynomial Rings

@register_serialization_type PolyRing uses_id  uses_params
@register_serialization_type MPolyRing uses_id uses_params
@register_serialization_type UniversalPolyRing uses_id uses_params
@register_serialization_type MPolyDecRing uses_id uses_params
@register_serialization_type AbstractAlgebra.Generic.LaurentMPolyWrapRing uses_id uses_params

function save_object(s::SerializerState, R::PolyRingUnionType)
  base = base_ring(R)
  save_data_dict(s) do
    save_object(s, symbols(R), :symbols)
  end
end

function load_object(s::DeserializerState,
                     T::Type{<: PolyRingUnionType},
                     params::Ring)
  symbols = load_object(s, Vector, Symbol, :symbols)
  if T <: PolyRing
    return polynomial_ring(params, symbols..., cached=false)[1]
  elseif T <: UniversalPolyRing
    poly_ring = universal_polynomial_ring(params, cached=false)
    gens(poly_ring, symbols)
    return poly_ring
  elseif T <: AbstractAlgebra.Generic.LaurentMPolyWrapRing
    return laurent_polynomial_ring(params, symbols, cached=false)[1]
  end
  return polynomial_ring(params, symbols, cached=false)[1]
end

# with grading

function save_object(s::SerializerState, R::MPolyDecRing)
  save_data_dict(s) do
    save_typed_object(s, _grading(R), :grading)
    save_typed_object(s, forget_grading(R), :ring)
  end
end

function load_object(s::DeserializerState, ::Type{<:MPolyDecRing})
  ring = load_typed_object(s, :ring)
  grading = load_typed_object(s, :grading)
  return grade(ring, grading)[1]
end

################################################################################
#  Polynomial Ring Elem Types
@register_serialization_type MPolyRingElem uses_params
@register_serialization_type MPolyDecRingElem uses_params
@register_serialization_type UniversalPolyRingElem uses_params
@register_serialization_type AbstractAlgebra.Generic.LaurentMPolyWrap uses_params

# elements
function save_object(s::SerializerState, p::Union{UniversalPolyRingElem, MPolyRingElem})
  # we use this line instead of typeof(coeff(p, 1)) to catch the 0 polynomial
  coeff_type = elem_type(base_ring(parent(p)))
  save_data_array(s) do
    for i in 1:length(p)
      save_data_array(s) do 
        save_object(s, map(string, exponent_vector(p, i)))
        save_object(s, coeff(p, i))
      end
    end
  end
end

function save_object(s::SerializerState, p::AbstractAlgebra.Generic.LaurentMPolyWrap)
  exponent_vectors_gen = AbstractAlgebra.exponent_vectors(p)
  index = 0
  save_data_array(s) do
    for c in coefficients(p)
      exponent_vector, index = iterate(exponent_vectors_gen, index)
      save_data_array(s) do
        save_object(s, map(string, exponent_vector))
        save_object(s, c)
      end
    end
  end
end

################################################################################
# Univariate Polynomials

@register_serialization_type PolyRingElem uses_params

function save_object(s::SerializerState, p::PolyRingElem)
  coeffs = coefficients(p)
  exponent = 0
  save_data_array(s) do
    for coeff in coeffs
      # collect only non trivial terms
      if is_zero(coeff)
        exponent += 1
        continue
      end
      save_data_array(s) do
        save_object(s, string(exponent))
        save_object(s, coeff)
      end
      exponent += 1
    end
  end
end

function load_object(s::DeserializerState, ::Type{<: PolyRingElem},
                     parent_ring::PolyRing)
  load_node(s) do terms
    if isempty(terms)
      return parent_ring(0)
    end
    # load exponents and account for shift
    exponents = []
    for i in 1:length(terms)
      e = load_node(s, i) do _
        load_object(s, Int, 1) + 1
      end
      push!(exponents, e)
    end
    degree = max(exponents...)
    base = base_ring(parent_ring)
    loaded_terms = zeros(base, degree)
    coeff_type = elem_type(base)
    for (i, exponent) in enumerate(exponents)
      load_node(s, i) do _
        load_node(s, 2) do _
          loaded_terms[exponent] = load_object(s, coeff_type, base)
        end
      end
    end
    return parent_ring(loaded_terms)
  end
end


function load_object(s::DeserializerState,
                     ::Type{<:Union{MPolyRingElem, UniversalPolyRingElem, AbstractAlgebra.Generic.LaurentMPolyWrap}},
                     parent_ring::PolyRingUnionType)
  load_node(s) do terms
    exponents = [term[1] for term in terms]
    base = base_ring(parent_ring)
    polynomial = MPolyBuildCtx(parent_ring)
    coeff_type = elem_type(base)
    for (i, e) in enumerate(exponents)
      load_node(s, i) do _
        c = load_object(s, coeff_type, base, 2)
        e_int = load_array_node(s, 1) do _
          load_object(s, Int)
        end
        push_term!(polynomial, c, e_int)
      end
    end
    return finish(polynomial)
  end
end

function load_object(s::DeserializerState, ::Type{<:MPolyDecRingElem}, parent_ring::MPolyDecRingElem)
  poly = load_object(s, MPolyRingElem, forget_grading(parent_ring))
  return parent_ring(poly)
end

################################################################################
# Polynomial Ideals

@register_serialization_type MPolyIdeal uses_params
@register_serialization_type LaurentMPolyIdeal uses_params

# we should avoid this list getting too long and find a
# way to abstract saving params soon
const IdealOrdUnionType = Union{MPolyIdeal,
                                LaurentMPolyIdeal,
                                FreeAssociativeAlgebraIdeal,
                                IdealGens,
                                MonomialOrdering}


function save_object(s::SerializerState, I::T) where T <: IdealOrdUnionType
  save_object(s, gens(I))
end

function load_object(s::DeserializerState, ::Type{<: IdealOrdUnionType}, parent_ring::RingMatSpaceUnion)
  gens = elem_type(parent_ring)[]
  load_array_node(s) do _
    push!(gens, load_object(s, elem_type(parent_ring), parent_ring))
  end
  return ideal(parent_ring, gens)
end

################################################################################
# IdealGens

# this will need adjustments to cover the NCRing case

@register_serialization_type IdealGens uses_params

function save_object(s::SerializerState, obj::IdealGens)
  save_data_dict(s) do
    save_object(s, ordering(obj), :ordering)
    save_object(s, gens(obj), :gens)
    save_object(s, is_groebner_basis(obj), :is_gb)
    save_object(s, obj.isReduced, :is_reduced)
    save_object(s, obj.keep_ordering, :keep_ordering)
  end
end

function load_object(s::DeserializerState, ::Type{<:IdealGens}, base_ring::MPolyRing)
  ord = load_object(s, MonomialOrdering, base_ring, :ordering)
  generators = load_object(s, Vector{MPolyRingElem}, base_ring, :gens)
  is_gb = load_object(s, Bool, :is_gb)
  is_reduced = load_object(s, Bool, :is_reduced)
  keep_ordering = load_object(s, Bool, :keep_ordering)
  return IdealGens(base_ring, generators, ord;
                   keep_ordering=keep_ordering,
                   isReduced=is_reduced,
                   isGB=is_gb)
end

################################################################################
# Matrices
@register_serialization_type MatSpace uses_id
@register_serialization_type MatElem uses_params
@register_serialization_type SMatSpace uses_id
@register_serialization_type SMat uses_params

function save_object(s::SerializerState, obj::MatSpace)
  save_data_dict(s) do
    save_typed_object(s, base_ring(obj), :base_ring)
    save_object(s, ncols(obj), :ncols)
    save_object(s, nrows(obj), :nrows)
  end
end

function save_object(s::SerializerState, obj::SMatSpace)
  save_data_dict(s) do
    save_typed_object(s, base_ring(obj), :base_ring)
    # getters currently do not seem to exist
    save_object(s, obj.cols, :ncols)
    save_object(s, obj.rows, :nrows)
  end
end

function load_object(s::DeserializerState, ::Type{<:Union{MatSpace, SMatSpace}})
  base_ring = load_typed_object(s, :base_ring)
  ncols = load_object(s, Int, :ncols)
  nrows = load_object(s, Int, :nrows)
  return matrix_space(base_ring, nrows, ncols)
end

# elems
function save_object(s::SerializerState, obj::MatElem)
  save_object(s, Array(obj))
end

function save_object(s::SerializerState, obj::SMat)
  save_data_array(s) do
    for r in obj
      save_object(s, collect(r))
    end
  end
end

function load_object(s::DeserializerState, ::Type{<:MatElem}, parents::Vector)
  parent = parents[end]
  T = elem_type(base_ring(parent))
  if serialize_with_params(T)
    if length(parents) == 1
      params = base_ring(parent)
    else
      params = parents[1:end - 1]
    end
    m = load_object(s, Matrix, (T, params))
  else
    m = load_object(s, Matrix, T)
  end
  if isempty(m)
    return parent()
  end
  return parent(m)
end

function load_object(s::DeserializerState, ::Type{<:SMat}, parents::Vector)
  parent = parents[end]
  base = base_ring(parent)
  T = elem_type(base)
  M = sparse_matrix(base)

  if serialize_with_params(T)
    if length(parents) == 1
      params = base_ring(parent)
    else
      params = parents[1:end - 1]
    end

    load_array_node(s) do _
      row_entries = Tuple{Int, T}[]
      load_array_node(s) do _
        push!(row_entries, load_object(s, Tuple, [Int, (T, params)]))
      end
      push!(M, sparse_row(base, row_entries))
    end
  else
    load_array_node(s) do _
      row_entries = Tuple{Int, T}[]
      load_array_node(s) do _
        push!(row_entries, load_object(s, Tuple, [Int, T]))
      end
      push!(M, sparse_row(base, row_entries))
    end
  end
  return M
end

################################################################################
# Power Series
@register_serialization_type SeriesRing uses_id
const RelPowerSeriesUnionType = Union{ Generic.RelPowerSeriesRing,
                                       QQRelPowerSeriesRing,
                                       ZZRelPowerSeriesRing,
                                       fqPolyRepRelPowerSeriesRing,
                                       FqRelPowerSeriesRing,
                                       zzModRelPowerSeriesRing}
const AbsPowerSeriesUnionType = Union{ Generic.AbsPowerSeriesRing,
                                       QQAbsPowerSeriesRing,
                                       ZZAbsPowerSeriesRing,
                                       FqAbsPowerSeriesRing,
                                       fqPolyRepAbsPowerSeriesRing,
                                       zzModAbsPowerSeriesRing}

function save_object(s::SerializerState, R::RelPowerSeriesUnionType)
  save_data_dict(s) do
    save_typed_object(s, base_ring(R), :base_ring)
    save_object(s, var(R), :var)
    save_object(s, max_precision(R), :max_precision)
    save_object(s, :capped_relative, :model)
  end
end

function save_object(s::SerializerState, R::AbsPowerSeriesUnionType)

  save_data_dict(s) do
    save_typed_object(s, base_ring(R), :base_ring)
    save_object(s, var(R), :var)
    save_object(s, max_precision(R), :max_precision)
    save_object(s, :capped_absolute, :model)
  end
end

function load_object(s::DeserializerState, ::Type{<: SeriesRing})
  base_ring = load_typed_object(s, :base_ring)
  var = load_object(s, Symbol, :var)
  max_precision = load_object(s, Int, :max_precision)
  model = load_object(s, Symbol, :model)
  
  return power_series_ring(base_ring, max_precision, var; cached=false, model=model)[1]
end

# elements
@register_serialization_type RelPowerSeriesRingElem uses_params
@register_serialization_type AbsPowerSeriesRingElem uses_params

function save_object(s::SerializerState, r::RelPowerSeriesRingElem)
  v = valuation(r)
  pl = pol_length(r)
  encoded_terms = []
  save_data_dict(s) do
    save_data_array(s, :terms) do
      for exponent in v: v + pl
        coefficient = coeff(r, exponent)
        #collect only non trivial values
        if is_zero(coefficient)
          continue
        end

        save_data_array(s) do
          save_object(s, exponent)
          save_object(s, coefficient)
        end
      end
    end
    save_object(s, pl, :pol_length)
    save_object(s, precision(r), :precision)
    save_object(s, v, :valuation)
  end
end

function save_object(s::SerializerState, r::AbsPowerSeriesRingElem)
  pl = pol_length(r)
  encoded_terms = []
  parents = []
  parent_ring = parent(r)
  save_data_dict(s) do
    save_data_array(s, :terms) do
      for exponent in 0:pl
        coefficient = coeff(r, exponent)
        #collect only non trivial values
        if is_zero(coefficient)
          continue
        end
        save_data_array(s) do
          save_object(s, exponent)
          save_object(s, coefficient)
        end
      end
    end
    save_object(s, pl, :pol_length)
    save_object(s, precision(r),:precision)
  end
end

function load_object(s::DeserializerState, ::Type{<:RelPowerSeriesRingElem},
                     parent_ring::RelPowerSeriesUnionType)
  valuation = load_object(s, Int, :valuation)
  pol_length = load_object(s, Int, :pol_length)
  precision = load_object(s, Int, :precision)
  base = base_ring(parent_ring)
  loaded_terms = zeros(base, pol_length)
  coeff_type = elem_type(base)
  
  load_node(s, :terms) do _
    load_array_node(s) do _
      e = load_object(s, Int, 1)
      loaded_terms[e] = load_object(s, coeff_type, base, 2)
    end
  end
  return parent_ring(loaded_terms, pol_length, precision, valuation)
end

function load_object(s::DeserializerState, ::Type{<:AbsPowerSeriesRingElem}, parents::Vector)
  parent_ring = parents[end]
  pol_length = load_object(s, Int, :pol_length)
  precision = load_object(s, Int, :precision)
  base = base_ring(parent_ring)
  loaded_terms = zeros(base, pol_length)
  coeff_type = elem_type(base)

  load_node(s, :terms) do _
    load_array_node(s) do _
      e = load_object(s, Int, 1)
      loaded_terms[e + 1] = load_object(s, coeff_type, base, 2)
    end
  end
  return parent_ring(loaded_terms, pol_length, precision)
end

################################################################################
# Laurent Series
@register_serialization_type Generic.LaurentSeriesRing "LaurentSeriesRing" uses_id
@register_serialization_type Generic.LaurentSeriesField "LaurentSeriesField" uses_id
@register_serialization_type ZZLaurentSeriesRing uses_id
const LaurentUnionType = Union{ Generic.LaurentSeriesRing, Generic.LaurentSeriesField, ZZLaurentSeriesRing}

function save_object(s::SerializerState, R::LaurentUnionType)
  save_data_dict(s) do
    save_typed_object(s, base_ring(R), :base_ring)
    save_object(s, var(R), :var)
    save_object(s, max_precision(R), :max_precision)
  end
end

function load_object(s::DeserializerState,
                     ::Type{<: LaurentUnionType})
  base_ring = load_typed_object(s, :base_ring)
  var = load_object(s, Symbol, :var)
  max_precision = load_object(s, Int, :max_precision)

  return laurent_series_ring(base_ring, max_precision, var; cached=false)[1]
end

# elements
@register_serialization_type Generic.LaurentSeriesFieldElem "LaurentSeriesFieldElem" uses_params
@register_serialization_type Generic.LaurentSeriesRingElem "LaurentSeriesRingElem" uses_params
@register_serialization_type ZZLaurentSeriesRingElem uses_params

function save_object(s::SerializerState, r:: Union{Generic.LaurentSeriesElem, ZZLaurentSeriesRingElem})
  v = valuation(r)
  pl = pol_length(r)
  encoded_terms = []
  save_data_dict(s) do
    save_data_array(s, :terms) do
      for exponent in v: v + pl
        coefficient = coeff(r, exponent)
        #collect only non trivial values
        if is_zero(coefficient)
          continue
        end

        save_data_array(s) do
          save_object(s, exponent)
          save_object(s, coefficient)
        end
      end
    end
    save_object(s, pl, :pol_length)
    save_object(s, precision(r), :precision)
    save_object(s, v, :valuation)
    save_object(s, Generic.scale(r), :scale)
  end
end

function load_object(s::DeserializerState,
                     ::Type{<: Union{Generic.LaurentSeriesElem, ZZLaurentSeriesRingElem}},
                     parent_ring::LaurentUnionType)
  terms = load_node(s, :terms) do terms_data
    exponents = []
    for i in 1:length(terms_data)
      load_node(s, i) do _
        push!(exponents, load_object(s, Int, 1))
      end
    end
    
    highest_degree = max(exponents...)
    lowest_degree = min(exponents...)
    base = base_ring(parent_ring)
    coeff_type = elem_type(base)
    # account for index shift
    loaded_terms = zeros(base, highest_degree - lowest_degree + 1)
    for (i, e) in enumerate(exponents)
      e -= lowest_degree - 1
      loaded_terms[e] = load_object(s, coeff_type, base, i)
    end
    return loaded_terms
  end
  valuation = load_object(s, Int, :valuation)
  pol_length = load_object(s, Int, :pol_length)
  precision = load_object(s, Int, :precision)
  scale = load_object(s, Int, :scale)
  return parent_ring(terms, pol_length, precision, valuation, scale)
end

### Affine algebras
@register_serialization_type MPolyQuoRing uses_id

function save_object(s::SerializerState, A::MPolyQuoRing)
  save_data_dict(s) do # Saves stuff in a JSON dictionary. This opens a `{`, puts stuff 
                       # inside there for the various keys and then closes it with `}`.
                       # It's not using Julia Dicts.
    save_typed_object(s, modulus(A), :modulus)
    save_typed_object(s, ordering(A), :ordering) # Does this already serialize???
  end
end

function load_object(s::DeserializerState, ::Type{MPolyQuoRing})
  I = load_typed_object(s, :modulus) 
  R = base_ring(I)
  o = load_typed_object(s, :ordering)
  return MPolyQuoRing(R, I, o)
end

### Serialization of Monomial orderings
@register_serialization_type MonomialOrdering uses_params

function save_object(s::SerializerState, o::MonomialOrdering)
  save_data_dict(s) do
    save_object(s, o.o, :internal_ordering) # TODO: Is there a getter for this?
    if isdefined(o, :is_total)
      save_object(s, o.is_total, :is_total)
    end
  end
end

function load_object(s::DeserializerState, ::Type{MonomialOrdering}, ring::MPolyRing)
  # this will need to be changed to include other orderings, see below
  ord = load_object(s, Orderings.SymbOrdering, :internal_ordering)
  result = MonomialOrdering(ring, ord)

  if haskey(s, :is_total)
    result.is_total = load_object(s, Bool, :is_total)
  end
  return result
end

# we will need to extend this to more orderings at some point
@register_serialization_type Orderings.SymbOrdering

function save_object(s::SerializerState, o::Orderings.SymbOrdering{S}) where {S}
  save_data_dict(s) do
    save_object(s, S, :ordering_symbol_as_type)
    save_object(s, o.vars, :vars) # TODO: Is there a getter?
  end
end

function load_object(s::DeserializerState, ::Type{Orderings.SymbOrdering})
  S = load_object(s, Symbol, :ordering_symbol_as_type)
  vars = load_object(s, Vector{Int}, :vars) # are these always Vector{Int} ?
  return Orderings.SymbOrdering(S, vars)
end
