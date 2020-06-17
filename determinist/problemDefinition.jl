using JuMP, GLPK


#an hyperplane is made for Calculating the power fuction of a powerhouse
# z is a coefficient for this hyper plane
# y is a coefficient of stored water
# x is a coefficient of discharged water
# the equation is x+y*stored+z*discharge
#it return an instant power in MW
mutable struct hyperplane
x::Float64
y::Float64
z::Float64
end
mutable struct powerhouse
  name::String
  #m3/s
  inflows::Array
  maxPower::Float64
  #hm3
  stored_water::Float64
  #hm3
  min_storable_water::Float64
  #hm3
  max_storable_water::Float64
  #m3/s
  max_spillway_flow::Float64
  #m3/s
  max_discharge_flow::Float64
  upstream_power_houses::Array
  hyperplanes::Array

end

#this function is reading the production function hyperplanes from a textfile
#the argument is simply the path to the hyperplanes' file
#the return value is an array of hyperplane struct
function read_hyperplanes(path)
  hyperplanes=[]
  open(path) do file
    for ln in eachline(file)
      m=match(
      r"(?<x>[-+]?\d+\.?\d*)\s(?<y>[-+]?\d+\.?\d*)\s(?<z>[-+]?\d+\.?\d*)",
      ln)
      if m !== nothing
        x=parse(Float64,m[:x])
        y=parse(Float64,m[:y])
        z=parse(Float64,m[:z])
        push!(hyperplanes,hyperplane(x,y,z))
      end
    end
    return hyperplanes
  end
end
#this function is reading a 30 days inflow scenario
#in the red file, there is 62 scenario, instance is an integer who is selectingm
#the good inflow scenario.
function read_inflows(path, instance=1)
  inflows=[]
  firstline=true
  open(path) do file
    for ln in eachline(file)
      if !firstline
        inflow=SubString.(ln, findall(r"\S+",ln))
        push!(inflows,parse(Float64,inflow[1]))
      else
        firstline=false
      end
    end
  end
  return inflows
end

#for now this function is creating an array of power houses and most parameters
#are typed by hand,
#TODO create a function to read all parameters in a json file insted of type them
#by hand here so next users will not have to opend and changes things in this code !

function read_parameters()
  ccd=powerhouse(
  "CCD",
  read_inflows("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/cd-Original.dat",1),
  199.715,
  380.5,
  353.8,
  385,
  825.477,
  825.477,
  [],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes1/CCD.5.txt")
  )
  ccs=powerhouse(
  "CCS",
  read_inflows("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/cs-Original.dat",1),
  307.832,
  194.4,
  194.4,
  194.4,
  1097.19,
  1037.19,
  [ccd],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes1/CCS.5.txt")

  )
  cim=powerhouse(
  "CIM",
  read_inflows("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/lsj-Original.dat",1),
  439.528,
  4594,
  3489.5,
  4726.4,
  1495.3,
  1495.3,
  [ccs],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes1/CIM.12.txt")

  )
  csh=powerhouse(
  "CSH",
  read_inflows("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/sh.dat",1),
  1232.96,
  79.8,
  79.8,
  79.8,
  2600.27,
  2600.27,
  [cim],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes1/CSH.17.txt")
  )
  return [ccd,ccs,cim, csh]
end

function create_optimization_model()
  periods=[]
  for i in 0:30
    push!(periods,i)
  end
  power_plants=read_parameters()

  #model = Model(()->Xpress.Optimizer(DEFAULTALG=2, PRESOLVE=0, logfile = "output.log"))
  model = Model(()->GLPK.Optimizer(tm_lim= 60000, msg_lev=GLPK.MSG_OFF))
  #variables defining the discharged water at the powerhouse i and period t in m3/s
  @variable(model, discharge_water[1:size(power_plants)[1],1:size(periods)[1]]>=0)
  #variable defining the spillway water at the powerhouse i and period t in m3/s
  @variable(model, spillway_water[1:size(power_plants)[1],1:size(periods)[1]]>=0)
  #variable defining the reservoir volume at the powerhouse i and period t in hm3
  @variable(model, reservoir_volume[1:size(power_plants)[1],1:size(periods)[1]]>=0)
  #Production instantannée d'électricité
  @variable(model, production[1:size(power_plants)[1],1:size(periods)[1]]>=0)
  #TODO
  @objective(model, Max,
    sum(sum(production[i,t]*24 for i in 1:size(power_plants)[1]) for t in 1:size(periods)[1])
   )

  #upper bounds on discharge water, spillway flow and reservoir volumes
  for i in 1:size(power_plants)[1]
    for t in 1:size(periods)[1]
        set_upper_bound(discharge_water[i,t], power_plants[i].max_discharge_flow)
        set_upper_bound(spillway_water[i,t], power_plants[i].max_spillway_flow)
        set_upper_bound(reservoir_volume[i,t], power_plants[i].max_storable_water)
        set_lower_bound(reservoir_volume[i,t], power_plants[i].min_storable_water)
        set_upper_bound(production[i,t], power_plants[i].maxPower)
        @constraint(model,discharge_water[i,t]>= 0 )
        @constraint(model,spillway_water[i,t]>= 0 )
    end
  end
  # Water balance constraints
  for i in 1:size(power_plants)[1]
    for t in 2:size(periods)[1]
      #t-1 is the current period,indeed we are starting at 2 because the
      #first period is used to emulate the -1 period for the real first period
      if i == 1
        @constraint(model, reservoir_volume[i,t]==reservoir_volume[i,t-1]
            +power_plants[i].inflows[t-1]*(0.086400)
            -discharge_water[i,t]*(0.086400)-spillway_water[i,t]*(0.086400))
      else
        @constraint(model, reservoir_volume[i,t]==reservoir_volume[i,t-1]
            +power_plants[i].inflows[t-1]*(0.086400)+discharge_water[i-1,t]*(0.086400)+spillway_water[i-1,t]*(0.086400)
            -discharge_water[i,t]*(0.086400)-spillway_water[i,t]*(0.086400))
      end
    end
  end
  #hyperplanes constraints (production function)
  for i in 1 : size(power_plants)[1]
    for t in 2:size(periods)[1]
      for h in power_plants[i].hyperplanes
        #h=power_plants[i].hyperplanes[1]
        @constraint(model, production[i,t]<=h.z+h.x*discharge_water[i,t]+h.y*reservoir_volume[i,t])
      end
    end
  end
  #fixing reservoir volume, spillway and discharge at the period -1
  for i in 1:size(power_plants)[1]
    fix(discharge_water[i,1], 0; force = true)
    fix(spillway_water[i,1], 0; force = true)
    fix(reservoir_volume[i,1], power_plants[i].stored_water; force = true)
  end

  # Solve problem using MIP solver
  JuMP.optimize!(model)
  println("the total produced energy is : ", JuMP.objective_value(model), "MWh")
  for i in 1:size(power_plants)[1]
    println(power_plants[i].name)
    println("period \t\t power \t\t\t\t reservoir \t\t\t discharge \t\t\t spillway \t\t\t inflows")
    for t in 2:size(periods)[1]
      println(t-1,  "\t\t",round(JuMP.value(production[i,t]),sigdigits=8),
      "\t\t\t\t",round(JuMP.value(reservoir_volume[i,t]),sigdigits=8),
       "\t\t\t", round(JuMP.value(discharge_water[i,t]),sigdigits=8),
        "\t\t\t", round(JuMP.value(spillway_water[i,t]),sigdigits=8),
        "\t\t\t", round(power_plants[i].inflows[t-1],sigdigits=8))
    end

  end
  println(JuMP.termination_status(model))
  println(JuMP.primal_status(model))
  println(JuMP.objective_value(model))


end

create_optimization_model()
