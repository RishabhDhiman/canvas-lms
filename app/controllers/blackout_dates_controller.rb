# frozen_string_literal: true

#
# Copyright (C) 2022 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#
# @API Blackout Dates
#
# API for accessing blackout date information.
#
# @model BlackoutDate
#     {
#       "id": "BlackoutDate",
#       "description": "Blackout dates are used to prevent scheduling assignments on a given date in course pacing.",
#       "properties": {
#         "id": {
#           "description": "the ID of the blackout date",
#           "example": 1,
#           "type": "integer"
#         },
#         "context_id": {
#           "description": "the context owning the blackout date",
#           "example": 1,
#           "type": "integer"
#         },
#         "context_type": {
#           "example": "Course",
#           "type": "string"
#         },
#         "start_date": {
#           "description": "the start date of the blackout date",
#           "example": "2022-01-01",
#           "type": "datetime"
#         },
#         "end_date": {
#           "description": "the end date of the blackout date",
#           "example": "2022-01-02",
#           "type": "datetime"
#         },
#         "event_title": {
#           "description": "title of the blackout date",
#           "example": "some title",
#           "type": "string"
#         }
#       }
#     }
#
class BlackoutDatesController < ApplicationController
  before_action :require_context
  before_action :require_feature_flag
  before_action :authorize_action
  before_action :load_blackout_date, only: %i[show edit update destroy]

  # @API List blackout dates
  # Returns the list of blackout dates for the current context.
  #
  # @returns [BlackoutDate]
  #
  def index
    @blackout_dates = @context.blackout_dates.order(:start_date)
    respond_to do |format|
      format.html
      format.json { render json: @blackout_dates.as_json(include_root: false) }
    end
  end

  # @API Get a single blackout date
  # Returns the blackout date with the given id.
  #
  # @returns BlackoutDate
  #
  def show
    render json: @blackout_date.as_json
  end

  # @API New Blackout Date
  # Initialize an unsaved Blackout Date for the given context.
  #
  # @returns BlackoutDate
  #
  def new
    @blackout_date = @context.blackout_dates.new
    render json: @blackout_date.as_json
  end

  # @API Create Blackout Date
  # Create a blackout date for the given context.
  #
  # @argument start_date [Date]
  #   The start date of the blackout date.
  # @argument end_date [Date]
  #   The end date of the blackout date.
  # @argument event_title [String]
  #   The title of the blackout date.
  #
  # @returns BlackoutDate
  #
  def create
    @blackout_date = @context.blackout_dates.build(blackout_date_params)
    if @blackout_date.save
      render json: @blackout_date.as_json, status: :created
    else
      render json: { success: false, errors: @blackout_date.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @API Update Blackout Date
  # Update a blackout date for the given context.
  #
  # @argument start_date [Date]
  #   The start date of the blackout date.
  # @argument end_date [Date]
  #   The end date of the blackout date.
  # @argument event_title [String]
  #   The title of the blackout date.
  #
  # @returns BlackoutDate
  #
  def update
    if @blackout_date.update(blackout_date_params)
      render json: @blackout_date.as_json
    else
      render json: @blackout_date.errors.full_messages, status: :unprocessable_entity
    end
  end

  # @API Delete Blackout Date
  # Delete a blackout date for the given context.
  #
  # @returns BlackoutDate
  #
  def destroy
    @blackout_date.destroy
    head :no_content
  end

  private

  def authorize_action
    authorized_action(@context, @current_user, :manage_content)
  end

  def require_feature_flag
    account = @context.is_a?(Account) ? @context : @context.account
    not_found unless account.feature_enabled?(:pace_plans)
  end

  def load_blackout_date
    @blackout_date = @context.blackout_dates.find(params[:id])
  end

  def blackout_date_params
    params.require(:blackout_date).permit(:start_date, :end_date, :event_title)
  end
end
