require 'result'

module Core
  class Estimations
    def initialize
      @estimation_rooms = {}
    end

    def add(room: nil, name:, description:)
      return Result.failure(:empty_name) if name.strip.empty?
      estimations = estimations_in(room)
      estimation = estimations.find{|e|e[:name] == name}
      return Result.failure(:added_previously) if estimation

      estimations << {
        name: name,
        description: description,
        completed: false,
        estimates: {}
      }
      Result.success
    end

    def complete(room: nil, name:)
      estimations = estimations_in(room)
      estimation = estimations.find{|e|e[:name] == name}
      return Result.failure(:nonexistent_name) if !estimation
      return Result.failure(:completed_previously) if estimation[:completed]
      return Result.failure(:unestimated) if estimation[:estimates].empty?

      estimations.map! do |estimation|
        if estimation[:name] == name
          estimation.merge(completed: true)
        else
          estimation
        end
      end
      Result.success
    end

    def estimate(room: nil, name:, user:, optimistic:, realistic:, pessimistic:)
      return Result.failure(:empty_user) if user.strip.empty?
      estimations = estimations_in(room)
      estimation = estimations.find{|e|e[:name] == name}
      return Result.failure(:nonexistent_name) if !estimation
      return Result.failure(:completed_previously) if estimation[:completed]
      return Result.failure(:user_estimated_previously) if estimation[:estimates][user]
      return Result.failure(:absurd_estimation) if realistic < optimistic || pessimistic < realistic || optimistic < 0

      estimations.map! do |estimation|
        if estimation[:name] == name
          estimation.merge(
            estimates: estimation[:estimates].merge(
              user => {
                optimistic: optimistic,
                realistic: realistic,
                pessimistic: pessimistic
              }
            )
          )
        else
          estimation
        end
      end
      Result.success
    end

    def in_progress(room: nil)
      estimations = estimations_in(room)
      estimations.select do |estimation|
        !estimation[:completed]
      end.map do |estimation|
        h = estimation.clone
        h.delete(:completed)
        h[:estimates] = estimation[:estimates].keys
        h
      end
    end

    def completed(room: nil)
      estimations = estimations_in(room)
      estimations.select do |estimation|
        estimation[:completed]
      end.map do |estimation|
        h = estimation.clone
        h.delete(:completed)
        h[:estimate] = pert(estimation)
        h
      end
    end

    private
    def estimations_in(room)
      @estimation_rooms[room] ||= []
      @estimation_rooms[room]
    end

    def pert(estimation)
      estimates = estimation[:estimates]&.values
      return nil if estimates.empty?

      o = estimates.map{|e|e[:optimistic]}.min.to_f
      r = estimates.map{|e|e[:realistic]}.reduce(:+).to_f / estimates.size
      p = estimates.map{|e|e[:pessimistic]}.max.to_f

      weight_mean = (o + (4 * r) + p) /6
      standard_deviation = (p - o) /6
      pert = weight_mean + (standard_deviation * 2)
      (pert * 4).round / 4.0
    end
  end
end
