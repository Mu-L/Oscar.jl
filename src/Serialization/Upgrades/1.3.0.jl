function upgrade_QSMModel(d::Dict)
  upgraded_dict = d
  upgraded_dict[:_type] = Dict(
    :name => d[:_type],
    :params => Dict(
      :hs_model => d[:data][:hs_model][:_type],
      :genus_ci => d[:data][:genus_ci][:_type],
      :degree_of_Kbar_of_tv_restricted_to_ci => d[:data][:degree_of_Kbar_of_tv_restricted_to_ci][:_type]
    ))
  upgraded_dict[:data][:hs_model] = d[:data][:hs_model][:data]
  upgraded_dict[:data][:genus_ci] = d[:data][:genus_ci][:data]
  upgraded_dict[:data][:degree_of_Kbar_of_tv_restricted_to_ci] = d[:data][:degree_of_Kbar_of_tv_restricted_to_ci][:data]

  return upgraded_dict
end

push!(upgrade_scripts_set, UpgradeScript(
  v"1.3.0",
  function upgrade_1_3_0(s::UpgradeState, dict::Dict)
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
        d = Dict()
        for (k, v) in dict[:_type][:params]
          if k == :key_type
            d[k] = v
          else
            d[k] = upgrade_1_3_0(s, Dict(
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
            upgraded_dict[:_type][:params][k] = v
          else
            upgraded_dict[:_type][:params][k] = v[:_type]
            upgraded_dict[:data][k] = v[:data]
          end
        end
      elseif type_name in ["Vector", "Set", "Matrix"]
        subtype = dict[:_type][:params]
        upgraded_entries = []
        for entry in dict[:data]
          push!(upgraded_entries, upgrade_1_3_0(s, Dict(
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
          push!(upgraded_subtypes, upgrade_1_3_0(s, Dict(
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
        if !(dict[:_type][:params] isa Dict)
          upgraded_subdict = upgrade_1_3_0(s, dict[:data])
          upgraded_subdict[:_type][:params][:key_type] = "Symbol"
          field = nothing

          for (k, v) in s.id_to_dict
            if v[:_type] == "EmbeddedNumField"
              field = k
            end
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
                
      elseif type_name == "FPGroup"
        if haskey(dict[:data][:X], :freeGroup)
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
      elseif type_name == "PcGroup"
        if haskey(dict[:data][:X], :fullGroup)
          upgraded_dict[:_type] = Dict(
            :name => type_name,
            :params => dict[:data][:X][:fullGroup]
          )
        #elseif haskey(dict[:data][:X], :wholeGroup)
          #upgraded_dict[:_type] = Dict(
            #:name => type_name,
            #:params => dict[:data][:X][:wholeGroup]
          #)
          #
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

      elseif type_name == "GAP.GapObj"
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
        
      elseif type_name in [
        "AbsPowerSeriesRingElem", "PolyRingElem", "MPolyRingElem", "MPolyDecRingElem",
        "AbsPowerSeriesRingElem", "RelPowerSeriesRingElem",
        "UniversalPolyRingElem",
        "NormalToricVariety",
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
        "ZZRingElem"
        ]
        # do nothing
        
      else
        println(json(dict, 2))
        error("$type_name doesn't have upgrade")
      end
    elseif haskey(dict, :data) && dict[:data] isa Dict
      upgraded_dict[:data] = upgrade_1_3_0(s, dict[:data])
    end

    if haskey(dict, :_refs)
      upgraded_refs = Dict()
      for (k, v) in dict[:_refs]
        upgraded_refs[k] = upgrade_1_3_0(s, v)
      end
      upgraded_dict[:_refs] = upgraded_refs
    end
    #println(json(upgraded_dict, 2))
    return upgraded_dict
  end
))
