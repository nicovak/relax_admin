require "csv"

module SlashAdmin
  class ModelsController < SlashAdmin::BaseController
    include Pagy::Backend

    skip_before_action :verify_authenticity_token, only: :nestable
    before_action :handle_internal_default
    before_action :handle_default
    before_action :nestable_config
    before_action :handle_default_params
    before_action :handle_associations

    helper_method :list_params, :export_params, :create_params, :update_params, :show_params, :nested_params, :should_add_translatable?, :translatable_params, :available_locales, :tooltips

    def index
      authorize! :index, @model_class
      @models_export = if params[:filters].present?
        handle_filtered_search
      else
        @model_class.all
      end

      column = @model_class.arel_table[params[:order_field].to_sym]
      order = params[:order].downcase
      if %w[asc desc].include?(order)
        if @models_export.is_a?(Array)
          @models = if order == "asc"
            @models_export.sort { |m1, m2| m1.send(params[:order_field]) <=> m2.send(params[:order_field]) }
          else
            @models_export.sort { |m1, m2| m2.send(params[:order_field]) <=> m1.send(params[:order_field]) }
          end
          @pagy_models, @models = pagy_array(@models, items: params[:per])
        else
          @pagy_models, @models = pagy(@models_export.order(column.send(params[:order].downcase)), items: params[:per])
        end
      end

      @fields = if @use_export_params
        export_params
      else
        @model_class.column_names
      end

      respond_to do |format|
        format.html
        format.csv { stream_csv_report }
        format.xls { send_data render_to_string, filename: "#{@model_class.model_name.plural.upcase}_#{Date.today}.xls" }
        format.js { @models }
      end
    end

    def new
      authorize! :new, @model_class
      @model = @model_class.new
    end

    def before_validate_on_create
    end

    def after_save_on_create
    end

    def create
      authorize! :new, @model_class
      handle_has_one

      @model = @model_class.new(permit_params)

      before_validate_on_create
      handle_specific_fields

      if @model.valid?
        if @model.save!
          after_save_on_create
          respond_to do |format|
            format.html do
              flash[:success] = t("slash_admin.controller.create.success", model_name: @model_name)
              redirect_to(handle_redirect_after_submit) && return
            end
            format.js { render(json: {id: @model.id, name: helpers.show_object(@model)}) && return }
          end
        end
      else
        flash[:error] = t("slash_admin.controller.create.error", model_name: @model_name)
      end

      respond_to do |format|
        format.html { render :new }
        format.js { render json: {errors: @model.errors.full_messages} }
      end
    end

    def edit
      authorize! :edit, @model_class
      @model = @model_class.find(params[:id])
    end

    def update
      authorize! :edit, @model_class
      @model = @model_class.find(params[:id])

      handle_has_one

      @model.assign_attributes(permit_params)

      before_validate_on_update
      handle_specific_fields

      if @model.valid?
        if @model.save!
          after_save_on_update
          flash[:success] = t("slash_admin.controller.update.success", model_name: @model_name)
          respond_to do |format|
            format.html { redirect_to(handle_redirect_after_submit) && return }
            format.js
          end
        end
      else
        flash[:error] = t("slash_admin.controller.update.error", model_name: @model_name)
      end
      render :edit
    end

    def show
      authorize! :show, @model_class
      @model = @model_class.find(params[:id])

      respond_to do |format|
        format.html
        format.js { @model }
      end
    end

    def destroy
      @model_class.find(params[:id]).destroy!
      flash[:success] = t("slash_admin.controller.delete.success", model_name: @model_name)
      respond_to do |format|
        format.html { redirect_to main_app.polymorphic_url([:slash_admin, @model_class]) }
        format.js
      end
    end

    def before_validate_on_update
    end

    def after_save_on_update
    end

    # Add tooltip to th list view & edit/create view
    # {
    #   attr: 'Value',
    #   title: 'The title of my model',
    # }
    #
    def tooltips
      {}
    end

    def handle_has_one
      @has_one = {}
      Array.wrap(update_params + create_params).uniq.each do |p|
        if helpers.guess_field_type(@model_class.new, p) == "has_one" && !@model_class.nested_attributes_options.key?(p.to_sym)
          @has_one[p] = permit_params[p]
          permit_params.delete(p)
        end
      end
    end

    def handle_specific_fields
      # has_one
      if @has_one.present?
        @has_one.each do |k, v|
          if v.present?
            @model.send("#{k}=", helpers.class_name_from_association(@model, k).constantize.find(v))
          else
            @model.send("#{k}=", nil)
          end
        end
      end

      # JSON
      @model_class.columns_hash.each do |k, v|
        if permit_params[k].is_a? String
          if v.type == :json || v.type == :jsonb || helpers.serialized_json_field?(@model_class, k.to_s)
            begin
              @model.send("#{k}=", JSON.parse(permit_params[k]))
            rescue
              # Handle case when single string passed, we transform it into array to have a valid json
              json = permit_params[k].split(",").to_json
              @model.send("#{k}=", JSON.parse(json))
            end
          end
        end
      end

      # Other
    end

    def nestable
      unless @is_nestable
        flash[:error] = t("slash_admin.controller.nestable.error", model_name: @model_name)
        redirect_to(main_app.polymorphic_url([:slash_admin, @model_class])) && return
      end

      if request.post?
        if params[:nestable][:data].present?
          JSON.parse(params[:nestable][:data]).each_with_index do |p, i|
            m = @model_class.find(p["id"])
            m.position = i
            m.save!
          end
        end

        flash[:success] = t("slash_admin.controller.nestable.success")

        redirect_to(main_app.polymorphic_url(["slash_admin", @model_class])) && return if params.key?(:submit_redirect)
        redirect_to main_app.polymorphic_url([:nestable, :slash_admin, @model_class])
      end
    end

    def handle_filtered_search
      search = if @model_class.respond_to? :translated_attribute_names
        @model_class.with_translations(I18n.locale).all
      else
        @model_class.all
      end

      virtual_fields = []

      params[:filters].each do |attr, query|
        unless query.blank?
          attr_type = helpers.guess_field_type(@model_class, attr)
          if @model_class.respond_to?(:translated_attribute_names) && @model_class.translated_attribute_names.include?(attr.to_sym)
            attr = "#{@model_class.name.singularize.underscore}_translations.#{attr}"
          end
          # aggregate_reflections ?
          attr_prefixed = model.table_name + "." + attr
          case attr_type
            # TODO : Should be rewritten
          when "belongs_to"
            search = search.eager_load(attr.to_s)
            search = search.where(attr.to_s + "_id IN (" + query.join(",") + ")")
            # TODO : Should be rewritten
          when "has_one"
            search = search.eager_load(attr.to_s)
            search = search.where(attr.to_s.pluralize + ".id IN (" + query.join(",") + ")")
          when "string", "text"
            query.strip! unless query.strip!.nil?
            attributes = @model_class.new.attributes.keys
            if !attributes.include?(attr.to_s) && @model_class.method_defined?(attr.to_s)
              virtual_fields << attr.to_s
            else
              begin
                search = search.where("unaccent(lower(#{attr_prefixed})) LIKE unaccent(lower(:query))", query: "%#{query}%")
              rescue
                search = search.where("lower(#{attr_prefixed}) LIKE lower(:query)", query: "%#{query}%")
              end
            end
          when "date", "datetime"
            if query.is_a?(String)
              search = search.where("#{attr_prefixed} = :query", query: query)
            else
              if query["from"].present? || query["to"].present?
                if query["from"].to_date != query["to"].to_date
                  if query["from"].present?
                    search = search.where("#{attr_prefixed} >= :query", query: query["from"].to_date)
                  end
                  if query["to"].present?
                    search = search.where("#{attr_prefixed} <= :query", query: query["to"].to_date)
                  end
                else
                  search = search.where("#{attr_prefixed} = :query", query: query["from"].to_date)
                end
              end
            end
          when "decimal", "number", "integer"
            if query.instance_of?(ActionController::Parameters)
              if query["from"].present? || query["to"].present?
                search = search.where("#{attr_prefixed} >= :query", query: query["from"]) if query["from"].present?
                search = search.where("#{attr_prefixed} <= :query", query: query["to"]) if query["to"].present?
              end
            else
              if attr_type == "decimal" || attr_type == "number"
                query = query.to_f
              elsif attr_type == "integer"
                query = query.to_i
              end
              search = search.where("#{attr_prefixed} = :query", query: query)
            end
          when "boolean"
            search = search.where("#{attr_prefixed} = :query", query: to_boolean(query))
          else
            raise Exception.new("Unable to query for attribute_type : #{attr_type}")
          end
        end
      end

      params[:filters].each do |attr, query|
        unless query.blank?
          if virtual_fields.present? && virtual_fields.include?(attr.to_s)
            search = search.select { |s| s.send(attr).present? ? s.send(attr).to_s.downcase.include?(query.downcase) : nil }
          end
        end
      end

      search
    end

    # Export CSV
    def export_csv(options = {})
      @models_export.to_sql
    end

    def update_params(options = {})
      if options.present?
        create_params(options)
      else
        create_params
      end
    end

    def autocomplete_params
      aut_params = []
      helpers.object_label_methods.each do |m|
        aut_params << m if model.respond_to? m
      end

      raise Exception.new("You have to defined autocomplete_params in your admin model controller") if aut_params.blank?
      aut_params
    end

    protected

    def prepend_view_paths
      prepend_view_path "app/views/slash_admin"
      begin
        prepend_view_path "app/views/slash_admin/models/#{@model_class.model_name.to_s.pluralize.underscore}"
      rescue
        nil
      end
    end

    def handle_redirect_after_submit
      path = main_app.edit_polymorphic_url(["slash_admin", @model])
      path = main_app.polymorphic_url(["slash_admin", @model_class]) if params.key?(:submit_redirect)
      path = main_app.new_polymorphic_url(["slash_admin", @model_class]) if params.key?(:submit_add)

      path
    end

    def permit_params
      params[@model_class.name.split("::").last.underscore].permit!
    end

    def handle_default
      @title = @model_name.present? ? @model_class.model_name.human(count: 2) : nil
      @sub_title = nil
      @per = 20
      @page = 1
      @per_values = [20, 30, 50, 100, 150]
      @use_export_params = false
      @order_field = :id
      @order = "DESC"
    end

    def nestable_config
      @is_nestable = false
      @max_depth = 1

      @nestable_field = :position
      @acenstry_field = :ancestry
    end

    def handle_internal_default
      @model_class = model
      @update_params = update_params
      @model_name = @model_class.model_name.human
    end

    def should_add_translatable?
      should = @model_class.respond_to?(:translated_attribute_names)
      handle_default_translations if should

      should
    end

    def handle_default_translations
      available_locales.reject { |key| key == :root }.each do |locale|
        translation = @model.translations.find_by_locale locale.to_s
        if translation.nil?
          @model.translations.build locale: locale
        end
      end
    end

    def handle_default_params
      params[:per] ||= @per
      params[:page] ||= @page
      params[:order_field] ||= @order_field
      params[:order] ||= @order
      params[:filters] ||= []
    end

    def available_locales
      SlashAdmin.configuration.available_locales
    end

    def handle_associations
      @belongs_to_fields = @model_class.reflect_on_all_associations(:belongs_to).map(&:name)
      @has_many_fields = @model_class.reflect_on_all_associations(:has_many).map(&:name)
      @has_one_fields = @model_class.reflect_on_all_associations(:has_one).map(&:name)
    end

    # By default we are looking in SlashAdmin:: namespace
    def model
      controller_name.classify.constantize
    rescue
      ("SlashAdmin::" + controller_name.classify).constantize
    end

    def create_params(options = {})
      exclude_default_params(controller_name.classify.constantize.attribute_names).map { |attr| attr.gsub(/_id$/, "") }
    end

    def translatable_params
      controller_name.classify.constantize.translated_attribute_names
    end

    def show_params
      @model_class.attribute_names.map { |attr| attr.gsub(/_id$/, "") }
    end

    def nested_params
      nested_params = []
      @model_class.nested_attributes_options.keys.each do |nested|
        nested_params << {nested => exclude_default_params(nested.to_s.singularize.classify.constantize.attribute_names.map { |attr| attr.gsub(/_id$/, "") }) - [@model.model_name.param_key]}
      end

      nested_params
    end

    # Exclude default params for edit and create
    def exclude_default_params(params)
      params -= %w[id created_at updated_at slug position]
      if @model_class.try(:translated_attribute_names).present?
        params -= @model_class.translated_attribute_names.map(&:to_s)
      end
      params
    end

    def stream_file(filename, extension)
      response.headers["Content-Type"] = "application/octet-stream"
      response.headers["Content-Disposition"] = "attachment; filename=#{filename}.#{extension}"

      yield response.stream
    ensure
      response.stream.close
    end

    def stream_csv_report
      query = @models_export.limit(5000).to_sql
      query_options = "WITH CSV HEADER"

      stream_file("#{@model_class.model_name.plural.upcase}_#{Date.today}", "csv") do |stream|
        stream_query_rows(query, query_options) do |row_from_db|
          stream.write row_from_db
        end
      end
    end

    private

    def list_params
    end

    def export_params
      list_params
    end

    def stream_query_rows(sql_query, options = "WITH CSV HEADER")
      conn = ActiveRecord::Base.connection.raw_connection
      conn.copy_data "COPY (#{sql_query}) TO STDOUT #{options};" do
        while row = conn.get_copy_data
          yield row
        end
      end
    end
  end
end
