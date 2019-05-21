class VariablesController < ApplicationController
  include VariableUtils

  around_action :log_execution_time

  respond_to :json

  def index
    response = retrieve_variables({ cmr_format: 'umm_json' }.merge(params), token)

    render json: response.body, status: response.status
  end

  def show
    response = retrieve_variable(params[:id], token)

    render json: response.body, status: response.status
  end
end
