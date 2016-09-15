# frozen_string_literal: true

class WoeidController < ApplicationController
  include StringUtils

  # GET /es/woeid/:id/:type
  # GET /es/woeid/:id/:type/status/:status
  # GET /es/ad/listall/ad_type/:type
  # GET /es/ad/listall/ad_type/:type/status/:status
  def show
    @id = params[:id]
    @type = type_scope
    @status = status_scope
    @q = params[:q]
    page = params[:page]

    unless page.nil? || positive_integer?(page)
      raise ActionController::RoutingError, 'Not Found'
    end

    if @id.present?
      @woeid = WoeidHelper.convert_woeid_name(@id)

      raise ActionController::RoutingError, 'Not Found' if @woeid.nil?
    end

    scope = Ad.public_send(@type)
              .public_send(@status)
              .by_woeid_code(@id)
              .by_title(@q)

    @ads = policy_scope(scope).includes(:user).recent_first.paginate(page: page)
  end
end
