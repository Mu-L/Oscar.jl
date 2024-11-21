push!(upgrade_scripts_set, UpgradeScript(
  v"1.2.1",
  function upgrade_1_2_1(s::UpgradeState, dict::Dict)
    upgraded_dict = dict
    if haskey(dict, :_type) && dict[:_type] == "FqField"
      if dict[:data] isa Dict
        if !(haskey(dict[:data], :def_pol))
          upgraded_dict[:data][:def_pol] = copy(dict[:data])
        end
      end
    elseif haskey(dict, :data) && dict[:data] isa Dict
      upgraded_dict[:data] = upgrade_1_2_1(s, dict[:data])
    end
    if haskey(dict, :_refs)
      upgraded_refs = Dict()
      for (k, v) in dict[:_refs]
        upgraded_refs[k] = upgrade_1_2_1(s, v)
      end
      upgraded_dict[:_refs] = upgraded_refs
    end

    return upgraded_dict
  end
))
