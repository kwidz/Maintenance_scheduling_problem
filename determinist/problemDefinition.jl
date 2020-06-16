using JuMP, Xpress, Test


#an hyperplane is made for Calculating the power fuction of a powerhouse
#x is a coefficient for this hyper plane
#y is a coefficient of stored water
# z is a coefficient of discharged water
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


function maximise_production()
  ccd=powerhouse(
  "CCD",
  [6.2956000e+02,6.3400000e+02,7.9235000e+02,7.8936000e+02],
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
  [3.7800000e+01,3.7300000e+01,3.6500000e+01,3.5500000e+01],
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
  [7.6100000e+02,7.7300000e+02,7.7600000e+02,7.6300000e+02],
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
  [0,0,0,0],
  1232.96,
  79.8,
  79.8,
  79.8,
  2600.27,
  2600.27,
  [cim],
  read_hyperplanes("/home/kwidz/Doctorat/ProjetMaintenanceTurbines/Projet Jesus/ModelSelection/data/fineHyperPlanes1/CSH.17.txt")

  )


  powerHouses=[ccd,ccs,cim, csh]
  periodes=[1,2,3,4]
  println(ccs)


end

maximise_production()
