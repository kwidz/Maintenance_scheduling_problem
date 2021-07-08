#using JuMP, Xpress
using JuMP, GLPK, BenchmarkTools


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
  usable_turbines_number::Array
  minTurbines::Int8
  maxTurbines::Int8
  powerReductionPeroutages::Array
end
mutable struct maintenance
  power_house_index::Int8
  duration::Int8
  earliest_start::Int8
  latest_start::Int8
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
function read_inflows(path, instance=1, scenario_number=1)
  inflows=[]
  for i in 0:scenario_number-1
    println("boucled ", i)
    push!(inflows,[])
  end
  println(inflows)
  firstline=true
  open(path) do file
    for ln in eachline(file)
      if !firstline
        inflow=SubString.(ln, findall(r"\S+",ln))

        for i in 1:scenario_number
          push!(inflows[i],parse(Float64,inflow[instance+(i-1)*62]))
        end
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

function read_parameters(scenario_number)
  ccd=powerhouse(
  "CCD",
  read_inflows("/home/kwidz/Doctorat/Maintenance_scheduling_problem/stochastic/Stochastic Maintenance data/inflows/cd.dat",1, scenario_number),
  199.715,
  380.5,
  353.8,
  385,
  825.477,
  825.477,
  [],
  [[],[],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CCD.3.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CCD.4.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CCD.5.txt")
  ],
  [3,4,5],
  3,
  5,
  [30,15,0]

  )
  ccs=powerhouse(
  "CCS",
  read_inflows("/home/kwidz/Doctorat/Maintenance_scheduling_problem/stochastic/Stochastic Maintenance data/inflows/cs.dat",1, scenario_number),
  307.832,
  194.4,
  194.4,
  194.4,
  1097.19,
  1037.19,
  [ccd],
  [[],[],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CCS.3.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CCS.4.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CCS.5.txt")
  ],
  [3,4,5],
  3,
  5,
  [-100,-50,0]
  )
  cim=powerhouse(
  "CIM",
  read_inflows("/home/kwidz/Doctorat/Maintenance_scheduling_problem/stochastic/Stochastic Maintenance data/inflows/lsj.dat",1, scenario_number),
  439.528,
  4594,
  3489.5,
  4726.4,
  1495.3,
  1495.3,
  [ccs],
  [[],[],[],[],[],[],[],[],[],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CIM.10.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CIM.11.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CIM.12.txt")
  ],
  [10,11,12],
  10,
  12,
  [-25,0,16]
  )
  csh=powerhouse(
  "CSH",
  read_inflows("/home/kwidz/Doctorat/Maintenance_scheduling_problem/stochastic/Stochastic Maintenance data/inflows/sh.dat",1, scenario_number),
  1232.96,
  79.8,
  79.8,
  79.8,
  2600.27,
  2600.27,
  [cim],
  [[],[],[],[],[],[],[],[],[],[],[],[],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CSH.13.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CSH.14.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CSH.15.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CSH.16.txt"),
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes2/CSH.17.txt")
  ],
  [14,15,16,17],
  14,
  17,
  [-50,0,50,90]
  )
  return [ccd,ccs,cim, csh]

end
#a is the powerplant index, b is the duration of the maintenance,
#c is the earliest period to start the maintenance
#and d is the latest period to start  the maintenance
function read_maintenances(path)
  maintenances=[]
  ignore_lines=1
  open(path) do file
    for ln in eachline(file)
      #ignoring the 2 first lines of the config file because they are useless
      if ignore_lines <=2
        ignore_lines+=1
        continue
      end
      m=match(
      r"(?<a>\d+)\s(?<x>\d+)\s(?<b>\d+)\s(?<y>\d+)\s(?<c>\d+)\s(?<d>\d+)",
      ln)
      if m !== nothing
        a=parse(Float64,m[:a])+1
        b=parse(Float64,m[:b])
        c=parse(Float64,m[:c])+2
        d=parse(Float64,m[:d])+2
        push!(maintenances,maintenance(a,b,c,d))
        println(a,",",b,",",c,",",d )
      end
    end
  end
  return maintenances
end

function create_optimization_model()
  scenario_number=40
  periods=[]
  for i in 0:29
    push!(periods,i)
  end
  power_plants=read_parameters(scenario_number)
  maintenances=read_maintenances("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/sched_3.txt")
  #Xpress.Optimizer(OUTPUTLOG = 1)
  #model = Model(()->Xpress.Optimizer(DEFAULTALG=2, PRESOLVE=1, logfile = "output.log"))
  model = Model(()->GLPK.Optimizer(tm_lim= 800000, msg_lev=GLPK.MSG_OFF))
  #variables defining the discharged water at the powerhouse i and period t in m3/s
  @variable(model, discharge_water[1:size(power_plants)[1],1:size(periods)[1], 1:scenario_number]>=0)
  #variable defining the spillway water at the powerhouse i and period t in m3/s
  @variable(model, spillway_water[1:size(power_plants)[1],1:size(periods)[1], 1:scenario_number]>=0)
  #variable defining the reservoir volume at the powerhouse i and period t in hm3
  @variable(model, reservoir_volume[1:size(power_plants)[1],1:size(periods)[1], 1:scenario_number]>=0)
  #Production instantannée d'électricité
  @variable(model, production[1:size(power_plants)[1],1:size(periods)[1], 1:scenario_number]>=0)
  #Number of maintenances sheduled at the powerhouse i and period t
  @variable(model, maintenance_number[1:size(power_plants)[1],1:size(periods)[1]]>=0,Int)
  #Binary variable to define if a maintenance task m is starting at the period t
  @variable(model, start_maintenance[1:size(maintenances)[1],1:size(periods)[1]],Bin)
  #binary variable. 1 if k turbines are actives at the period t in the powerhouse i
  periods_optimizables_ccd=[]
  for m in maintenances
    if m.power_house_index==1
      for i in m.earliest_start:m.latest_start+m.duration
        check=false
        for j in periods_optimizables_ccd
          if i ==j
            check=true
          end
        end
        if check
          push!(periods_optimizables,i)
        end
      end
    end
  end
  @variable(model, number_of_active_turbinesCCD[
  1:size(power_plants)[1],
  i in 1:size(periods)[1],
  3:5; i in periods_optimizables_ccd],Bin)
  periods_optimizables_ccs=[]
  for m in maintenances
    if m.power_house_index==1
      for i in m.earliest_start:m.latest_start+m.duration
        check=false
        for j in periods_optimizables_ccs
          if i ==j
            check=true
          end
        end
        if check
          push!(periods_optimizables,i)
        end
      end
    end
  end
  @variable(model, number_of_active_turbinesCCS[
  1:size(power_plants)[1],
  i in 1:size(periods)[1],
  3:6; i in periods_optimizables_ccs],Bin)
  periods_optimizables_cim=[]
  for m in maintenances
    if m.power_house_index==1
      for i in m.earliest_start:m.latest_start+m.duration
        check=false
        for j in periods_optimizables_cim
          if i ==j
            check=true
          end
        end
        if check
          push!(periods_optimizables,i)
        end
      end
    end
  end
  @variable(model, number_of_active_turbinesCIM[
  1:size(power_plants)[1],
  i in 1:size(periods)[1],
  10:12; i in periods_optimizables_cim],Bin)
  periods_optimizables_csh=[]
  for m in maintenances
    if m.power_house_index==1
      for i in m.earliest_start:m.latest_start+m.duration
        check=false
        for j in periods_optimizables_csh
          if i ==j
            check=true
          end
        end
        if check
          push!(periods_optimizables,i)
        end
      end
    end
  end
  @variable(model, number_of_active_turbinesCSH[
  1:size(power_plants)[1],
  i in 1:size(periods)[1],
  13:17; i in periods_optimizables_csh],Bin)

  @objective(model, Max,
  #*1.92 is for 24 hours times 80$ per Megawat / 1000 so the objective will be in K$
  sum(sum(sum(1/scenario_number*production[i,t,w]*1.92 for w in 1:scenario_number) for i in 1:size(power_plants)[1]) for t in 1:size(periods)[1])
  )

  #upper bounds on discharge water, spillway flow and reservoir volumes
  for i in 1:size(power_plants)[1]
    for t in 1:size(periods)[1]
      for w in 1:scenario_number
        set_upper_bound(discharge_water[i,t,w], power_plants[i].max_discharge_flow)
        set_upper_bound(spillway_water[i,t,w], power_plants[i].max_spillway_flow)
        set_upper_bound(reservoir_volume[i,t,w], power_plants[i].max_storable_water)
        set_lower_bound(reservoir_volume[i,t,w], power_plants[i].min_storable_water)
        set_upper_bound(production[i,t,w], power_plants[i].maxPower)
        @constraint(model,discharge_water[i,t,w]>= 0 )
        @constraint(model,spillway_water[i,t,w]>= 0 )
      end
    end
  end
  # Water balance constraints
  for i in 1:size(power_plants)[1]
    for t in 2:size(periods)[1]
      #t-1 is the current period,indeed we are starting at 2 because the
      #first period is used to emulate the -1 period for the real first period
      #TODO inflows
      if i == 1
        for w in 1:scenario_number
          @constraint(model, reservoir_volume[i,t,w]==reservoir_volume[i,t-1,w]
          +power_plants[i].inflows[w][t-1]*(0.086400)
          -discharge_water[i,t,w]*(0.086400)-spillway_water[i,t,w]*(0.086400))
        end
      else
        for w in 1:scenario_number
          @constraint(model, reservoir_volume[i,t,w]==reservoir_volume[i,t-1,w]
          +power_plants[i].inflows[w][t-1]*(0.086400)+discharge_water[i-1,t,w]*(0.086400)+spillway_water[i-1,t,w]*(0.086400)
          -discharge_water[i,t,w]*(0.086400)-spillway_water[i,t,w]*(0.086400))
        end
      end
    end
  end
  #hyperplanes constraints (production function)
  for i in 1 : size(power_plants)[1]
    for t in 2:size(periods)[1]
      for h in power_plants[i].hyperplanes[power_plants[i].maxTurbines]
        if(h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][1])
        #h=power_plants[i].hyperplanes[1]
        if i==1
          for k in power_plants[i].minTurbines:power_plants[i].maxTurbines
            if t in periods_optimizables_ccd
              for w in 1:scenario_number
                @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w]+(1-number_of_active_turbinesCCD[i,t,k])*200)
              end
            elseif k == power_plants[i].maxTurbines
              for w in 1:scenario_number
                if(h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][1]||h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][20])
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
                end
              end
            end
          end
        end
        if i==2
          if t in periods_optimizables_ccs
            for w in 1:scenario_number
              @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w]+
              sum(number_of_active_turbinesCCS[i,t,k]*power_plants[i].powerReductionPeroutages[k-power_plants[i].minTurbines+1] for k in power_plants[i].minTurbines:power_plants[i].maxTurbines)+(1-number_of_active_turbinesCCS[i,t,k])*200)
            end
          else
            for w in 1:scenario_number
              if(h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][1]||h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][20])
                @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
              end
          end
          end
        end
        if i==3
          if t in periods_optimizables_cim
            for w in 1:scenario_number
              @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w]+
              sum(number_of_active_turbinesCIM[i,t,k]*power_plants[i].powerReductionPeroutages[k-power_plants[i].minTurbines+1] for k in power_plants[i].minTurbines:power_plants[i].maxTurbines)+(1-number_of_active_turbinesCIM[i,t,k])*200)
            end
          else
            for w in 1:scenario_number
              if(h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][1]||h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][20])
                @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
              end
          end

          end
        end
        if i==4
          if t in periods_optimizables_csh
            for w in 1:scenario_number
              @constraint(model, production[i,t,w]<=(h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])+
              sum(number_of_active_turbinesCSH[i,t,k]*power_plants[i].powerReductionPeroutages[k-power_plants[i].minTurbines+1] for k in power_plants[i].minTurbines:power_plants[i].maxTurbines)+(1-number_of_active_turbinesCSH[i,t,k])*200)
            end
          else
            for w in 1:scenario_number

              if(h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][1]||h==power_plants[i].hyperplanes[power_plants[i].maxTurbines][20])
                @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
                println("here we go")
                println(h)
              end
          end

end
          end
        end
      end

    end
  end
  #fixing reservoir volume, spillway and discharge at the period -1
  for i in 1:size(power_plants)[1]
    for w in 1:scenario_number
      fix(discharge_water[i,1,w], 0; force = true)
      fix(spillway_water[i,1,w], 0; force = true)
      fix(reservoir_volume[i,1,w], power_plants[i].stored_water; force = true)
    end
  end
  #maintenances bounding the variable for number of groups to 0 if there isn't enough group in the central i
  # for i in 1:size(power_plants)[1]
  #   for t in 1:size(periods)[1]
  #     for k in 1:17
  #       if (k<power_plants[i].minTurbines || k>power_plants[i].maxTurbines)
  #         fix(number_of_active_turbinesCCD[i,t,k], 0, force = true)
  #       end
  #     end
  #   end
  # end


  #maintenances : forcing all maintenances to start !
  for m in 1:size(maintenances)[1]
    @constraint(model, sum(start_maintenance[m,t] for t in 2:size(periods)[1]
    if (maintenances[m].earliest_start<=t && maintenances[m].latest_start>=t ))==1)
    end
    # maintenance : defining the number of maintenances
    for i in 1:size(power_plants)[1]
      #starting at 2 because array in julia starts at one and the first period is used for defining reservoir levels
      for t in 2:size(periods)[1]
        total_outage=@expression(model, 0)
        for m in 1:size(maintenances)[1]
          if maintenances[m].power_house_index==i
            for tt in t-maintenances[m].duration+1:t
              if (tt>=2
                && (tt<size(periods)[1]-maintenances[m].duration+1)
                && tt>=maintenances[m].earliest_start
                && tt<=maintenances[m].latest_start)
                #building the sum of outages for the period t
                total_outage+=start_maintenance[m,tt]
              end
            end
          end
        end
        @constraint(model,total_outage==maintenance_number[i,t])
      end
    end

    #bounds maintenance number
    #TODO add maximum maintenance and min for all centrals
    for i in 1:size(power_plants)[1]
      for t in 2:size(periods)[1]
        @constraint(model, maintenance_number[i,t]<=3)
        @constraint(model, maintenance_number[i,t]>=0)
      end
      @constraint(model, maintenance_number[i,1]==0)
    end

    #mapping maintenance number to active turbines number
    for i in 1:size(power_plants)[1]
      for t in 2:size(periods)[1]
        if i==1
          if t in periods_optimizables_ccd
            @constraint(model, maintenance_number[i,t]+sum(k*number_of_active_turbinesCCD[i,t,k] for k in power_plants[i].usable_turbines_number)==power_plants[i].maxTurbines)
          end
        end
        if i==2
          if t in periods_optimizables_ccs
            @constraint(model, maintenance_number[i,t]+sum(k*number_of_active_turbinesCCS[i,t,k] for k in power_plants[i].usable_turbines_number)==power_plants[i].maxTurbines)
          end
        end
        if i==3
          if t in periods_optimizables_cim
            @constraint(model, maintenance_number[i,t]+sum(k*number_of_active_turbinesCIM[i,t,k] for k in power_plants[i].usable_turbines_number)==power_plants[i].maxTurbines)
          end
        end
        if i==4
          if t in periods_optimizables_csh
            @constraint(model, maintenance_number[i,t]+sum(k*number_of_active_turbinesCSH[i,t,k] for k in power_plants[i].usable_turbines_number)==power_plants[i].maxTurbines)
          end
        end
      end
    end


    # Solve problem using MIP solver
    println("starting optimization...")
    start = time()
    JuMP.optimize!(model)
    elapsed = time() - start
    println("temps de résolution : ",elapsed)
    println(JuMP.termination_status(model))
    println("the total produced energy is : ", JuMP.objective_value(model), "MWh")
    for i in 1:size(power_plants)[1]
      println(power_plants[i].name)
      println("period \t power \t\t reservoir \t\t discharge \t\t spillway \t\t inflows")
      for t in 2:size(periods)[1]
        print(t-1,  "\t\t",round(JuMP.value(production[i,t,1]),sigdigits=8),
        "\t\t\t",round(JuMP.value(reservoir_volume[i,t,1]),sigdigits=8),
        "\t", round(JuMP.value(discharge_water[i,t,1]),sigdigits=8),
        "\t", round(JuMP.value(spillway_water[i,t,1]),sigdigits=8),
        "\t", round(power_plants[i].inflows[1][t-1],sigdigits=8),
        "\tnombre de maintenances :", JuMP.value(maintenance_number[i,t]))
        for m in 1:size(maintenances)[1]
          if JuMP.value(start_maintenance[m,t])==1 && maintenances[m].power_house_index==i
            print("\tStarting maintenance ", m)
          end
        end
        println()

      end

    end
    println(JuMP.termination_status(model))
    println(JuMP.primal_status(model))
    println(JuMP.objective_value(model))


  end

  create_optimization_model()
