#using JuMP, Xpress
using JuMP, GLPK, BenchmarkTools, Plots, JSON

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
    push!(inflows,[])
  end
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

function read_parameters(scenario_number, config)
  ccd=powerhouse(
  config["CCD"]["name"],
  read_inflows(string(config["globalParameters"]["inflowsFolder"],config["CCD"]["inflows"]),1, scenario_number),
  config["CCD"]["maxPower"],
  config["CCD"]["stored_water"],
  config["CCD"]["min_storable_water"],
  config["CCD"]["max_storable_water"],
  config["CCD"]["max_spillway_flow"],
  config["CCD"]["max_discharge_flow"],
  config["CCD"]["upstream_power_houses"],
  [[],[],
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CCD"]["hyperplanes"][3] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CCD"]["hyperplanes"][4] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CCD"]["hyperplanes"][5] ))
  ],
  config["CCD"]["usable_turbines_number"],
  config["CCD"]["minTurbines"],
  config["CCD"]["maxTurbines"],
  config["CCD"]["powerReductionPeroutages"]

  )
  ccs=powerhouse(
  config["CCS"]["name"],
  read_inflows(string(config["globalParameters"]["inflowsFolder"],config["CCS"]["inflows"]),1, scenario_number),
  config["CCS"]["maxPower"],
  config["CCS"]["stored_water"],
  config["CCS"]["min_storable_water"],
  config["CCS"]["max_storable_water"],
  config["CCS"]["max_spillway_flow"],
  config["CCS"]["max_discharge_flow"],
  config["CCS"]["upstream_power_houses"],
  [[],[],
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CCS"]["hyperplanes"][3] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CCS"]["hyperplanes"][4] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CCS"]["hyperplanes"][5] ))
  ],
  config["CCS"]["usable_turbines_number"],
  config["CCS"]["minTurbines"],
  config["CCS"]["maxTurbines"],
  config["CCS"]["powerReductionPeroutages"]
  )
  cim=powerhouse(
  config["CIM"]["name"],
  read_inflows(string(config["globalParameters"]["inflowsFolder"],config["CIM"]["inflows"]),1, scenario_number),
  config["CIM"]["maxPower"],
  config["CIM"]["stored_water"],
  config["CIM"]["min_storable_water"],
  config["CIM"]["max_storable_water"],
  config["CIM"]["max_spillway_flow"],
  config["CIM"]["max_discharge_flow"],
  config["CIM"]["upstream_power_houses"],
  [[],[],[],[],[],[],[],[],[],
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CIM"]["hyperplanes"][10] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CIM"]["hyperplanes"][11] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CIM"]["hyperplanes"][12] ))
  ],
  config["CIM"]["usable_turbines_number"],
  config["CIM"]["minTurbines"],
  config["CIM"]["maxTurbines"],
  config["CIM"]["powerReductionPeroutages"]
  
  
  )
  csh=powerhouse(
  config["CSH"]["name"],
  read_inflows(string(config["globalParameters"]["inflowsFolder"],config["CIM"]["inflows"]),1, scenario_number),
  config["CSH"]["maxPower"],
  config["CSH"]["stored_water"],
  config["CSH"]["min_storable_water"],
  config["CSH"]["max_storable_water"],
  config["CSH"]["max_spillway_flow"],
  config["CSH"]["max_discharge_flow"],
  config["CSH"]["upstream_power_houses"],
  [[],[],[],[],[],[],[],[],[],[],[],[],
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CSH"]["hyperplanes"][13] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CSH"]["hyperplanes"][14] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CSH"]["hyperplanes"][15] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CSH"]["hyperplanes"][16] )),
  read_hyperplanes(string(config["globalParameters"]["hyperplanesFolder"],config["CSH"]["hyperplanes"][17] ))
  ],
  config["CSH"]["usable_turbines_number"],
  config["CSH"]["minTurbines"],
  config["CSH"]["maxTurbines"],
  config["CSH"]["powerReductionPeroutages"]
  )
  return [ccd,ccs,cim, csh]

end
#a is the powerplant index, b is the duration of the maintenance,
#c is the earliest period to start the maintenance
#and d is the latest period to start  the maintenance
function read_maintenances(config)
  path=string(config["globalParameters"]["maintenancesScenarios"],ARGS[1],".txt")
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
        
      end
    end
  end
  return maintenances
end

function create_optimization_model()
  config=Dict()
  config=JSON.parsefile("config.json")  # parse and transform data
  scenario_number=config["globalParameters"]["scenarioNumber"]
  periods=[]
  for i in 0:29
    push!(periods,i)
  end
  power_plants=read_parameters(scenario_number, config)
  maintenances=read_maintenances(config)
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
      for k in power_plants[i].minTurbines:power_plants[i].maxTurbines
        if (k>=power_plants[i].minTurbines && k<=power_plants[i].maxTurbines)
          #k=power_plants[i].maxTurbines
          for h in power_plants[i].hyperplanes[k]
            #h=power_plants[i].hyperplanes[1]
            if i==1
              if t in periods_optimizables_ccd
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w]+(1-number_of_active_turbinesCCD[i,t,k])*200)
                end
              elseif k == power_plants[i].maxTurbines
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
                end
              end
            end
            if i==2
              if t in periods_optimizables_ccs
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w]+(1-number_of_active_turbinesCCS[i,t,k])*200)
                end
              elseif k == power_plants[i].maxTurbines
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
                end
              end
            end
            if i==3
              if t in periods_optimizables_cim
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w]+(1-number_of_active_turbinesCIM[i,t,k])*200)
                end
              elseif k == power_plants[i].maxTurbines
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
                end
              end
            end
            if i==4
              if t in periods_optimizables_csh
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w]+(1-number_of_active_turbinesCSH[i,t,k])*200)
                end
              elseif k == power_plants[i].maxTurbines
                for w in 1:scenario_number
                  @constraint(model, production[i,t,w]<=h.z+h.x*discharge_water[i,t,w]+h.y*reservoir_volume[i,t,w])
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
    #println("starting optimization...")
    start = time()
    JuMP.optimize!(model)
    elapsed = time() - start
    #println("temps de résolution : ",elapsed)
    #println(JuMP.termination_status(model))
    #println("the total produced energy is : ", JuMP.objective_value(model), "MWh")
    gr()
    #println("temps de résolution : ",elapsed)
    #println(JuMP.termination_status(model))
    #println("the total produced energy is : ", JuMP.objective_value(model), "MWh")
    maintenancesCCD=[]
        maintenancesCCS=[]
        maintenancesCIM=[]
        maintenancesCSH=[]
        for t in 1:size(periods)[1]-1
            append!(maintenancesCCD,0)
            append!(maintenancesCCS,0)
            append!(maintenancesCIM,0)
            append!(maintenancesCSH,0)
        end
    for i in 1:size(power_plants)[1]
      #println(power_plants[i].name)
      println("\n")
      println("period; power; reservoir; discharge; spillway; inflows")
      x=3:size(periods)[1]-1
      y=[[],[],[]]
      for t in 3:size(periods)[1]-1
        append!(y[1], round(JuMP.value(reservoir_volume[i,t,1]),sigdigits=8))
        append!(y[2],round(JuMP.value(discharge_water[i,t,1]),sigdigits=8))
        append!(y[3],round(JuMP.value(production[i,t,1]),sigdigits=8))
      end
      plot(x,y[1],label="reservoir volume")
      plot!(x,y[2],label="discharge_water")
      plot!(x,y[3],label="production")
      if i== 1
        savefig(string(config["globalParameters"]["savingResultsFolder"],ARGS[1],"/CCDWaterJesus.png"))
      end
      if i== 2
        savefig(string(config["globalParameters"]["savingResultsFolder"],ARGS[1],"/CCSWaterJesus.png"))
      end
      if i== 3
        savefig(string(config["globalParameters"]["savingResultsFolder"],ARGS[1],"/CIMWaterJesus.png"))
      end
      if i== 4
        savefig(string(config["globalParameters"]["savingResultsFolder"],ARGS[1],"/CSHWaterJesus.png"))
      end

        
      for t in 1:size(periods)[1]-1
        print(t-1,  ";",round(JuMP.value(production[i,t,1]),sigdigits=8),
        ";",round(JuMP.value(reservoir_volume[i,t,1]),sigdigits=8),
        ";", round(JuMP.value(discharge_water[i,t,1]),sigdigits=8),
        ";", round(JuMP.value(spillway_water[i,t,1]),sigdigits=8),
        ";", round(power_plants[i].inflows[1][t],sigdigits=8)
        #";nombre de maintenances :", JuMP.value(maintenance_number[i,t])
        )
        for m in 1:size(maintenances)[1]
          if JuMP.value(start_maintenance[m,t])==1 && maintenances[m].power_house_index==i
            if(i==1)
                for duree in 1:maintenances[m].duration
                     maintenancesCCD[t+duree-1]=maintenancesCCD[t+duree-1]+1
                end
            end
            if(i==2)
                for duree in 1:maintenances[m].duration
                     maintenancesCCS[t+duree-1]=maintenancesCCS[t+duree-1]+1
                end
            end
            if(i==3)
                for duree in 1:maintenances[m].duration
                     maintenancesCIM[t+duree-1]=maintenancesCIM[t+duree-1]+1
                end
            end
            if(i==4)
                for duree in 1:maintenances[m].duration
                     maintenancesCSH[t+duree-1]=maintenancesCSH[t+duree-1]+1
                end
            end
          end
        end
        
        println()

      end
      x=1:size(periods)[1]-1
      println(x)
      println(maintenancesCCS)
      plot(x,maintenancesCCD,label="Maintenances CCD", linetype="steppost")
      plot!(x,maintenancesCCS,label="Maintenances CCS", linetype="steppost")
      plot!(x,maintenancesCIM,label="Maintenances CIM", linetype="steppost")
      plot!(x,maintenancesCSH,label="Maintenances CSH", linetype="steppost")
      savefig(string(config["globalParameters"]["savingResultsFolder"],ARGS[1],"/MaintenancesJesus.png"))
      

    end
    #println(JuMP.termination_status(model))
    #println(JuMP.primal_status(model))
    #println(JuMP.objective_value(model))


  end

  create_optimization_model()
