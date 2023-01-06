using HiGHS
using JuMP

using EnergyModelsBase
using EnergyModelsInvestments
using TimeStructures

const EMB = EnergyModelsBase
const IM = EnergyModelsInvestments


"""
    run_model(case, model, optimizer)

Defines the necessary steps for running the model. 
This is a temporary implementation before a separate package handles this.
"""
function run_model(case, model, optimizer = nothing)
    @info "Run model" model optimizer

    m = EMB.create_model(case, model)

    set_optimizer(m, optimizer)
    optimize!(m)
    return m
end


"""
    generate_data()

Generate the data for the case study.
"""
function generate_data()
    @info "Generate case data"

    # Define the different resources
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k => 0 for k ∈ products)

    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    nodes = [
        EMB.GenAvailability(1, 𝒫₀, 𝒫₀),
        EMB.RefSink(
            2,
            DynamicProfile(
                [
                    20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20
                    20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20
                    20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20
                    20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20
                ],
            ),
            Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
            Dict(Power => 1),
            𝒫ᵉᵐ₀,
        ),
        EMB.RefSource(
            3,
            FixedProfile(30),
            FixedProfile(30),
            FixedProfile(100),
            Dict(NG => 1),
            𝒫ᵉᵐ₀,
            Dict(
                "Investments" => extra_inv_data(
                    Capex_Cap = FixedProfile(1000),
                    Cap_max_inst = FixedProfile(200),
                    Cap_max_add = FixedProfile(200),
                    Cap_min_add = FixedProfile(10),
                    Inv_mode = ContinuousInvestment(),
                    Cap_increment = FixedProfile(5),
                    Cap_start = 15,
                ),
            ),
        ),
        EMB.RefSource(
            4,
            FixedProfile(9),
            FixedProfile(9),
            FixedProfile(100),
            Dict(Coal => 1),
            𝒫ᵉᵐ₀,
            Dict(
                "Investments" => extra_inv_data(
                    Capex_Cap = FixedProfile(1000),
                    Cap_max_inst = FixedProfile(200),
                    Cap_max_add = FixedProfile(200),
                    Cap_min_add = FixedProfile(0),
                    Inv_mode = ContinuousInvestment(),
                ),
            ),
        ),
        EMB.RefGeneration(
            5,
            FixedProfile(0),
            FixedProfile(5.5),
            FixedProfile(100),
            Dict(NG => 2),
            Dict(Power => 1, CO2 => 1),
            𝒫ᵉᵐ₀,
            0.9,
            Dict(
                "Investments" => extra_inv_data(
                    Capex_Cap = FixedProfile(600),
                    Cap_max_inst = FixedProfile(25),
                    Cap_max_add = FixedProfile(25),
                    Cap_min_add = FixedProfile(0),
                    Inv_mode = ContinuousInvestment(),
                ),
            ),
        ),
        EMB.RefGeneration(
            6,
            FixedProfile(0),
            FixedProfile(6),
            FixedProfile(100),
            Dict(Coal => 2.5),
            Dict(Power => 1, CO2 => 1),
            𝒫ᵉᵐ₀,
            0,
            Dict(
                "Investments" => extra_inv_data(
                    Capex_Cap = FixedProfile(800),
                    Cap_max_inst = FixedProfile(25),
                    Cap_max_add = FixedProfile(25),
                    Cap_min_add = FixedProfile(0),
                    Inv_mode = ContinuousInvestment(),
                ),
            ),
        ),
        EMB.RefStorage(
            7,
            FixedProfile(0),
            FixedProfile(0),
            FixedProfile(9.1),
            FixedProfile(100),
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            Dict(
                "Investments" => extra_inv_data_storage(
                    Capex_rate = FixedProfile(0),
                    Rate_max_inst = FixedProfile(600),
                    Rate_max_add = FixedProfile(600),
                    Rate_min_add = FixedProfile(0),
                    Capex_stor = FixedProfile(500),
                    Stor_max_inst = FixedProfile(600),
                    Stor_max_add = FixedProfile(600),
                    Stor_min_add = FixedProfile(0),
                    Inv_mode = ContinuousInvestment(),
                ),
            ),
        ),
        EMB.RefGeneration(
            8,
            FixedProfile(2),
            FixedProfile(0),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1, CO2 => 1),
            𝒫ᵉᵐ₀,
            0,
            Dict(
                "Investments" => extra_inv_data(
                    Capex_Cap = FixedProfile(0),
                    Cap_max_inst = FixedProfile(25),
                    Cap_max_add = FixedProfile(2),
                    Cap_min_add = FixedProfile(2),
                    Inv_mode = ContinuousInvestment(),
                ),
            ),
        ),
        EMB.RefStorage(
            9,
            FixedProfile(3),
            FixedProfile(5),
            FixedProfile(0),
            FixedProfile(0),
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            Dict(
                "Investments" => extra_inv_data_storage(
                    Capex_rate = FixedProfile(0),
                    Rate_max_inst = FixedProfile(30),
                    Rate_max_add = FixedProfile(3),
                    Rate_min_add = FixedProfile(3),
                    Capex_stor = FixedProfile(0),
                    Stor_max_inst = FixedProfile(50),
                    Stor_max_add = FixedProfile(5),
                    Stor_min_add = FixedProfile(5),
                    Inv_mode = ContinuousInvestment(),
                ),
            ),
        ),
        EMB.RefGeneration(
            10,
            FixedProfile(0),
            FixedProfile(0),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1, CO2 => 1),
            𝒫ᵉᵐ₀,
            0,
            Dict(
                "Investments" => extra_inv_data(
                    Capex_Cap = FixedProfile(10000),
                    Cap_max_inst = FixedProfile(10000),
                    Cap_max_add = FixedProfile(10000),
                    Cap_min_add = FixedProfile(0),
                    Inv_mode = ContinuousInvestment(),
                ),
            ),
        ),
    ]
    links = [
        EMB.Direct(15, nodes[1], nodes[5], EMB.Linear())
        EMB.Direct(16, nodes[1], nodes[6], EMB.Linear())
        EMB.Direct(17, nodes[1], nodes[7], EMB.Linear())
        EMB.Direct(18, nodes[1], nodes[8], EMB.Linear())
        EMB.Direct(19, nodes[1], nodes[9], EMB.Linear())
        EMB.Direct(110, nodes[1], nodes[10], EMB.Linear())
        EMB.Direct(12, nodes[1], nodes[2], EMB.Linear())
        EMB.Direct(31, nodes[3], nodes[1], EMB.Linear())
        EMB.Direct(41, nodes[4], nodes[1], EMB.Linear())
        EMB.Direct(51, nodes[5], nodes[1], EMB.Linear())
        EMB.Direct(61, nodes[6], nodes[1], EMB.Linear())
        EMB.Direct(71, nodes[7], nodes[1], EMB.Linear())
        EMB.Direct(81, nodes[8], nodes[1], EMB.Linear())
        EMB.Direct(91, nodes[9], nodes[1], EMB.Linear())
        EMB.Direct(101, nodes[10], nodes[1], EMB.Linear())
    ]

    # Creation of the time structure and global data
    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    em_limits =
        Dict(NG => FixedProfile(1e6), CO2 => StrategicFixedProfile([450, 400, 350, 300]))
    em_cost = Dict(NG => FixedProfile(0), CO2 => FixedProfile(0))
    global_data = IM.GlobalData(em_limits, em_cost, 0.07)

    # WIP case structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
        :global_data => global_data,
    )
    return case
end

# Generate case data.
model_type = InvestmentModel()
case_data = generate_data()

# Run the optimization as an investment model.
m = run_model(case_data, model_type, HiGHS.Optimizer)

# Uncomment to print all the constraints set in the model.
# print(m)

solution_summary(m)
