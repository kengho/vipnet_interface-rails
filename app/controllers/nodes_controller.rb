class NodesController < ApplicationController
  before_action :check_if_ncc_node_exist, only: [:info, :history, :availability]

  def index
    @params = params.reject { |k, _| %w[controller action].include?(k) }
  end

  respond_to :js

  def load
    @search = false
    clear_params = clear_params(params)
    expanded_params = expand_params(clear_params)

    if expanded_params["search"]
      @search = true
      search_resuls = NccNode.none
      value = expanded_params["search"]
      NccNode.quick_searchable.each do |prop|
        search_resuls = search_resuls | NccNode.where_prop_like(prop, value)
      end
    else
      search_resuls = NccNode.all
      expanded_params.each do |prop, value|
        next if prop == "page"
        @search = true
        values = Array(value)
        sub_search_resuls = NccNode.none
        values.each do |value|
          sub_search_resuls = sub_search_resuls | NccNode.where_prop_like(prop, value)
        end
        search_resuls = search_resuls & sub_search_resuls
      end
    end

    per_page = current_user.settings["nodes_per_page"] || Settings.nodes_per_page
    if @search
      # http://stackoverflow.com/a/24448317/6376451
      all_ncc_nodes = NccNode
        .where(id: search_resuls.map(&:id))
        .order(vid: :asc)
      current_ncc_nodes = all_ncc_nodes.where(type: "CurrentNccNode")
      NccNode.per_page = per_page
      if current_ncc_nodes.size > 0
        @ncc_nodes = current_ncc_nodes
      else
        @ncc_nodes = all_ncc_nodes
      end

      # calculating size here because of paginate() later
      @size = @ncc_nodes.size
    else
      # there are mess in pagination if creation_date is the same
      # and there are only one ordering prop
      @ncc_nodes = CurrentNccNode.order(creation_date: :desc, vid: :desc)
      CurrentNccNode.per_page = per_page
    end

    @ncc_nodes = @ncc_nodes
      .paginate(page: params[:page])
      .includes(:descendant, :hw_nodes, hw_nodes: [:node_ips])
    @params = clear_params.clone
    @js_data = @ncc_nodes.js_data
  end

  def info
    @ncc_node
  end

  def history
    @prop = params[:prop].to_sym
    @data = @ncc_node.history(@prop)
    @status = @data.size > 0
  end

  def availability
    @status = @ncc_node.availability
    sleep(rand(5)) if Settings.demo_mode == "true"
  end

  private
    def check_if_ncc_node_exist
      @ncc_node = NccNode.find_by(vid: params[:vid])
      render_nothing(:bad_request) unless @ncc_node
    end
end
