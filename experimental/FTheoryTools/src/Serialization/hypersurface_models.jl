@register_serialization_type HypersurfaceModel uses_id [
  :Kbar3,
  :_ambient_space_base_divisor_pairs_to_be_considered,
  :_ambient_space_divisor_pairs_to_be_considered,
  :ambient_space_models_of_g4_fluxes,
  :ambient_space_models_of_g4_fluxes_indices,
  :associated_literature_models,
  :birational_literature_models,
  :chern_classes,
  :classes_of_model_sections,
  :classes_of_tunable_sections_in_basis_of_Kbar_and_defining_classes,
  :components_of_dual_graph,
  :components_of_simplified_dual_graph,
  :degree_of_Kbar_of_tv_restricted_to_ci,
  :degree_of_Kbar_of_tv_restricted_to_components_of_dual_graph,
  :degree_of_Kbar_of_tv_restricted_to_components_of_simplified_dual_graph,
  :dual_graph,
  :estimated_number_of_triangulations,
  :euler_characteristic,
  :g4_flux_tuple_list,
  :gauge_algebra,
  :generating_sections,
  :genus_ci,
  :genus_of_components_of_dual_graph,
  :genus_of_components_of_simplified_dual_graph,
  :global_gauge_quotients,
  :h11,
  :h12,
  :h13,
  :h22,
  :index_facet_interior_divisors,
  :inter_dict,
  :intersection_number_among_ci_cj,
  :intersection_number_among_nontrivial_ci_cj,
  :is_calabi_yau,
  :literature_identifier,
  :matrix_integral_quant,
  :matrix_rational_quant,
  :matrix_integral_quant_transverse,
  :matrix_rational_quant_transverse,
  :matrix_integral_quant_transverse_nobreak,
  :matrix_rational_quant_transverse_nobreak,
  :max_lattice_pts_in_facet,
  :model_parameters,
  :model_sections,
  :partially_resolved,
  :poly_index,
  :resolutions,
  :resolution_generating_sections,
  :resolution_zero_sections,
  :s_inter_dict,
  :simplified_dual_graph,
  :torsion_sections,
  :triang_quick,
  :tunable_sections,
  :vertices,
  :weierstrass_model,
  :weighted_resolutions,
  :weighted_resolution_generating_sections,
  :weighted_resolution_zero_sections,
  :well_quantized_ambient_space_models_of_g4_fluxes,
  :well_quantized_and_vertical_ambient_space_models_of_g4_fluxes,
  :well_quantized_and_vertical_and_no_non_abelian_gauge_group_breaking_ambient_space_models_of_g4_fluxes,
  :well_quantized_and_vertical_integral,
  :well_quantized_and_vertical_rational,
  :well_quantized_integral,
  :well_quantized_rational,
  :well_quantized_vertical_no_break_integral,
  :well_quantized_vertical_no_break_rational,
  :zero_section,
  :zero_section_class,
  :zero_section_index,

  # these attributes should be moved into some form of meta data
  :arxiv_doi,
  :arxiv_id,
  :arxiv_link,
  :arxiv_model_equation_number,
  :arxiv_model_page,
  :arxiv_model_section,
  :arxiv_version,
  :journal_doi,
  :journal_link,
  :journal_model_equation_number,
  :journal_model_page,
  :journal_model_section,
  :journal_name,
  :journal_pages,
  :journal_report_numbers,
  :journal_volume,
  :journal_year,
  :model_description,
  :model_index,
  :paper_authors,
  :paper_buzzwords,
  :paper_description,
  :paper_title,
]



############################################################################
# This function saves the types of the data that define a hypersurface model
############################################################################

type_params(h::HypersurfaceModel) = TypeParams(
  HypersurfaceModel,
  :base_space => base_space(h),
  :ambient_space => ambient_space(h),
  :fiber_ambient_space => fiber_ambient_space(h),
  :hypersurface_equation_ring =>parent(hypersurface_equation(h)), 
  :hypersurface_equation_parametrization_ring => parent(hypersurface_equation_parametrization(h))
)

##########################################
# This function saves a hypersurface model
##########################################

function save_object(s::SerializerState, h::HypersurfaceModel)
  @req base_space(h) isa NormalToricVariety "Currently, we only serialize hypersurface models defined over a toric base space"
  @req ambient_space(h) isa NormalToricVariety "Currently, we only serialize hypersurface models defined within a toric ambient space"
  save_data_dict(s) do
    for (data, key) in [
        (explicit_model_sections(h), :explicit_model_sections),
        (defining_classes(h), :defining_classes),
        (model_section_parametrization(h), :model_section_parametrization)
        ]
      !isempty(data) && save_typed_object(s, data, key)
    end
    save_object(s, hypersurface_equation(h), :hypersurface_equation)
    save_object(s, hypersurface_equation_parametrization(h), :hypersurface_equation_parametrization)
  end
end


##########################################
# This function loads a hypersurface model
##########################################

function load_object(s::DeserializerState, ::Type{<:HypersurfaceModel}, params::Dict)
  base_space = params[:base_space]
  amb_space = params[:ambient_space]
  fiber_ambient_space = params[:fiber_ambient_space]
  R1 = params[:hypersurface_equation_ring]
  R2 = params[:hypersurface_equation_parametrization_ring]
  defining_equation = load_object(s, MPolyRingElem, R1, :hypersurface_equation)
  defining_equation_parametrization = load_object(s, MPolyRingElem, R2, :hypersurface_equation_parametrization)
  explicit_model_sections = haskey(s, :explicit_model_sections) ? load_typed_object(s, :explicit_model_sections) : Dict{String, MPolyRingElem}()
  defining_classes = haskey(s, :defining_classes) ? load_typed_object(s, :defining_classes) : Dict{String, ToricDivisorClass}()
  model_section_parametrization = haskey(s, :model_section_parametrization) ? load_typed_object(s, :model_section_parametrization) : Dict{String, MPolyRingElem}()
  model = HypersurfaceModel(explicit_model_sections, defining_equation_parametrization, defining_equation, base_space, amb_space, fiber_ambient_space)
  model.defining_classes = defining_classes
  model.model_section_parametrization = model_section_parametrization
  @req cox_ring(ambient_space(model)) == parent(hypersurface_equation(model)) "Hypersurface polynomial not in Cox ring of toric ambient space"

  # Refactor inter_dict to the type that is needed.
  # !!!!!!! We should add functionality for storing this types of tuples !!!!!!!
  
  # if haskey(attrs_data, :inter_dict)
  #   # We want this inter_dict to be of type Dict{NTuple{4, Int64}, ZZRingElem}().
  #   # Sadly, serializing and loading turns NTuple{4, Int64} into Tuple.
  #   # So we need to massage this... Not at all good, as it doubles memory usage!
  #   original_dict = attrs_data[:inter_dict]
  #   new_dict = Dict{NTuple{4, Int64}, ZZRingElem}()
  #   for (key, value) in original_dict
  #     new_key = NTuple{4, Int64}(key)
  #     new_dict[new_key] = value
  #   end
  #   set_attribute!(model, :inter_dict, new_dict)
  # end
  
  return model
end
