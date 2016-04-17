class NodesController < ApplicationController
  skip_before_action :check_administrator_role
  before_action :check_if_node_exist, only: [:availability, :history, :info]

  def index
    searchable_by = Node.searchable
    query_sql = "("
    query_params = Array.new
    params.each do |key, param|
      if (searchable_by.key?(key) && param != "" && param)
        prop = searchable_by[key]
        if key == "vipnet_version"
          regexps = Node.vipnet_versions_substitute(param)
          query_sql += "false AND " unless regexps
          if regexps.class == Array
            query_sql += "("
            regexps.each do |regexp|
              query_sql += "vipnet_version -> 'summary' ILIKE ? OR "
              query_params.push(Node.pg_regexp_adoptation(regexp))
            end
            query_sql += "false) AND "
          end
          next
        end
        if prop.class == String
          query_sql += "#{prop} ILIKE ? AND "
        elsif prop.class == Hash
          hash_prop = prop.keys[0]
          key = prop[hash_prop]
          query_sql += "#{hash_prop} -> '#{key}' ILIKE ? AND "
        end
        query_params.push(Node.pg_regexp_adoptation(Regexp.new(param)))
      end
    end
    query_sql += "true)"

    Node.per_page = current_user.settings["nodes_per_page"] || Settings.nodes_per_page
    if query_sql == "(true)"
      @nodes = Node.where("history = 'false'")
      @size_all = @nodes.size
      @nodes = @nodes.paginate(page: params[:page])
      @dont_show_history = true
      @search = false
    else
      @nodes = Node.where(query_sql, *query_params)
      @size_all = @nodes.size
      @size_no_history = @nodes.where("history = 'false'").size
      @nodes = @nodes.paginate(page: params[:page])
      @dont_show_history = @size_no_history > 0 ? true : false
      @search = true
    end
  end

  respond_to :js
  respond_to :html

  def availability
    @response = {
      parent_id: "#node-#{@node.id}__check-availability"
    }
    availability = @node.availability
    if availability[:errors]
      @response[:status] = false
      @response[:tooltip_text] = t("nodes.fullscreen_tooltip.#{availability[:errors][0][:detail]}.short")
      @response[:fullscreen_tooltip_key] = availability[:errors][0][:detail]
    else
      @response[:status] = availability[:data][:availability]
      @response[:tooltip_text] = t("nodes.row.availability.status_#{availability[:data][:availability]}")
      @response[:fullscreen_tooltip_key] = "node-unavailable" if @response[:status] == false
    end
    respond_with(@response, template: "nodes/row/remote_status_button") and return
  end

  def history
    @response = {
      parent_id: "#node-#{@node.id}__history",
      row_id: "#node-#{@node.id}__row",
      history: true,
    }
    @response[:nodes] = Node.where("vipnet_id = ? AND history = ?", @node.vipnet_id, !@node.history).reorder("updated_at ASC")
    if @node.history
      @response[:status] = @response[:nodes].size == 1
      @response[:place] = "before"
      @response[:tooltip_text] = t("nodes.row.history.update_#{@response[:status]}")
    else
      @response[:status] = @response[:nodes].size > 0
      @response[:place] = "after"
      @response[:tooltip_text] = t("nodes.row.history.history_#{@response[:status]}")
    end
    respond_with(@response, template: "nodes/row/remote_status_button") and return
  end

  def info
    @response = {
      parent_id: "#node-#{@node.id}__info",
      name: @node.name,
      category: t("nodes.row.info.#{@node.category}"),
      network: Node.network(@node.vipnet_id),
      ips: @node.ips["summary"] ? @node.ips["summary"] : "?",
      vipnet_version_hw: @node.vipnet_version["summary"] ? @node.vipnet_version["summary"] : "?",
      tooltip_text: t("nodes.row.info.loaded"),
    }
    network = Network.find_by_id(@node.network_id)
    if network
      if network.name
        @response[:network] = "#{@response[:network]} (#{network.name})"
      end
    else
      Rails.logger.error("Unable to find network '#{@node.network_id}'")
    end
    respond_with(@response, template: "nodes/row/info") and return
  end

  private
    def check_if_node_exist
      @node = Node.find_by_id(params[:node_id])
      render nothing: true, status: 400, content_type: "text/html" and return unless @node
    end

end
