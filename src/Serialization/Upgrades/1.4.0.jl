push!(upgrade_scripts_set, UpgradeScript(
  v"1.4.0",
  function upgrade_1_4_0(s::UpgradeState, dict::Dict)
    if haskey(dict, :_refs)
      s.id_to_dict = dict[:_refs]
    end
    if haskey(dict, :_ns)
      if haskey(dict[:_ns], :polymake)
        return dict
      end
    end
    if haskey(dict, :_type)
      if dict[:_type] isa Dict && haskey(dict[:_type], :name)
        type_name = dict[:_type][:name]
      else
        type_name = dict[:_type]
      end
      upgraded_dict = dict
      if type_name in [
        "PolyRing", "FreeAssociativeAlgebra", "MPolyRing", "RationalFunctionField",
        "AbstractAlgebra.Generic.LaurentMPolyWrapRing", "UniversalPolyRing",
        ]
        if dict[:data] isa String
          # do nothing
        else
          upgraded_dict[:_type] = Dict(
            :name => dict[:_type],
            :params => dict[:data][:base_ring]
          )
          upgraded_dict[:data] = Dict(
            :symbols => dict[:data][:symbols],
          )
        end
      elseif type_name == "QSMModel"
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => Dict(
            :hs_model => dict[:data][:hs_model][:_type],
            :genus_ci => dict[:data][:genus_ci][:_type],
            :degree_of_Kbar_of_tv_restricted_to_ci => dict[:data][:degree_of_Kbar_of_tv_restricted_to_ci][:_type]
          ))
        upgraded_dict[:data][:hs_model] = dict[:data][:hs_model][:data]
        upgraded_dict[:data][:genus_ci] = dict[:data][:genus_ci][:data]
        upgraded_dict[:data][:degree_of_Kbar_of_tv_restricted_to_ci] = dict[:data][:degree_of_Kbar_of_tv_restricted_to_ci][:data]

      elseif type_name == "AbstractLieAlgebra"
        println(json(dict, 2))
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => Dict(
            :base_ring => dict[:data][:base_ring],
            :root_system => dict[:data][:root_system]
        ))
        upgraded_dict[:attrs] = dict[:data][:attrs]
      elseif type_name in [
        "FracField", "LaurentSeriesField", "SeriesRing", "LaurentSeriesRing"
        ]
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => dict[:data][:base_ring]
        )
        delete!(dict, :base_ring)
        upgraded_dict[:data] = dict[:data]
      elseif type_name in ["MatSpace", "SMatSpace"]
        upgraded_dict[:_type] = Dict(
          :name => type_name,
          :params => upgraded_dict[:data][:base_ring]
        )
        upgraded_dict[:data] = Dict(
          :ncols => upgraded_dict[:data][:ncols],
          :nrows => upgraded_dict[:data][:nrows]
        )
      elseif type_name == "fqPolyRepField"
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => dict[:data][:def_pol][:_type][:params]
        )
        upgraded_dict[:data] = dict[:data][:def_pol][:data]
      elseif type_name == "MPolyDecRing"
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => Dict(
            :ring => dict[:data][:ring],
            :grading_group => dict[:data][:grading][:_type][:params]
          )
        )
        upgraded_dict[:data] = dict[:data][:grading][:data]
      elseif type_name in ["AbsSimpleNumField", "Hecke.RelSimpleNumField"]
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => dict[:data][:def_pol][:_type][:params]
        )
        upgraded_dict[:data] = Dict(
          :var => dict[:data][:var],
          :def_pol => dict[:data][:def_pol][:data]
        )
      elseif type_name in ["AbsNonSimpleNumField", "Hecke.RelNonSimpleNumField"]
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => dict[:data][:def_pols][:_type][:params]
        )
        upgraded_dict[:data] = Dict(
          :vars => dict[:data][:vars],
          :def_pols => dict[:data][:def_pols][:data]
        )

      elseif type_name == "EmbeddedNumField"
        upgraded_dict[:_type] = Dict(
          :name => dict[:_type],
          :params => dict[:data][:embedding]
        )
        upgraded_dict[:data] = []
      elseif type_name == "FqField"
        if dict[:data] isa Dict
          upgraded_dict[:_type] = Dict(
            :name => dict[:_type],
            :params => dict[:data][:def_pol][:_type][:params]
          )
          upgraded_dict[:data] = dict[:data][:def_pol][:data]
        end
      elseif type_name == "Dict"
        if haskey(dict[:_type][:params], :value_type)
          if haskey(dict[:_type][:params], :value_params)
            value_params = dict[:_type][:params][:value_params]
          else
            value_params = dict[:_type][:params][:value_type]
          end

          if haskey(dict[:_type][:params], :key_params)
            key_params = dict[:_type][:params][:key_params]
          else
            key_params = dict[:_type][:params][:key_type]
          end

          upgraded_dict[:_type][:params] = Dict(
            :value_params => value_params,
            :key_params => key_params
          )

        else
          d = Dict()
          for (k, v) in dict[:_type][:params]
            if k == :key_type
              d[k] = v
            elseif k == :_coeff
              
            else
              d[k] = upgrade_1_4_0(s, Dict(
                :_type => dict[:_type][:params][k],
                :data => dict[:data][k]
              ))
            end
          end
          
          upgraded_dict = Dict(
            :_type => Dict(:name => "Dict", :params=>Dict()),
            :data => Dict()
          )
          for (k, v) in d
            if k == :key_type
              upgraded_dict[:_type][:params][:key_params] = v
            else
              upgraded_dict[:_type][:params][k] = v[:_type]
              upgraded_dict[:data][k] = v[:data]
            end
          end
        end
      elseif type_name in ["Vector", "Set", "Matrix"]
        subtype = dict[:_type][:params]
        upgraded_entries = []
        for entry in dict[:data]
          entry isa String && break
          push!(upgraded_entries, upgrade_1_4_0(s, Dict(
            :_type => subtype,
            :data => entry
          )))
        end
        upgraded_dict[:data] = [e[:data] for e in upgraded_entries]
      elseif type_name == "NamedTuple"
        #println(json(dict, 2))
      elseif type_name == "Tuple"
        upgraded_subtypes = Dict[]
        for (i, subtype) in enumerate(dict[:_type][:params])
          push!(upgraded_subtypes, upgrade_1_4_0(s, Dict(
            :_type => subtype,
            :data => dict[:data][i]
          )))
        end
        upgraded_dict[:_type][:params] = [subdict[:_type] for subdict in upgraded_subtypes]
        upgraded_dict[:data] = [subdict[:data] for subdict in upgraded_subtypes]
      elseif type_name == "ZZLat"
        upgraded_dict[:_type] = Dict(
          :name => type_name,
          :params => Dict(
            :basis => dict[:data][:basis][:_type],
            :ambient_space => dict[:data][:ambient_space]
          )
        )
        upgraded_dict[:data] = dict[:data][:basis][:data]
      elseif type_name == "LinearProgram"
        if !(dict[:_type][:params] == "QQField")
          
        end
      elseif type_name == "MixedIntegerLinearProgram"
        if !(dict[:_type][:params] == "QQField")
          
        end
      elseif type_name in [
        "Polyhedron", "Cone", "PolyhedralComplex", "PolyhedralFan",
        "SubdivisionOfPoints"
        ]
        if !(dict[:_type][:params] isa Dict) || dict[:_type][:params][:_type] == "QQBarField"
          upgraded_subdict = upgrade_1_4_0(s, dict[:data])
          upgraded_subdict[:_type][:params][:key_params] = "Symbol"
          field = nothing

          for (k, v) in s.id_to_dict
            if v[:_type] == "EmbeddedNumField"
              field = k
            end
          end
          if isnothing(field)
            field = Dict(:_type => "QQBarField")
          end
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => Dict(
              :field => field,
              :pm_params => upgraded_subdict[:_type]
            )
          )
          upgraded_dict[:data] = upgraded_subdict[:data]
          upgraded_dict[:_type][:params][:pm_params][:params][:_polymake_type] = dict[:_type][:params][:pm_params][:params][:_type]
          upgraded_dict[:data][:_polymake_type] = dict[:data][:_type]
        end
      elseif type_name in [
        "Hecke.RelSimpleNumFieldEmbedding", "Hecke.RelNonSimpleNumFieldEmbedding"
        ]
        upgraded_dict[:_type] = Dict(
          :name => type_name,
          :params => Dict(
            :num_field => dict[:data][:num_field],
            :base_field_emb => dict[:data][:base_field_emb]
          )
        )
        upgraded_dict[:data] = dict[:data][:data][:data]
      elseif type_name in  [
        "Hecke.AbsSimpleNumFieldEmbedding", "Hecke.AbsNonSimpleNumFieldEmbedding"
        ]
        upgraded_dict[:_type] = Dict(
          :name => type_name,
          :params => dict[:data][:num_field]
        )
        upgraded_dict[:data] = dict[:data][:data][:data]
                
      elseif type_name in ["FPGroup", "SubFPGroup"]
        if dict[:data][:X] isa String
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => dict[:data][:X]
          )
        elseif haskey(dict[:data][:X], :freeGroup)
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => dict[:data][:X][:freeGroup]
          )
        elseif haskey(dict[:data][:X], :wholeGroup)
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => dict[:data][:X][:wholeGroup]
          )

        else
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => Dict(
              :_type => "GapObj",
              :data => dict[:data][:X]
            )
          )
          upgraded_dict[:data] = dict[:data][:X]
        end
      elseif type_name in ["PcGroup", "SubPcGroup"]
        if dict[:data][:X] isa String
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => dict[:data][:X]
          )
        elseif haskey(dict[:data][:X], :fullGroup)
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => dict[:data][:X][:fullGroup]
          )
        else
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => Dict(
              :_type => "GapObj",
              :data => dict[:data][:X]
            )
          )
          upgraded_dict[:data] = dict[:data][:X]
        end
        
      elseif type_name == "GAP.GapObj" || type_name == "GapObj"
        upgraded_dict[:_type] = "GapObj"
        if dict[:data] isa String
          #do nothing
        elseif haskey(dict[:data], :freeGroup)
          upgraded_dict[:_type] = Dict(
            :name => "GapObj",
            :params => dict[:data][:freeGroup]
          )
        elseif haskey(dict[:data], :fullGroup)
          upgraded_dict[:_type] = Dict(
            :name => "GapObj",
            :params => dict[:data][:fullGroup]
          )

        elseif haskey(dict[:data], :wholeGroup)
          upgraded_dict[:_type] = Dict(
            :name => "GapObj",
            :params => dict[:data][:wholeGroup]
          )
        end
      elseif type_name == "TropicalCurve"
        if haskey(dict[:data], :graph)
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => Dict(:_type => String, :data => "graph")
          )
          upgraded_dict[:data][:graph] = dict[:data][:graph][:data]
        else
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => dict[:data][:polyhedral_complex][:_type]
          )
          upgraded_dict[:data][:polyhedral_complex] = dict[:data][:polyhedral_complex][:data]
        end
      elseif type_name == "TropicalHypersurface"
        upgraded_dict[:_type] = Dict(
          :name => type_name,
          :params => dict[:data][:tropical_polynomial][:_type][:params]
        )
        upgraded_dict[:data] = dict[:data][:tropical_polynomial][:data]
      elseif type_name == "IdealGens"
        upgraded_dict[:_type] = Dict(
          :name => "IdealGens",
          :params => Dict(
            :base_ring => dict[:_type][:params],
            :ordering_type => dict[:data][:ordering][:internal_ordering][:_type]
          )
        )
        upgraded_dict[:data][:ordering][:internal_ordering] = dict[:data][:ordering][:internal_ordering][:data]

        if haskey(upgraded_dict[:data][:ordering][:internal_ordering], :ordering_symbol_as_type)
          upgraded_dict[:data][:ordering][:internal_ordering][:vars] = upgraded_dict[:data][:ordering][:internal_ordering][:vars][:data]
          upgraded_dict[:data][:ordering][:internal_ordering][:ordering_symbol_as_type] = upgraded_dict[:data][:ordering][:internal_ordering][:ordering_symbol_as_type][:data]
        end
      elseif type_name == "NormalToricVariety"
        if dict[:data] isa Dict
          upgraded_dict[:attrs] = dict[:data][:attrs]
          upgraded_dict[:data] = dict[:data][:pm_data]
        end
      elseif type_name == "CohomologyClass"
        upgraded_dict = Dict(
          :_type => dict[:_type],
          :data => dict[:data][:polynomial]
        )
      elseif type_name in ["WeightLattice", "WeylGroup"]
        upgraded_dict[:_type] = Dict(
          :name => type_name,
          :params => dict[:data][:root_system]
        )
      elseif type_name == "MPolyQuoRing"
        ord_data = dict[:data][:ordering]
        upgraded_dict[:_type] = Dict(
          :name => type_name,
          :params => Dict(
            :base_ring => ord_data[:_type][:params],
            :ordering => ord_data[:_type][:name]
          )
        )
        ord_data[:data][:internal_ordering] = ord_data[:data][:internal_ordering][:data]
        ord_data[:data][:internal_ordering][:vars] = ord_data[:data][:internal_ordering][:vars][:data]
        ord_data[:data][:internal_ordering][:ordering_symbol_as_type] = ord_data[:data][:internal_ordering][:ordering_symbol_as_type][:data]
        upgraded_dict[:data] = Dict(
          :ordering => ord_data[:data],
          :modulus => dict[:data][:modulus][:data]
        )
      elseif type_name in [
        "AbsPowerSeriesRingElem", "PolyRingElem", "MPolyRingElem", "MPolyDecRingElem",
        "AbsPowerSeriesRingElem", "RelPowerSeriesRingElem",
        "DualRootSpaceElem",
        "RootSystem",
        "UniversalPolyRingElem",
        "FinGenAbGroup", "AbstractAlgebra.Generic.LaurentMPolyWrap",
        "MPolyIdeal", "MatElem", "String", "Base.Int", "Bool", "Graph{Undirected}",
        "LaurentMPolyIdeal", "LaurentSeriesFieldElem",
        "Graph{Directed}", "Polymake.IncidenceMatrixAllocated{Polymake.NonSymmetric}",
        "Float64", "Float16", "Float32",
        "FpFieldElem",
        "fpFieldElem",
        "Hecke.QuadSpace",
        "LaurentSeriesRingElem",
        "PcGroupElem", "PermGroup", "PermGroupElem",
        "FreeAssociativeAlgebraIdeal",
        "FreeAssociativeAlgebraElem",
        "UInt8", "UInt16", "UInt32", "UInt64", "UInt128",
        "BigInt", "Int128", "Int16", "Int32", "Int8",
        "MPolyAnyMap",
        "FPGroupElem",
        "QQField", "QQFieldElem",
        "QQBarField",
        "RootSpaceElem",
        "SubFPGroupElem",
        "SubPcGroupElem",
        "Matroid",
        "SMat",
        "SimplicialComplex",
        "Symbol",
        "TropicalSemiringElem",
        "ToricDivisor",
        "FqFieldElem",
        "ZZModRingElem",
        "Nemo.ZZModRing",
        "zzModRingElem",
        "Nemo.zzModRing",
        "ZZRing",
        "ZZRingElem",
        "WeightLatticeElem",
        "WeylGroupElem",
        "ToricDivisorClass"
        ]
        # do nothing
        
      else
        println(json(dict, 2))
        error("$type_name doesn't have upgrade")
      end
    elseif haskey(dict, :data) && dict[:data] isa Dict
      upgraded_dict[:data] = upgrade_1_4_0(s, dict[:data])
    end

    if haskey(dict, :_refs)
      upgraded_refs = Dict()
      for (k, v) in dict[:_refs]
        upgraded_refs[k] = upgrade_1_4_0(s, v)
      end
      upgraded_dict[:_refs] = upgraded_refs
    end
    #println(json(upgraded_dict, 2))
    return upgraded_dict
  end
))
