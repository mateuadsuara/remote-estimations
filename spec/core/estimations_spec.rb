require 'core/estimations'

RSpec.describe Core::Estimations do
  let(:estimations) { described_class.new }

  it 'start empty' do
    expect(estimations.in_progress).to eq []
    expect(estimations.completed).to eq []
  end

  it 'can be added' do
    addition = estimations.add(
      name: "::the name::",
      description: "::the description::"
    )

    expect(addition).to eq Result.success
    expect(estimations.in_progress).to eq [{
      name: "::the name::",
      description: "::the description::",
      estimates: []
    }]
  end

  it 'cannot be added twice' do
    first_addition = estimations.add(
      name: "::the name::",
      description: "::the description 1::"
    )
    second_addition = estimations.add(
      name: "::the name::",
      description: "::the description 2::"
    )

    expect(first_addition).to eq Result.success
    expect(second_addition).to eq Result.failure(:added_previously)
    expect(estimations.in_progress).to eq [{
      name: "::the name::",
      description: "::the description 1::",
      estimates: []
    }]
  end

  it 'cannot be estimated before added' do
    estimation = estimations.estimate(
      name: "::nonexistent name::",
      user: "::the user::",
      optimistic: 1,
      realistic: 2,
      pessimistic: 4
    )

    expect(estimation).to eq Result.failure(:nonexistent_name)
    expect(estimations.in_progress).to eq []
    expect(estimations.completed).to eq []
  end

  it 'can take estimates for the matching name' do
    estimations.add(
      name: "::matching::",
      description: ""
    )
    estimations.add(
      name: "::another estimation::",
      description: ""
    )
    first_estimation = estimations.estimate(
      name: "::matching::",
      user: "::user1::",
      optimistic: 1,
      realistic: 2,
      pessimistic: 4
    )
    second_estimation = estimations.estimate(
      name: "::matching::",
      user: "::user2::",
      optimistic: 9,
      realistic: 15,
      pessimistic: 99
    )

    expect(first_estimation).to eq Result.success
    expect(second_estimation).to eq Result.success
    expect(estimations.in_progress).to eq([
      {name: "::matching::", description: "", estimates: ["::user1::", "::user2::"]},
      {name: "::another estimation::", description: "", estimates: []}
    ])
  end

  it 'remembers the estimates sent to show them when completed' do
    estimations.add(
      name: "::the name::",
      description: ""
    )
    estimations.estimate(
      name: "::the name::",
      user: "::user1::",
      optimistic: 1,
      realistic: 2,
      pessimistic: 4
    )
    estimations.complete(
      name: "::the name::"
    )

    expect(estimations.completed.first[:estimates]).to eq({
      "::user1::" => {
        optimistic: 1,
        realistic: 2,
        pessimistic: 4
      }
    })
  end

  it 'cannot be estimated by the same user twice' do
    estimations.add(
      name: "::the name::",
      description: "::the description::"
    )
    first_estimation = estimations.estimate(
      name: "::the name::",
      user: "::the user::",
      optimistic: 1,
      realistic: 2,
      pessimistic: 4
    )
    second_estimation = estimations.estimate(
      name: "::the name::",
      user: "::the user::",
      optimistic: 9,
      realistic: 9,
      pessimistic: 9
    )
    estimations.complete(
      name: "::the name::"
    )

    expect(first_estimation).to eq Result.success
    expect(second_estimation).to eq Result.failure(:user_estimated_previously)
    expect(estimations.completed.first[:estimates]).to eq({
      "::the user::" => {
        optimistic: 1,
        realistic: 2,
        pessimistic: 4
      }
    })
  end

  it 'cannot have lower realistic value than the optimistic' do
    estimations.add(
      name: "::the name::",
      description: "::the description::"
    )
    estimation = estimations.estimate(
      name: "::the name::",
      user: "::the user::",
      optimistic: 2,
      realistic: 1,
      pessimistic: 4
    )

    expect(estimation).to eq Result.failure(:absurd_estimation)
    expect(estimations.in_progress.first[:estimates]).to eq([])
  end

  it 'cannot have lower pesimistic value than the realistic' do
    estimations.add(
      name: "::the name::",
      description: "::the description::"
    )
    estimation = estimations.estimate(
      name: "::the name::",
      user: "::the user::",
      optimistic: 1,
      realistic: 4,
      pessimistic: 2
    )

    expect(estimation).to eq Result.failure(:absurd_estimation)
    expect(estimations.in_progress.first[:estimates]).to eq([])
  end

  it 'cannot be completed twice' do
    estimations.add(
      name: "::the name::",
      description: "::the description::"
    )
    first_completion = estimations.complete(
      name: "::the name::"
    )
    second_completion = estimations.complete(
      name: "::the name::"
    )

    expect(first_completion).to eq Result.success
    expect(second_completion).to eq Result.failure(:completed_previously)
    expect(estimations.in_progress).to eq []
    expect(estimations.completed.length).to eq 1
  end

  it 'cannot complete an unexistent name' do
    completion = estimations.complete(
      name: "::nonexistent name::"
    )

    expect(completion).to eq Result.failure(:nonexistent_name)
    expect(estimations.in_progress).to eq []
    expect(estimations.completed).to eq []
  end

  it 'that are in progress show which users already estimated' do
    estimations.add(
      name: "::estimation1::",
      description: "::description1::"
    )
    estimations.estimate(
      name: "::estimation1::",
      user: "::user1::",
      optimistic: 1,
      realistic: 2,
      pessimistic: 4
    )
    estimations.estimate(
      name: "::estimation1::",
      user: "::user2::",
      optimistic: 2,
      realistic: 2,
      pessimistic: 2
    )
    estimations.add(
      name: "::estimation2::",
      description: "::description2::"
    )
    estimations.estimate(
      name: "::estimation2::",
      user: "::user2::",
      optimistic: 9,
      realistic: 9,
      pessimistic: 9
    )
    estimations.complete(
      name: "::estimation2::"
    )
    estimations.add(
      name: "::estimation3::",
      description: "::description3::"
    )

    expect(estimations.in_progress).to eq [
      {name: "::estimation1::", description: "::description1::", estimates: ["::user1::", "::user2::"]},
      {name: "::estimation3::", description: "::description3::", estimates: []}
    ]
  end

  it 'that are completed show the users who participated with their estimates and the final pert estimate' do
    estimations.add(
      name: "::estimation1::",
      description: "::description1::"
    )
    estimations.estimate(
      name: "::estimation1::",
      user: "::user1::",
      optimistic: 1,
      realistic: 4,
      pessimistic: 8
    )
    estimations.estimate(
      name: "::estimation1::",
      user: "::user2::",
      optimistic: 4,
      realistic: 4,
      pessimistic: 4
    )
    estimations.complete(
      name: "::estimation1::"
    )
    estimations.add(
      name: "::estimation2::",
      description: "::description2::"
    )
    estimations.estimate(
      name: "::estimation2::",
      user: "::user2::",
      optimistic: 8,
      realistic: 8,
      pessimistic: 8
    )
    estimations.complete(
      name: "::estimation2::"
    )
    estimations.add(
      name: "::estimation3::",
      description: "::description3::"
    )

    expect(estimations.completed).to eq([
      {
        name: "::estimation1::",
        description: "::description1::",
        estimate: 6.5,
        estimates: {
          "::user1::" => {
            optimistic: 1,
            realistic: 4,
            pessimistic: 8
          },
          "::user2::" => {
            optimistic: 4,
            realistic: 4,
            pessimistic: 4
          }
        }
      },
      {
        name: "::estimation2::",
        description: "::description2::",
        estimate: 8,
        estimates: {
          "::user2::" => {
            optimistic: 8,
            realistic: 8,
            pessimistic: 8
          }
        }
      }
    ])
  end

  context 'include a pert estimate that' do
    def pert(estimates)
      estimations = described_class.new

      estimations.add(
        name: "::the name::",
        description: "::the description::"
      )

      estimates.each_with_index do |estimate, index|
        optimistic, realistic, pessimistic = estimate
        estimations.estimate(
          name: "::the name::",
          user: "::user#{index}::",
          optimistic: optimistic,
          realistic: realistic,
          pessimistic: pessimistic
        )
      end

      estimations.complete(
        name: "::the name::"
      )

      estimations.completed.first[:estimate]
    end

    it 'is missing when no user estimated' do
      estimates = []
      expect(pert(estimates)).to eq nil
    end

    it 'is 1 when only one user estimated with 1, 1, 1' do
      estimates = [[1, 1, 1]]
      expect(pert(estimates)).to eq 1.0
    end

    it 'is 6.5 when only one user estimated with 1, 4, 8' do
      estimates = [[1, 4, 8]]
      expect(pert(estimates)).to eq 6.5
    end

    it 'is 11.5 when only one user estimated with 1, 10, 10' do
      estimates = [[1, 10, 10]]
      expect(pert(estimates)).to eq 11.5
    end

    it 'takes the most optimistic across all users' do
      all_user_estimates = [
        [2, 4, 8],
        [4, 4, 8],
        [1, 4, 8]
      ]
      one_user_equivalent = [
        [1, 4, 8]
      ]

      expect(pert(all_user_estimates)).to eq pert(one_user_equivalent)
    end

    it 'takes the most pessimistic across all users' do
      all_user_estimates = [
        [1, 4, 4],
        [1, 4, 8],
        [1, 4, 5]
      ]
      one_user_equivalent = [
        [1, 4, 8]
      ]

      expect(pert(all_user_estimates)).to eq pert(one_user_equivalent)
    end

    it 'takes the average realistic for all users' do
      all_user_estimates = [
        [1, 2, 8],
        [1, 3, 8],
        [1, 7, 8]
      ]
      one_user_equivalent = [
        [1, 4, 8]
      ]

      expect(pert(all_user_estimates)).to eq pert(one_user_equivalent)
    end
  end
end
