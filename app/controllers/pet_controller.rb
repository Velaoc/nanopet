# frozen_string_literal: true

# The whole app: the public root IS the pet. Actions post back to the same
# page and swap the pet panel via Turbo Streams, so stats update visibly
# without a reload.
class PetController < ApplicationController
  before_action :set_pet, only: %i[show feed play rest rescue]
  before_action :ensure_pet, only: %i[show feed play rest rescue]

  def show
    @stats = @pet.stats
    @events = @pet.care_events.limit(8)
    @notice = flash[:notice]
  end

  def new
    @pet = Pet.new
  end

  def create
    pet = Pet.adopt!(name: pet_params[:name].to_s.strip, look: pet_params[:look])
    respond_to do |format|
      format.turbo_stream { redirect_to root_path, notice: "#{pet.name} has joined your life!" }
      format.html { redirect_to root_path, notice: "#{pet.name} has joined your life!" }
    end
  rescue ActiveRecord::RecordInvalid
    @pet = Pet.new(pet_params)
    render :new, status: :unprocessable_content
  end

  def feed
    care(:feed)
  end

  def play
    care(:play)
  end

  def rest
    care(:rest)
  end

  def rescue
    care(:rescue)
  end

  private

  def set_pet
    @pet = Pet.current
  end

  def ensure_pet
    redirect_to new_pet_path unless @pet
  end

  def care(action)
    @result = @pet.public_send(:"#{action}!")
    @stats = @result[:stats]
    @events = @pet.care_events.limit(8)
    @notice = @result[:message]
    @reaction = action

    respond_to do |format|
      format.turbo_stream { render "pet/care" }
      format.html { redirect_to root_path, notice: @notice }
    end
  end

  def pet_params
    params.require(:pet).permit(:name, :look)
  end
end
