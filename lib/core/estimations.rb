require 'result'

module Core
  class Estimations
    def initialize
      @estimations = []
    end

    def add(name:, description:)
      estimation = @estimations.find{|e|e[:name] == name}
      return Result.failure(:added_previously) if estimation

      @estimations << {
        name: name,
        description: description,
        completed: false,
        estimates: {}
      }
      Result.success
    end

    def complete(name:)
      estimation = @estimations.find{|e|e[:name] == name}
      return Result.failure(:nonexistent_name) if !estimation
      return Result.failure(:completed_previously) if estimation[:completed]

      @estimations.map! do |estimation|
        if estimation[:name] == name
          estimation.merge(completed: true)
        else
          estimation
        end
      end
      Result.success
    end

    def estimate(name:, user:, optimistic:, realistic:, pessimistic:)
      estimation = @estimations.find{|e|e[:name] == name}
      return Result.failure(:nonexistent_name) if !estimation
      return Result.failure(:completed_previously) if estimation[:completed]
      return Result.failure(:user_estimated_previously) if estimation[:estimates][user]
      return Result.failure(:absurd_estimation) if realistic < optimistic || pessimistic < realistic

      @estimations.map! do |estimation|
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

    def in_progress
      @estimations.select do |estimation|
        !estimation[:completed]
      end.map do |estimation|
        {
          name: estimation[:name],
          description: estimation[:description],
          estimates: estimation[:estimates].keys
        }
      end
    end

    def completed
      @estimations.select do |estimation|
        estimation[:completed]
      end.map do |estimation|
        estimation.delete(:completed)
        estimation[:estimate] = pert(estimation)
        estimation
      end
    end

    private
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
